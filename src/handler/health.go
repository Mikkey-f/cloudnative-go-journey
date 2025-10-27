package handler

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

var (
	startTime = time.Now()
	ready     = true // 可以根据实际情况（如数据库连接）动态设置
)

// HealthCheck 存活探针（Liveness Probe）
// K8s 用它检查容器是否还活着，失败会重启容器
func HealthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status": "healthy",
		"uptime": time.Since(startTime).String(),
	})
}

// ReadinessCheck 就绪探针（Readiness Probe）
// K8s 用它检查容器是否准备好接收流量
func ReadinessCheck(c *gin.Context) {
	if !ready {
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"status": "not ready",
			"reason": "service is starting up",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status": "ready",
		"uptime": time.Since(startTime).String(),
	})
}

// SetReady 设置就绪状态（可用于启动初始化）
func SetReady(isReady bool) {
	ready = isReady
}
