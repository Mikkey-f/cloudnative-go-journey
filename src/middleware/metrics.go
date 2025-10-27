package middleware

import (
	"strconv"
	"time"

	"github.com/yourname/cloudnative-go-journey/src/metrics"

	"github.com/gin-gonic/gin"
)

// Metrics Prometheus 指标收集中间件
func Metrics() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		method := c.Request.Method

		// 处理请求
		c.Next()

		// 记录指标
		duration := time.Since(start).Seconds()
		statusCode := strconv.Itoa(c.Writer.Status())

		// 跳过 /metrics 端点本身
		if path != "/metrics" {
			metrics.RequestCounter.WithLabelValues(method, path, statusCode).Inc()
			metrics.RequestDuration.WithLabelValues(method, path).Observe(duration)
		}
	}
}
