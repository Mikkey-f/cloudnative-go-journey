package config

import "time"

// AppConfig 应用配置结构体
type AppConfig struct {
	Server   ServerConfig   `mapstructure:"server" validate:"required"`
	Database DatabaseConfig `mapstructure:"database"`
	Redis    RedisConfig    `mapstructure:"redis" validate:"required"`
	Log      LogConfig      `mapstructure:"log" validate:"required"`
	Features FeatureFlags   `mapstructure:"features" validate:"required"`
}

// ServerConfig 服务器配置
type ServerConfig struct {
	Port         int           `mapstructure:"port" validate:"required,min=1,max=65535"`
	Host         string        `mapstructure:"host" validate:"required"`
	Environment  string        `mapstructure:"environment" validate:"required,oneof=development staging production"`
	AppName      string        `mapstructure:"app_name" validate:"required"`
	Version      string        `mapstructure:"version" validate:"required"`
	ReadTimeout  time.Duration `mapstructure:"read_timeout" validate:"required"`
	WriteTimeout time.Duration `mapstructure:"write_timeout" validate:"required"`
}

// DatabaseConfig 数据库配置
type DatabaseConfig struct {
	Enabled           bool          `mapstructure:"enabled"`
	Host              string        `mapstructure:"host" validate:"required_if=Enabled true"`
	Port              int           `mapstructure:"port" validate:"required_if=Enabled true,omitempty,min=1,max=65535"`
	Name              string        `mapstructure:"name" validate:"required_if=Enabled true"`
	User              string        `mapstructure:"user" validate:"required_if=Enabled true"`
	Password          string        `mapstructure:"password"` // 从环境变量读取，不验证
	MaxConnections    int           `mapstructure:"max_connections" validate:"omitempty,min=1"`
	ConnectionTimeout time.Duration `mapstructure:"connection_timeout" validate:"omitempty"`
}

// RedisConfig Redis 配置
type RedisConfig struct {
	Enabled     bool          `mapstructure:"enabled"`
	Host        string        `mapstructure:"host" validate:"required_if=Enabled true"`
	Port        int           `mapstructure:"port" validate:"required_if=Enabled true,omitempty,min=1,max=65535"`
	Password    string        `mapstructure:"password"` // 从环境变量读取，不验证
	DB          int           `mapstructure:"db" validate:"min=0,max=15"`
	MaxRetries  int           `mapstructure:"max_retries" validate:"min=0"`
	PoolSize    int           `mapstructure:"pool_size" validate:"min=1"`
	PoolTimeout time.Duration `mapstructure:"pool_timeout" validate:"required"`
}

// LogConfig 日志配置
type LogConfig struct {
	Level            string `mapstructure:"level" validate:"required,oneof=debug info warn error"`
	Format           string `mapstructure:"format" validate:"required,oneof=json text"`
	Output           string `mapstructure:"output" validate:"required,oneof=stdout stderr file"`
	EnableCaller     bool   `mapstructure:"enable_caller"`
	EnableStacktrace bool   `mapstructure:"enable_stacktrace"`
}

// FeatureFlags 功能开关
type FeatureFlags struct {
	EnableMetrics     bool `mapstructure:"enable_metrics"`
	EnableHealthCheck bool `mapstructure:"enable_health_check"`
	EnableConfigAPI   bool `mapstructure:"enable_config_api"`
	EnableHotReload   bool `mapstructure:"enable_hot_reload"`
}

// HotReloadableFields 可热更新的字段列表
var HotReloadableFields = []string{
	"log.level",
	"log.format",
	"redis.pool_size",
	"redis.max_retries",
	"features.enable_metrics",
	"features.enable_config_api",
}
