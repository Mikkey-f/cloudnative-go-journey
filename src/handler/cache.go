package handler

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/yourname/cloudnative-go-journey/src/cache"
)

// CacheHandler 缓存处理器
type CacheHandler struct {
	cache *cache.RedisCache
}

// NewCacheHandler 创建缓存处理器
func NewCacheHandler(c *cache.RedisCache) *CacheHandler {
	return &CacheHandler{cache: c}
}

// TestCache 测试缓存连接
// @Summary 测试Redis缓存
// @Description 测试Redis连接并返回统计信息
// @Tags cache
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/cache/test [get]
func (h *CacheHandler) TestCache(c *gin.Context) {
	// 测试 SET
	testKey := "temp:test:" + time.Now().Format("20060102150405")
	err := h.cache.Set(testKey, "test-value", 60*time.Second)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to set cache: " + err.Error(),
		})
		return
	}

	// 测试 GET
	value, err := h.cache.Get(testKey)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to get cache: " + err.Error(),
		})
		return
	}

	// 测试 EXISTS
	exists, _ := h.cache.Exists(testKey)

	// 清理测试键
	err = h.cache.Del(testKey)
	if err != nil {
		return
	}

	// 获取统计
	stats := h.cache.Stats()

	c.JSON(http.StatusOK, gin.H{
		"status":          "success",
		"redis_connected": true,
		"test_value":      value,
		"test_exists":     exists,
		"stats":           stats,
		"timestamp":       time.Now().Format(time.RFC3339),
	})
}

// GetConfig 获取配置信息
// @Summary 获取当前配置
// @Description 返回API服务的当前配置信息
// @Tags config
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/config [get]
func (h *CacheHandler) GetConfig(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"app_name":    "cloudnative-go-api",
		"version":     "v0.2.0",
		"environment": "production",
		"redis": gin.H{
			"connected": h.cache.Ping() == nil,
			"stats":     h.cache.Stats(),
		},
		"timestamp": time.Now().Format(time.RFC3339),
	})
}
