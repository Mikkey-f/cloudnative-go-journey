package handler

import (
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/yourname/cloudnative-go-journey/src/cache"
)

// DataHandler 数据处理器
type DataHandler struct {
	cache *cache.RedisCache
}

// NewDataHandler 创建数据处理器
func NewDataHandler(c *cache.RedisCache) *DataHandler {
	return &DataHandler{cache: c}
}

// CreateDataRequest 创建数据请求
type CreateDataRequest struct {
	Key   string `json:"key" binding:"required"`
	Value string `json:"value" binding:"required"`
	TTL   int    `json:"ttl"` // 秒，默认3600
}

// CreateData 创建数据
// @Summary 创建数据
// @Description 将数据写入Redis缓存
// @Tags data
// @Accept json
// @Produce json
// @Param data body CreateDataRequest true "数据信息"
// @Success 201 {object} map[string]interface{}
// @Router /api/v1/data [post]
func (h *DataHandler) CreateData(c *gin.Context) {
	var req CreateDataRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 强制添加 cache: 前缀
	cacheKey := "cache:" + req.Key

	// 默认 TTL 1 小时
	ttl := time.Duration(req.TTL) * time.Second
	if ttl == 0 {
		ttl = 1 * time.Hour
	}

	// 保存到 Redis
	err := h.cache.Set(cacheKey, req.Value, ttl)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to save data: " + err.Error(),
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"status":    "created",
		"key":       req.Key,
		"ttl":       req.TTL,
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

// GetData 获取数据
// @Summary 获取数据
// @Description 从Redis缓存读取数据
// @Tags data
// @Produce json
// @Param key path string true "数据键"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/data/{key} [get]
func (h *DataHandler) GetData(c *gin.Context) {
	key := c.Param("key")

	cacheKey := "cache:" + key
	// 从 Redis 获取
	value, err := h.cache.Get(cacheKey)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error":     "Key not found",
			"key":       key,
			"timestamp": time.Now().Format(time.RFC3339),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"key":       key,
		"value":     value,
		"cached":    true,
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

// DeleteData 删除数据
// @Summary 删除数据
// @Description 从Redis缓存删除数据
// @Tags data
// @Produce json
// @Param key path string true "数据键"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/data/{key} [delete]
func (h *DataHandler) DeleteData(c *gin.Context) {
	key := c.Param("key")

	// 添加前缀
	cacheKey := "cache:" + key

	// 检查键是否存在
	exists, err := h.cache.Exists(cacheKey)
	if err != nil || !exists {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Key not found",
			"key":   key,
		})
		return
	}

	// 删除键
	err = h.cache.Del(cacheKey)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to delete key: " + err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":    "deleted",
		"key":       key,
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

// ListKeys 列出所有键（用于演示，生产环境慎用）
// @Summary 列出键
// @Description 列出Redis中匹配模式的键
// @Tags data
// @Produce json
// @Param pattern query string false "匹配模式" default(*)
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/data [get]
func (h *DataHandler) ListKeys(c *gin.Context) {
	pattern := c.DefaultQuery("pattern", "*")

	// 注意：KEYS 命令在生产环境可能影响性能
	// 这里仅用于演示
	keys, err := h.cache.Client.Keys(h.cache.Ctx, pattern).Result()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// 简单实现：返回提示信息
	c.JSON(http.StatusOK, gin.H{
		"message":   fmt.Sprintf("List keys with pattern: %s", pattern),
		"keys":      keys,
		"note":      "This is a demo endpoint. Use SCAN in production.",
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

// GetCacheStats 获取缓存统计
// @Summary 缓存统计
// @Description 获取缓存命中率等统计信息
// @Tags cache
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/cache/stats [get]
func (h *DataHandler) GetCacheStats(c *gin.Context) {
	stats := h.cache.Stats()

	// 计算命中率
	hits := 0
	misses := 0
	if h, ok := stats["hits"].(uint32); ok {
		hits = int(h)
	}
	if m, ok := stats["misses"].(uint32); ok {
		misses = int(m)
	}

	total := hits + misses
	hitRate := 0.0
	if total > 0 {
		hitRate = float64(hits) / float64(total)
	}

	c.JSON(http.StatusOK, gin.H{
		"cache_stats":    stats,
		"hit_rate":       strconv.FormatFloat(hitRate, 'f', 4, 64),
		"total_requests": total,
		"timestamp":      time.Now().Format(time.RFC3339),
	})
}
