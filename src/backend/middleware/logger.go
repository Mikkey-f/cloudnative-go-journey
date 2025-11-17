package middleware

import (
	"log"
	"time"

	"github.com/gin-gonic/gin"
)

// Logger 日志中间件
func Logger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		method := c.Request.Method

		// 处理请求
		c.Next()

		// 计算耗时
		latency := time.Since(start)
		statusCode := c.Writer.Status()

		// 打印日志（简单格式）
		log.Printf("[%s] %s %s | Status: %d | Latency: %v",
			method,
			path,
			c.ClientIP(),
			statusCode,
			latency,
		)
	}
}
