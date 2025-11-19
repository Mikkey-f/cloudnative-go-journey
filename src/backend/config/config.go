package config

import (
	"errors"
	"fmt"
	"log"
	"sync"

	"github.com/spf13/viper"
)

// Manager 配置管理器
type Manager struct {
	viper      *viper.Viper
	config     *AppConfig
	validators []Validator
	onChange   []func(*AppConfig)
	mu         sync.RWMutex
}

// viperInstance Viper 实例别名（用于 default.go）
type viperInstance = viper.Viper

// NewManager 创建配置管理器
func NewManager() *Manager {
	return &Manager{
		viper:      viper.New(),
		validators: []Validator{&DefaultValidator{}},
		onChange:   []func(*AppConfig){},
	}
}

// Load 加载配置
// 优先级: 环境变量 > 配置文件 > 默认值
func (m *Manager) Load() error {
	// 1. 设置默认值
	setDefaults(m.viper)

	// 2. 设置配置文件路径
	m.viper.SetConfigName("config")
	m.viper.SetConfigType("yaml")
	m.viper.AddConfigPath("/etc/config") // K8s ConfigMap 挂载路径
	m.viper.AddConfigPath("./config")    // 本地开发路径
	m.viper.AddConfigPath(".")           // 当前目录

	// 3. 读取配置文件（可选，不存在不报错）
	if err := m.viper.ReadInConfig(); err != nil {
		var configFileNotFoundError viper.ConfigFileNotFoundError
		if !errors.As(err, &configFileNotFoundError) {
			return fmt.Errorf("读取配置文件失败: %w", err)
		}
		log.Println("未找到配置文件，使用默认值")
	} else {
		log.Printf("使用配置文件: %s", m.viper.ConfigFileUsed())
	}

	// 4. 自动绑定环境变量
	m.viper.AutomaticEnv()

	// 5. 手动绑定敏感信息的环境变量
	m.bindEnvVars()

	// 6. 反序列化到结构体
	var cfg AppConfig
	if err := m.viper.Unmarshal(&cfg); err != nil {
		return fmt.Errorf("解析配置失败: %w", err)
	}

	// 7. 验证配置
	if err := m.Validate(&cfg); err != nil {
		return fmt.Errorf("配置验证失败: %w", err)
	}

	// 8. 保存配置
	m.mu.Lock()
	m.config = &cfg
	m.mu.Unlock()

	log.Println("配置加载成功")
	return nil
}

// bindEnvVars 绑定环境变量
func (m *Manager) bindEnvVars() {
	// Server
	m.viper.BindEnv("server.port", "PORT")
	m.viper.BindEnv("server.environment", "ENVIRONMENT")
	m.viper.BindEnv("server.app_name", "APP_NAME")
	m.viper.BindEnv("server.version", "VERSION")

	// Redis（敏感信息）
	m.viper.BindEnv("redis.host", "REDIS_HOST")
	m.viper.BindEnv("redis.port", "REDIS_PORT")
	m.viper.BindEnv("redis.password", "REDIS_PASSWORD")

	// Database（敏感信息）
	m.viper.BindEnv("database.host", "DB_HOST")
	m.viper.BindEnv("database.port", "DB_PORT")
	m.viper.BindEnv("database.name", "DB_NAME")
	m.viper.BindEnv("database.user", "DB_USER")
	m.viper.BindEnv("database.password", "DB_PASSWORD")

	// Log
	m.viper.BindEnv("log.level", "LOG_LEVEL")
}

// GetConfig 获取当前配置（线程安全）
func (m *Manager) GetConfig() *AppConfig {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.config
}

// Validate 验证配置
func (m *Manager) Validate(cfg *AppConfig) error {
	for _, validator := range m.validators {
		if err := validator.Validate(cfg); err != nil {
			return err
		}
	}
	return nil
}

// OnChange 注册配置变更回调
func (m *Manager) OnChange(callback func(*AppConfig)) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.onChange = append(m.onChange, callback)
}

// notifyChange 通知所有监听器
func (m *Manager) notifyChange(cfg *AppConfig) {
	m.mu.RLock()
	callbacks := m.onChange
	m.mu.RUnlock()

	for _, callback := range callbacks {
		callback(cfg)
	}
}

// GetViperInstance 获取 Viper 实例（用于高级操作）
func (m *Manager) GetViperInstance() *viper.Viper {
	return m.viper
}

// Load 全局加载函数（向后兼容）
// 已弃用：请使用 NewManager().Load()
func Load() *Config {
	return &Config{
		Port:        8080,
		Environment: "development",
		AppName:     "cloudnative-go-api",
		Version:     "v0.5.0",
	}
}

// Config 旧配置结构（向后兼容）
// 已弃用：请使用 AppConfig
type Config struct {
	Port        int
	Environment string
	AppName     string
	Version     string
}
