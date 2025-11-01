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

	"github.com/yourname/cloudnative-go-journey/src/cache"
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

	// 初始化 Redis 客户端
	redisAddr := os.Getenv("REDIS_HOST")
	if redisAddr == "" {
		redisAddr = "localhost" // 本地开发默认值
	}
	redisPort := os.Getenv("REDIS_PORT")
	if redisPort == "" {
		redisPort = "6379"
	}
	redisFullAddr := fmt.Sprintf("%s:%s", redisAddr, redisPort)

	log.Printf("🔗 Connecting to Redis at %s...", redisFullAddr)
	redisCache, err := cache.NewRedisCache(redisFullAddr)
	if err != nil {
		log.Printf("⚠️  Warning: Redis connection failed: %v", err)
		log.Printf("⚠️  Continuing without cache support...")
		// 在生产环境可能需要 fatal，这里为了演示继续运行
	} else {
		log.Printf("✅ Redis connected successfully")
		defer func(redisCache *cache.RedisCache) {
			err := redisCache.Close()
			if err != nil {
				log.Fatalln("<UNK>  Warning: Redis connection close failed:", err)
			}
		}(redisCache)
	}

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
		// v0.1 接口
		api.GET("/hello", handler.Hello)
		api.GET("/info", handler.Info)
	}

	// v0.2 新增：缓存和数据接口
	if redisCache != nil {
		cacheHandler := handler.NewCacheHandler(redisCache)
		dataHandler := handler.NewDataHandler(redisCache)

		api.GET("/cache/test", cacheHandler.TestCache)
		api.GET("/config", cacheHandler.GetConfig)
		api.GET("/cache/stats", dataHandler.GetCacheStats)

		api.POST("/data", dataHandler.CreateData)
		api.GET("/data/:key", dataHandler.GetData)
		api.DELETE("/data/:key", dataHandler.DeleteData)
		api.GET("/data", dataHandler.ListKeys)
	}

	// v0.3 新增：工作负载测试接口（用于 HPA 测试）
	workload := api.Group("/workload")
	{
		workload.GET("", handler.WorkloadHandler)               // 综合负载
		workload.GET("/cpu", handler.CPUIntensiveHandler)       // CPU 密集型
		workload.GET("/memory", handler.MemoryIntensiveHandler) // 内存密集型
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
