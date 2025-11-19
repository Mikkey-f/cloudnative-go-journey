package config

import "time"

// setDefaults 设置默认配置值
func setDefaults(v *viperInstance) {
	// Server 默认值
	v.SetDefault("server.port", 8080)
	v.SetDefault("server.host", "0.0.0.0")
	v.SetDefault("server.environment", "development")
	v.SetDefault("server.app_name", "cloudnative-go-api")
	v.SetDefault("server.version", "v0.5.0")
	v.SetDefault("server.read_timeout", 30*time.Second)
	v.SetDefault("server.write_timeout", 30*time.Second)

	// Database 默认值
	v.SetDefault("database.enabled", false)
	v.SetDefault("database.host", "localhost")
	v.SetDefault("database.port", 5432)
	v.SetDefault("database.name", "myapp")
	v.SetDefault("database.user", "postgres")
	v.SetDefault("database.max_connections", 10)
	v.SetDefault("database.connection_timeout", 5*time.Second)

	// Redis 默认值
	v.SetDefault("redis.enabled", true)
	v.SetDefault("redis.host", "localhost")
	v.SetDefault("redis.port", 6379)
	v.SetDefault("redis.db", 0)
	v.SetDefault("redis.max_retries", 3)
	v.SetDefault("redis.pool_size", 10)
	v.SetDefault("redis.pool_timeout", 5*time.Second)

	// Log 默认值
	v.SetDefault("log.level", "info")
	v.SetDefault("log.format", "json")
	v.SetDefault("log.output", "stdout")
	v.SetDefault("log.enable_caller", true)
	v.SetDefault("log.enable_stacktrace", false)

	// Features 默认值
	v.SetDefault("features.enable_metrics", true)
	v.SetDefault("features.enable_health_check", true)
	v.SetDefault("features.enable_config_api", true)
	v.SetDefault("features.enable_hot_reload", true)
}
