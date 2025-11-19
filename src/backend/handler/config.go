package handler

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/yourname/cloudnative-go-journey/src/backend/config"
)

// ConfigHandler 配置管理 Handler
type ConfigHandler struct {
	manager *config.Manager
}

// NewConfigHandler 创建配置 Handler
func NewConfigHandler(manager *config.Manager) *ConfigHandler {
	return &ConfigHandler{
		manager: manager,
	}
}

// GetConfig 获取完整配置（脱敏）
// GET /api/v1/config
func (h *ConfigHandler) GetConfig(c *gin.Context) {
	cfg := h.manager.GetConfig()

	// 脱敏
	sanitized := h.sanitizeConfig(cfg)

	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"data":   sanitized,
	})
}

// GetConfigField 获取指定字段配置
// GET /api/v1/config/:field
func (h *ConfigHandler) GetConfigField(c *gin.Context) {
	field := c.Param("field")
	cfg := h.manager.GetConfig()

	// 根据字段名获取值
	value := h.getFieldValue(cfg, field)
	if value == nil {
		c.JSON(http.StatusNotFound, gin.H{
			"status":  "error",
			"message": "配置字段不存在",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"data": gin.H{
			"field": field,
			"value": value,
		},
	})
}

// GetHotReloadableFields 获取可热更新字段列表
// GET /api/v1/config/hot-reloadable
func (h *ConfigHandler) GetHotReloadableFields(c *gin.Context) {
	fields := config.GetHotReloadableFields()

	c.JSON(http.StatusOK, gin.H{
		"status": "success",
		"data": gin.H{
			"fields": fields,
			"count":  len(fields),
		},
	})
}

// ReloadConfig 手动触发配置重载
// POST /api/v1/config/reload
func (h *ConfigHandler) ReloadConfig(c *gin.Context) {
	if err := h.manager.ReloadManually(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"status":  "error",
			"message": "配置重载失败",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":  "success",
		"message": "配置已重载",
	})
}

// sanitizeConfig 脱敏配置（隐藏敏感信息）
func (h *ConfigHandler) sanitizeConfig(cfg *config.AppConfig) map[string]interface{} {
	return map[string]interface{}{
		"server": map[string]interface{}{
			"port":          cfg.Server.Port,
			"host":          cfg.Server.Host,
			"environment":   cfg.Server.Environment,
			"app_name":      cfg.Server.AppName,
			"version":       cfg.Server.Version,
			"read_timeout":  cfg.Server.ReadTimeout.String(),
			"write_timeout": cfg.Server.WriteTimeout.String(),
		},
		"database": map[string]interface{}{
			"enabled":            cfg.Database.Enabled,
			"host":               cfg.Database.Host,
			"port":               cfg.Database.Port,
			"name":               cfg.Database.Name,
			"user":               cfg.Database.User,
			"password":           "***", // 隐藏密码
			"max_connections":    cfg.Database.MaxConnections,
			"connection_timeout": cfg.Database.ConnectionTimeout.String(),
		},
		"redis": map[string]interface{}{
			"enabled":      cfg.Redis.Enabled,
			"host":         cfg.Redis.Host,
			"port":         cfg.Redis.Port,
			"password":     "***", // 隐藏密码
			"db":           cfg.Redis.DB,
			"max_retries":  cfg.Redis.MaxRetries,
			"pool_size":    cfg.Redis.PoolSize,
			"pool_timeout": cfg.Redis.PoolTimeout.String(),
		},
		"log": map[string]interface{}{
			"level":             cfg.Log.Level,
			"format":            cfg.Log.Format,
			"output":            cfg.Log.Output,
			"enable_caller":     cfg.Log.EnableCaller,
			"enable_stacktrace": cfg.Log.EnableStacktrace,
		},
		"features": map[string]interface{}{
			"enable_metrics":      cfg.Features.EnableMetrics,
			"enable_health_check": cfg.Features.EnableHealthCheck,
			"enable_config_api":   cfg.Features.EnableConfigAPI,
			"enable_hot_reload":   cfg.Features.EnableHotReload,
		},
	}
}

// getFieldValue 根据字段路径获取值
func (h *ConfigHandler) getFieldValue(cfg *config.AppConfig, field string) interface{} {
	parts := strings.Split(field, ".")
	if len(parts) < 2 {
		return nil
	}

	section := parts[0]
	key := parts[1]

	switch section {
	case "server":
		switch key {
		case "port":
			return cfg.Server.Port
		case "host":
			return cfg.Server.Host
		case "environment":
			return cfg.Server.Environment
		case "app_name":
			return cfg.Server.AppName
		case "version":
			return cfg.Server.Version
		}
	case "log":
		switch key {
		case "level":
			return cfg.Log.Level
		case "format":
			return cfg.Log.Format
		case "output":
			return cfg.Log.Output
		}
	case "redis":
		switch key {
		case "host":
			return cfg.Redis.Host
		case "port":
			return cfg.Redis.Port
		case "pool_size":
			return cfg.Redis.PoolSize
		}
	case "features":
		switch key {
		case "enable_metrics":
			return cfg.Features.EnableMetrics
		case "enable_config_api":
			return cfg.Features.EnableConfigAPI
		}
	}

	return nil
}

// RegisterRoutes 注册配置管理路由
func (h *ConfigHandler) RegisterRoutes(r *gin.RouterGroup) {
	config := r.Group("/config")
	{
		config.GET("", h.GetConfig)
		config.GET("/hot-reloadable", h.GetHotReloadableFields)
		config.GET("/:field", h.GetConfigField)
		config.POST("/reload", h.ReloadConfig)
	}
}
