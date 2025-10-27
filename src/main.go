package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/yourname/cloudnative-go-journey/src/config"
	"github.com/yourname/cloudnative-go-journey/src/handler"
	"github.com/yourname/cloudnative-go-journey/src/metrics"
	"github.com/yourname/cloudnative-go-journey/src/middleware"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
	// 加载配置
	cfg := config.Load()

	// 设置 Gin 模式，release模式精简日志
	if cfg.Environment == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	// 创建路由
	router := gin.New()

	// 中间件
	// 防止panic导致服务退出
	router.Use(gin.Recovery())
	router.Use(middleware.Logger())
	router.Use(middleware.Metrics())

	// 健康检查接口（K8s 探针使用）
	router.GET("/health", handler.HealthCheck)
	router.GET("/ready", handler.ReadinessCheck)

	// 业务接口
	api := router.Group("/api/v1")
	{
		api.GET("/hello", handler.Hello)
		api.GET("/info", handler.Info)
	}

	// Prometheus 指标接口
	router.GET("/metrics", gin.WrapH(promhttp.Handler()))

	// 初始化 Prometheus 指标
	metrics.Init()

	// 创建 HTTP 服务器
	srv := &http.Server{
		Addr:    fmt.Sprintf(":%d", cfg.Port),
		Handler: router,
	}

	// 启动服务器（goroutine）
	go func() {
		log.Printf("🚀 Server starting on port %d...", cfg.Port)
		log.Printf("📊 Metrics available at http://localhost:%d/metrics", cfg.Port)
		log.Printf("❤️  Health check at http://localhost:%d/health", cfg.Port)

		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()

	// 优雅关闭
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("🛑 Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("✅ Server exited")
}
