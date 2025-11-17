package config

import (
	"os"
	"strconv"
)

// Config 应用配置
type Config struct {
	Port        int
	Environment string
	AppName     string
	Version     string
}

// Load 加载配置
func Load() *Config {
	return &Config{
		Port:        getEnvAsInt("PORT", 8080),
		Environment: getEnv("ENVIRONMENT", "development"),
		AppName:     getEnv("APP_NAME", "cloudnative-go-api"),
		Version:     getEnv("VERSION", "v0.1.0"),
	}
}

// getEnv 获取环境变量（带默认值）
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// getEnvAsInt 获取环境变量为整数
func getEnvAsInt(key string, defaultValue int) int {
	valueStr := getEnv(key, "")
	if value, err := strconv.Atoi(valueStr); err == nil {
		return value
	}
	return defaultValue
}
