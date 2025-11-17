package handler

import (
	"os"

	"github.com/gin-gonic/gin"
)

// VersionHandler 返回 API 版本信息
// 用于金丝雀发布流量验证
// 版本号从环境变量 API_VERSION 读取，默认为 v1
func VersionHandler(c *gin.Context) {
	version := os.Getenv("API_VERSION")
	if version == "" {
		version = "v1"
	}

	message := "API v1 - Stable Version"
	if version == "v2" {
		message = "API v2 - Canary Version"
	}

	c.JSON(200, gin.H{
		"version": version,
		"service": "api",
		"message": message,
	})
}
