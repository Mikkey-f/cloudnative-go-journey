package config

import (
	"fmt"

	"github.com/go-playground/validator/v10"
)

// Validator 配置验证器接口
type Validator interface {
	Validate(cfg *AppConfig) error
}

// DefaultValidator 默认验证器
type DefaultValidator struct {
	validate *validator.Validate
}

// Validate 验证配置
func (v *DefaultValidator) Validate(cfg *AppConfig) error {
	if v.validate == nil {
		v.validate = validator.New()
	}

	if err := v.validate.Struct(cfg); err != nil {
		return fmt.Errorf("配置验证失败: %w", err)
	}

	// 额外的业务逻辑验证
	if err := v.validateBusinessLogic(cfg); err != nil {
		return err
	}

	return nil
}

// validateBusinessLogic 业务逻辑验证
func (v *DefaultValidator) validateBusinessLogic(cfg *AppConfig) error {
	// 验证 Redis 启用时的配置
	if cfg.Redis.Enabled {
		if cfg.Redis.Host == "" {
			return fmt.Errorf("Redis 已启用但未配置 Host")
		}
		if cfg.Redis.Port == 0 {
			return fmt.Errorf("Redis 已启用但未配置 Port")
		}
	}

	// 验证 Database 启用时的配置
	if cfg.Database.Enabled {
		if cfg.Database.Host == "" {
			return fmt.Errorf("Database 已启用但未配置 Host")
		}
		if cfg.Database.Port == 0 {
			return fmt.Errorf("Database 已启用但未配置 Port")
		}
	}

	// 验证生产环境的配置
	if cfg.Server.Environment == "production" {
		if cfg.Log.Level == "debug" {
			return fmt.Errorf("生产环境不应使用 debug 日志级别")
		}
		if cfg.Log.EnableStacktrace {
			return fmt.Errorf("生产环境不应启用堆栈跟踪")
		}
	}

	return nil
}
