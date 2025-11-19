package config

import (
	"fmt"
	"log"
	"reflect"

	"github.com/fsnotify/fsnotify"
)

// Watch 启动配置文件监听（热更新）
func (m *Manager) Watch() {
	// 开启一个携程来处理配置文件的热更新，大概是
	// 1：监听写事件和创造事件
	// 2：发现后通过readInConfig重新读取配置文件
	// 3：然后调用回调函数OnConfigChange
	// 4：在回调函数中重新加载配置
	m.viper.WatchConfig()
	m.viper.OnConfigChange(func(e fsnotify.Event) {
		log.Printf("配置文件变更: %s", e.Name)
		m.reload()
	})
	log.Println("配置热更新监听已启动")
}

// reload 重新加载配置
func (m *Manager) reload() {
	log.Println("开始重新加载配置...")

	// 1. 重新解析配置
	var newCfg AppConfig
	if err := m.viper.Unmarshal(&newCfg); err != nil {
		log.Printf("❌ 配置解析失败，保留旧配置: %v", err)
		return
	}

	// 2. 验证新配置（Fail-Safe：验证失败保留旧配置）
	if err := m.Validate(&newCfg); err != nil {
		log.Printf("❌ 配置验证失败，保留旧配置: %v", err)
		return
	}

	// 3. 计算配置差异
	oldCfg := m.GetConfig()
	changes := m.diff(oldCfg, &newCfg)
	if len(changes) == 0 {
		log.Println("配置无变化")
		return
	}

	// 4. 应用新配置
	m.mu.Lock()
	m.config = &newCfg
	m.mu.Unlock()

	// 5. 记录变更
	log.Printf("✅ 配置已更新，变更项: %v", changes)

	// 6. 通知监听器
	m.notifyChange(&newCfg)
}

// diff 比较配置差异
func (m *Manager) diff(old, new *AppConfig) []string {
	changes := []string{}

	// 比较 Log 配置
	if old.Log.Level != new.Log.Level {
		changes = append(changes, fmt.Sprintf("log.level: %s -> %s", old.Log.Level, new.Log.Level))
	}
	if old.Log.Format != new.Log.Format {
		changes = append(changes, fmt.Sprintf("log.format: %s -> %s", old.Log.Format, new.Log.Format))
	}

	// 比较 Redis 配置
	if old.Redis.PoolSize != new.Redis.PoolSize {
		changes = append(changes, fmt.Sprintf("redis.pool_size: %d -> %d", old.Redis.PoolSize, new.Redis.PoolSize))
	}
	if old.Redis.MaxRetries != new.Redis.MaxRetries {
		changes = append(changes, fmt.Sprintf("redis.max_retries: %d -> %d", old.Redis.MaxRetries, new.Redis.MaxRetries))
	}

	// 比较 Features 配置
	if old.Features.EnableMetrics != new.Features.EnableMetrics {
		changes = append(changes, fmt.Sprintf("features.enable_metrics: %v -> %v", old.Features.EnableMetrics, new.Features.EnableMetrics))
	}
	if old.Features.EnableConfigAPI != new.Features.EnableConfigAPI {
		changes = append(changes, fmt.Sprintf("features.enable_config_api: %v -> %v", old.Features.EnableConfigAPI, new.Features.EnableConfigAPI))
	}

	return changes
}

// IsHotReloadable 检查字段是否支持热更新
func IsHotReloadable(field string) bool {
	for _, f := range HotReloadableFields {
		if f == field {
			return true
		}
	}
	return false
}

// GetHotReloadableFields 获取所有可热更新的字段
func GetHotReloadableFields() []string {
	return HotReloadableFields
}

// ReloadManually 手动触发配置重载
func (m *Manager) ReloadManually() error {
	log.Println("手动触发配置重载...")

	// 重新读取配置文件
	if err := m.viper.ReadInConfig(); err != nil {
		return fmt.Errorf("读取配置文件失败: %w", err)
	}

	// 执行重载
	m.reload()
	return nil
}

// diffDeep 深度比较配置差异（通用版本）
func diffDeep(old, new interface{}, prefix string) []string {
	changes := []string{}

	oldVal := reflect.ValueOf(old)
	newVal := reflect.ValueOf(new)

	// 处理指针
	if oldVal.Kind() == reflect.Ptr {
		oldVal = oldVal.Elem()
	}
	if newVal.Kind() == reflect.Ptr {
		newVal = newVal.Elem()
	}

	// 只处理结构体
	if oldVal.Kind() != reflect.Struct || newVal.Kind() != reflect.Struct {
		return changes
	}

	// 遍历字段
	for i := 0; i < oldVal.NumField(); i++ {
		fieldName := oldVal.Type().Field(i).Name
		oldField := oldVal.Field(i)
		newField := newVal.Field(i)

		fieldPath := prefix + "." + fieldName
		if prefix == "" {
			fieldPath = fieldName
		}

		// 递归比较结构体
		if oldField.Kind() == reflect.Struct {
			changes = append(changes, diffDeep(oldField.Interface(), newField.Interface(), fieldPath)...)
			continue
		}

		// 比较基本类型
		if !reflect.DeepEqual(oldField.Interface(), newField.Interface()) {
			changes = append(changes, fmt.Sprintf("%s: %v -> %v", fieldPath, oldField.Interface(), newField.Interface()))
		}
	}

	return changes
}
