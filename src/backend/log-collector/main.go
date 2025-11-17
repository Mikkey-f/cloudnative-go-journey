package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	// Prometheus 指标
	logsCollected = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "logs_collected_total",
			Help: "Total number of logs collected by this collector",
		},
		[]string{"node"},
	)

	collectorUptime = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "log_collector_uptime_seconds",
			Help: "Time since the log collector started",
		},
	)
)

func init() {
	// 注册 Prometheus 指标
	prometheus.MustRegister(logsCollected)
	prometheus.MustRegister(collectorUptime)
}

func main() {
	// 获取节点名称（从环境变量，由 K8s DaemonSet 注入）
	nodeName := os.Getenv("NODE_NAME")
	if nodeName == "" {
		nodeName = "unknown-node"
	}

	log.Printf("📊 日志采集器启动")
	log.Printf("📍 节点名称: %s", nodeName)
	log.Printf("🔧 版本: v0.2.0")

	// 启动 HTTP 服务（健康检查 + 指标）
	go startHTTPServer()

	// 启动计时器，记录运行时间
	go func() {
		ticker := time.NewTicker(1 * time.Second)
		defer ticker.Stop()
		for range ticker.C {
			collectorUptime.Add(1)
		}
	}()

	// 模拟日志采集（每10秒采集一次）
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	log.Printf("✅ 开始采集日志...")

	for {
		select {
		case <-ticker.C:
			collectLogs(nodeName)
		}
	}
}

// collectLogs 模拟日志采集
func collectLogs(nodeName string) {
	// 在实际场景中，这里会：
	// 1. 读取 /var/log/ 目录下的日志文件
	// 2. 解析日志内容
	// 3. 发送到日志中心（如 ElasticSearch, Loki 等）

	// 这里模拟采集到 10-50 条日志
	logCount := 10 + (time.Now().Unix() % 40)

	// 输出到标准输出（K8s 会收集）
	fmt.Printf("[%s] [%s] 采集日志: %d 条\n",
		time.Now().Format("2006-01-02 15:04:05"),
		nodeName,
		logCount)

	// 记录到 Prometheus 指标
	logsCollected.WithLabelValues(nodeName).Add(float64(logCount))
}

// startHTTPServer 启动 HTTP 服务
func startHTTPServer() {
	mux := http.NewServeMux()

	// 健康检查端点
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, err := w.Write([]byte("OK"))
		if err != nil {
			return
		}
	})

	// Prometheus 指标端点
	mux.Handle("/metrics", promhttp.Handler())

	// 信息端点
	mux.HandleFunc("/info", func(w http.ResponseWriter, r *http.Request) {
		nodeName := os.Getenv("NODE_NAME")
		info := fmt.Sprintf(`{
  "service": "log-collector",
  "version": "v0.2.0",
  "node": "%s",
  "status": "running"
}`, nodeName)
		w.Header().Set("Content-Type", "application/json")
		_, err := w.Write([]byte(info))
		if err != nil {
			return
		}
	})

	log.Printf("🌐 HTTP 服务启动在端口 8080")
	log.Printf("   健康检查: http://localhost:8080/health")
	log.Printf("   指标接口: http://localhost:8080/metrics")
	log.Printf("   信息接口: http://localhost:8080/info")

	if err := http.ListenAndServe(":8080", mux); err != nil {
		log.Fatalf("HTTP 服务启动失败: %v", err)
	}
}
