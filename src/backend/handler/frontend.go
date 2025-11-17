package handler

import (
	"github.com/gin-gonic/gin"
)

// FrontendHandler 处理前端请求，返回系统架构页面
func FrontendHandler(c *gin.Context) {
	c.HTML(200, "index.html", gin.H{
		"title":   "CloudNative Go Journey v0.4",
		"version": "v0.4",
		"service": "frontend",
	})
}

// FrontendHealthCheck 前端服务健康检查
func FrontendHealthCheck(c *gin.Context) {
	c.JSON(200, gin.H{
		"status":  "healthy",
		"service": "frontend",
		"version": "v0.4",
	})
}
