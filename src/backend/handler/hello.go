package handler

import (
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
)

// Hello 简单的问候接口
func Hello(c *gin.Context) {
	name := c.DefaultQuery("name", "CloudNative")

	c.JSON(http.StatusOK, gin.H{
		"message":   "hi, " + name + "!",
		"timestamp": time.Now().Format(time.RFC3339),
		"pod":       os.Getenv("HOSTNAME"), // K8s 中 Pod 名称
	})
}

// Info 返回应用信息
func Info(c *gin.Context) {
	hostname, _ := os.Hostname()

	c.JSON(http.StatusOK, gin.H{
		"app":      "cloudnative-go-journey",
		"version":  "v0.1.0",
		"hostname": hostname,
		"env":      os.Getenv("ENVIRONMENT"),
		"golang":   "1.21+",
		"message":  "Welcome to CloudNative Go Journey! 🚀",
	})
}
