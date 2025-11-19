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

	"github.com/yourname/cloudnative-go-journey/src/backend/cache"
	"github.com/yourname/cloudnative-go-journey/src/backend/config"
	"github.com/yourname/cloudnative-go-journey/src/backend/handler"
	"github.com/yourname/cloudnative-go-journey/src/backend/metrics"
	"github.com/yourname/cloudnative-go-journey/src/backend/middleware"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
	// v0.5 新配置系统：加载配置
	configManager := config.NewManager()
	if err := configManager.Load(); err != nil {
		log.Fatalf("❌ 配置加载失败: %v", err)
	}
	
	cfg := configManager.GetConfig()
	log.Printf("✅ 配置加载成功 - 环境: %s, 版本: %s", cfg.Server.Environment, cfg.Server.Version)

	// v0.5 新功能：启动配置热更新监听
	if cfg.Features.EnableHotReload {
		configManager.Watch()
		
		// 注册配置变更回调
		configManager.OnChange(func(newCfg *config.AppConfig) {
			log.Printf("🔄 配置已更新 - 环境: %s, 日志级别: %s", newCfg.Server.Environment, newCfg.Log.Level)
		})
	}

	// 初始化 Redis 客户端（使用新配置系统）
	var redisCache *cache.RedisCache
	var err error
	if cfg.Redis.Enabled {
		redisFullAddr := fmt.Sprintf("%s:%d", cfg.Redis.Host, cfg.Redis.Port)
		log.Printf("🔗 Connecting to Redis at %s...", redisFullAddr)
		
		redisCache, err = cache.NewRedisCache(redisFullAddr)
		if err != nil {
			log.Printf("⚠️  Warning: Redis connection failed: %v", err)
			log.Printf("⚠️  Continuing without cache support...")
		} else {
			log.Printf("✅ Redis connected successfully")
			defer func(redisCache *cache.RedisCache) {
				err := redisCache.Close()
				if err != nil {
					log.Printf("⚠️  Warning: Redis connection close failed: %v", err)
				}
			}(redisCache)
		}
	} else {
		log.Println("ℹ️  Redis disabled in configuration")
	}

	// 设置 Gin 模式
	if cfg.Server.Environment == "production" {
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

	// v0.4 新增：前端服务
	router.GET("/", handler.FrontendHandler)
	router.GET("/frontend/health", handler.FrontendHealthCheck)

	// 业务接口
	api := router.Group("/api/v1")
	{
		// v0.1 接口
		api.GET("/hello", handler.Hello)
		api.GET("/info", handler.Info)

		// v0.4 新增：版本接口（用于金丝雀发布验证）
		api.GET("/version", handler.VersionHandler)
		
		// v0.5 新增：配置管理接口
		if cfg.Features.EnableConfigAPI {
			configHandler := handler.NewConfigHandler(configManager)
			configHandler.RegisterRoutes(api)
		}
	}

	// v0.2 新增：缓存和数据接口
	if redisCache != nil {
		cacheHandler := handler.NewCacheHandler(redisCache)
		dataHandler := handler.NewDataHandler(redisCache)

		api.GET("/cache/test", cacheHandler.TestCache)
		// api.GET("/config", cacheHandler.GetConfig) // v0.5: 已被 ConfigHandler 替代
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

	// 创建 HTTP 服务器（使用新配置）
	srv := &http.Server{
		Addr:         fmt.Sprintf("%s:%d", cfg.Server.Host, cfg.Server.Port),
		Handler:      router,
		ReadTimeout:  cfg.Server.ReadTimeout,
		WriteTimeout: cfg.Server.WriteTimeout,
	}

	// 启动服务器（goroutine）
	go func() {
		log.Printf("🚀 Server starting on %s:%d...", cfg.Server.Host, cfg.Server.Port)
		log.Printf("📊 Metrics available at http://localhost:%d/metrics", cfg.Server.Port)
		log.Printf("❤️  Health check at http://localhost:%d/health", cfg.Server.Port)
		if cfg.Features.EnableConfigAPI {
			log.Printf("⚙️  Config API available at http://localhost:%d/api/v1/config", cfg.Server.Port)
		}

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
