# v0.2 项目结构规划

> 详细的代码组织和文件结构

---

## 📁 完整项目结构

```
cloudnative-go-journey-plan/
├── src/                                # Go 源代码
│   ├── main.go                        # API 服务主入口
│   │
│   ├── config/                        # 配置管理
│   │   └── config.go                  # 配置加载和管理
│   │
│   ├── handler/                       # HTTP 处理器
│   │   ├── health.go                  # 健康检查（v0.1）
│   │   ├── hello.go                   # Hello 接口（v0.1）
│   │   ├── cache.go                   # 🆕 缓存测试接口
│   │   └── data.go                    # 🆕 数据接口（带缓存）
│   │
│   ├── middleware/                    # 中间件
│   │   ├── logger.go                  # 日志中间件（v0.1）
│   │   └── metrics.go                 # 指标中间件（v0.1）
│   │
│   ├── metrics/                       # 监控指标
│   │   └── prometheus.go              # Prometheus 指标（v0.1）
│   │
│   ├── cache/                         # 🆕 缓存层
│   │   ├── redis.go                   # Redis 客户端封装
│   │   └── interface.go               # 缓存接口定义
│   │
│   ├── log-collector/                 # 🆕 日志采集器服务
│   │   ├── main.go                    # 主入口
│   │   ├── collector.go               # 日志采集逻辑
│   │   └── metrics.go                 # 指标暴露
│   │
│   └── cleanup-job/                   # 🆕 清理任务
│       └── main.go                    # 定时清理脚本
│
├── k8s/                               # Kubernetes 配置
│   ├── v0.1/                          # v0.1 配置（保留）
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── README.md
│   │
│   └── v0.2/                          # 🆕 v0.2 配置
│       ├── api/                       # API 服务
│       │   ├── deployment.yaml        # Deployment 配置
│       │   ├── service.yaml           # Service 配置
│       │   └── configmap.yaml         # 配置文件
│       │
│       ├── redis/                     # Redis 有状态服务
│       │   ├── statefulset.yaml       # StatefulSet 配置
│       │   ├── service.yaml           # Headless Service
│       │   └── configmap.yaml         # Redis 配置文件
│       │
│       ├── log-collector/             # 日志采集器
│       │   └── daemonset.yaml         # DaemonSet 配置
│       │
│       ├── cleanup-job/               # 清理任务
│       │   └── cronjob.yaml           # CronJob 配置
│       │
│       └── README.md                  # 部署文档
│
├── docs/                              # 文档
│   ├── v0.1/                          # v0.1 文档（保留）
│   └── v0.2/                          # 🆕 v0.2 文档
│       ├── GOALS.md                   # 学习目标
│       ├── ASSESSMENT.md              # 技能评估
│       ├── ARCHITECTURE.md            # 架构设计
│       ├── PROJECT-STRUCTURE.md       # 本文件
│       ├── SETUP-GUIDE.md             # 环境搭建（待创建）
│       ├── DEPLOYMENT.md              # 部署指南（待创建）
│       ├── FAQ.md                     # 常见问题（待创建）
│       └── TROUBLESHOOTING.md         # 故障排查（待创建）
│
├── blog/                              # 博客文章
│   ├── v0.1/                          # v0.1 博客（保留）
│   └── v0.2/                          # 🆕 v0.2 博客
│       ├── 04-k8s-workloads.md        # 工作负载指南（待创建）
│       ├── 05-statefulset-redis.md    # StatefulSet 实战（待创建）
│       ├── 06-daemonset.md            # DaemonSet 实战（待创建）
│       ├── 07-configmap-secret.md     # 配置管理（待创建）
│       └── README.md                  # 博客索引（待创建）
│
├── scripts/                           # 自动化脚本
│   ├── deploy-v0.1.ps1                # v0.1 部署（保留）
│   └── deploy-v0.2.ps1                # 🆕 v0.2 部署（待创建）
│
├── go.mod                             # Go 模块定义
├── go.sum                             # Go 依赖锁定
├── Dockerfile                         # API 服务镜像（待更新）
├── Dockerfile.log-collector           # 🆕 日志采集器镜像（待创建）
├── Dockerfile.cleanup-job             # 🆕 清理任务镜像（待创建）
├── README.md                          # 项目 README（待更新）
└── CHANGELOG.md                       # 变更日志（待更新）
```

---

## 🔧 代码文件详解

### 1. API 服务改进

#### src/cache/redis.go

```go
package cache

import (
    "context"
    "time"
    
    "github.com/go-redis/redis/v8"
)

// RedisCache Redis 缓存客户端
type RedisCache struct {
    client *redis.Client
    ctx    context.Context
}

// NewRedisCache 创建 Redis 缓存客户端
func NewRedisCache(addr string) (*RedisCache, error) {
    client := redis.NewClient(&redis.Options{
        Addr:         addr,
        Password:     "",
        DB:           0,
        DialTimeout:  5 * time.Second,
        ReadTimeout:  3 * time.Second,
        WriteTimeout: 3 * time.Second,
    })
    
    ctx := context.Background()
    
    // 测试连接
    if err := client.Ping(ctx).Err(); err != nil {
        return nil, err
    }
    
    return &RedisCache{
        client: client,
        ctx:    ctx,
    }, nil
}

// Get 获取缓存
func (r *RedisCache) Get(key string) (string, error) {
    return r.client.Get(r.ctx, key).Result()
}

// Set 设置缓存
func (r *RedisCache) Set(key string, value string, ttl time.Duration) error {
    return r.client.Set(r.ctx, key, value, ttl).Err()
}

// Del 删除缓存
func (r *RedisCache) Del(key string) error {
    return r.client.Del(r.ctx, key).Err()
}

// Exists 检查键是否存在
func (r *RedisCache) Exists(key string) (bool, error) {
    result, err := r.client.Exists(r.ctx, key).Result()
    return result > 0, err
}

// Close 关闭连接
func (r *RedisCache) Close() error {
    return r.client.Close()
}

// Stats 获取统计信息
func (r *RedisCache) Stats() map[string]interface{} {
    stats := r.client.PoolStats()
    return map[string]interface{}{
        "hits":       stats.Hits,
        "misses":     stats.Misses,
        "timeouts":   stats.Timeouts,
        "total_conns": stats.TotalConns,
        "idle_conns":  stats.IdleConns,
    }
}
```

#### src/cache/interface.go

```go
package cache

import "time"

// Cache 缓存接口
type Cache interface {
    Get(key string) (string, error)
    Set(key string, value string, ttl time.Duration) error
    Del(key string) error
    Exists(key string) (bool, error)
    Close() error
}
```

#### src/handler/cache.go

```go
package handler

import (
    "net/http"
    
    "github.com/gin-gonic/gin"
    "cloudnative-go-journey/src/cache"
)

// CacheHandler 缓存处理器
type CacheHandler struct {
    cache *cache.RedisCache
}

// NewCacheHandler 创建缓存处理器
func NewCacheHandler(c *cache.RedisCache) *CacheHandler {
    return &CacheHandler{cache: c}
}

// TestCache 测试缓存连接
func (h *CacheHandler) TestCache(c *gin.Context) {
    // 测试 SET
    err := h.cache.Set("test:key", "test-value", 60)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{
            "error": "Failed to set cache: " + err.Error(),
        })
        return
    }
    
    // 测试 GET
    value, err := h.cache.Get("test:key")
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{
            "error": "Failed to get cache: " + err.Error(),
        })
        return
    }
    
    // 获取统计
    stats := h.cache.Stats()
    
    c.JSON(http.StatusOK, gin.H{
        "status":   "success",
        "redis_connected": true,
        "test_value": value,
        "stats":    stats,
    })
}
```

#### src/handler/data.go

```go
package handler

import (
    "fmt"
    "net/http"
    "time"
    
    "github.com/gin-gonic/gin"
    "cloudnative-go-journey/src/cache"
)

// DataHandler 数据处理器
type DataHandler struct {
    cache *cache.RedisCache
}

// NewDataHandler 创建数据处理器
func NewDataHandler(c *cache.RedisCache) *DataHandler {
    return &DataHandler{cache: c}
}

// CreateData 创建数据
func (h *DataHandler) CreateData(c *gin.Context) {
    var req struct {
        Key   string `json:"key" binding:"required"`
        Value string `json:"value" binding:"required"`
        TTL   int    `json:"ttl"`  // 秒
    }
    
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }
    
    // 默认 TTL 1 小时
    ttl := time.Duration(req.TTL) * time.Second
    if ttl == 0 {
        ttl = 1 * time.Hour
    }
    
    // 保存到 Redis
    err := h.cache.Set(req.Key, req.Value, ttl)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{
            "error": "Failed to save data: " + err.Error(),
        })
        return
    }
    
    c.JSON(http.StatusCreated, gin.H{
        "status": "created",
        "key":    req.Key,
        "ttl":    req.TTL,
    })
}

// GetData 获取数据
func (h *DataHandler) GetData(c *gin.Context) {
    key := c.Param("key")
    
    // 从 Redis 获取
    value, err := h.cache.Get(key)
    if err != nil {
        c.JSON(http.StatusNotFound, gin.H{
            "error": "Key not found: " + key,
        })
        return
    }
    
    c.JSON(http.StatusOK, gin.H{
        "key":       key,
        "value":     value,
        "cached":    true,
        "timestamp": time.Now().Format(time.RFC3339),
    })
}
```

---

### 2. 日志采集器服务

#### src/log-collector/main.go

```go
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
    logsCollected = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "logs_collected_total",
            Help: "Total number of logs collected",
        },
        []string{"node"},
    )
)

func init() {
    prometheus.MustRegister(logsCollected)
}

func main() {
    nodeName := os.Getenv("NODE_NAME")
    if nodeName == "" {
        nodeName = "unknown"
    }
    
    log.Printf("日志采集器启动在节点: %s", nodeName)
    
    // 启动 HTTP 服务（健康检查 + 指标）
    go func() {
        http.HandleFunc("/health", healthHandler)
        http.Handle("/metrics", promhttp.Handler())
        log.Fatal(http.ListenAndServe(":8080", nil))
    }()
    
    // 模拟日志采集
    ticker := time.NewTicker(10 * time.Second)
    defer ticker.Stop()
    
    for range ticker.C {
        collectLogs(nodeName)
    }
}

func collectLogs(nodeName string) {
    // 模拟采集日志
    logCount := 10 // 假设每次采集 10 条
    
    // 输出日志
    fmt.Printf("[%s] 采集到 %d 条日志\n", nodeName, logCount)
    
    // 记录指标
    logsCollected.WithLabelValues(nodeName).Add(float64(logCount))
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusOK)
    w.Write([]byte("OK"))
}
```

---

### 3. 清理任务

#### src/cleanup-job/main.go

```go
package main

import (
    "context"
    "log"
    "os"
    "time"
    
    "github.com/go-redis/redis/v8"
)

func main() {
    log.Println("清理任务开始执行...")
    
    // 连接 Redis
    redisHost := os.Getenv("REDIS_HOST")
    if redisHost == "" {
        redisHost = "redis-service:6379"
    }
    
    rdb := redis.NewClient(&redis.Options{
        Addr: redisHost,
    })
    defer rdb.Close()
    
    ctx := context.Background()
    
    // 测试连接
    if err := rdb.Ping(ctx).Err(); err != nil {
        log.Fatalf("无法连接 Redis: %v", err)
    }
    
    // 清理逻辑
    cleaned := cleanupExpiredKeys(rdb, ctx)
    
    log.Printf("清理完成，删除了 %d 个过期键", cleaned)
}

func cleanupExpiredKeys(rdb *redis.Client, ctx context.Context) int {
    // 获取所有以 cache: 开头的键
    keys, err := rdb.Keys(ctx, "cache:*").Result()
    if err != nil {
        log.Printf("获取键列表失败: %v", err)
        return 0
    }
    
    cleaned := 0
    for _, key := range keys {
        // 检查 TTL
        ttl := rdb.TTL(ctx, key).Val()
        
        // 如果已过期（TTL < 0）
        if ttl == -2 || ttl == -1 { // -2: 不存在, -1: 无过期时间但我们清理它
            rdb.Del(ctx, key)
            cleaned++
            log.Printf("删除键: %s", key)
        }
    }
    
    return cleaned
}
```

---

## 📦 Kubernetes 配置文件

### k8s/v0.2/api/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
  labels:
    app: api
    version: v0.2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
        version: v0.2
    spec:
      containers:
      - name: api
        image: cloudnative-go-api:v0.2
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: APP_ENV
          value: "production"
        - name: REDIS_HOST
          value: "redis-service"
        - name: REDIS_PORT
          value: "6379"
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: api-config
              key: log_level
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
```

### k8s/v0.2/api/configmap.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-config
data:
  log_level: "info"
  cache_ttl: "3600"
  max_connections: "100"
```

---

### k8s/v0.2/redis/statefulset.yaml

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
spec:
  serviceName: redis-service
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
          name: redis
        command:
        - redis-server
        - /etc/redis/redis.conf
        volumeMounts:
        - name: redis-data
          mountPath: /data
        - name: redis-config
          mountPath: /etc/redis
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: redis-config
        configMap:
          name: redis-config
  volumeClaimTemplates:
  - metadata:
      name: redis-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
```

### k8s/v0.2/redis/service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis-service
spec:
  clusterIP: None  # Headless Service
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
    name: redis
```

### k8s/v0.2/redis/configmap.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
data:
  redis.conf: |
    bind 0.0.0.0
    port 6379
    maxmemory 128mb
    maxmemory-policy allkeys-lru
    save 900 1
    save 300 10
    save 60 10000
    dir /data
    appendonly yes
    appendfilename "appendonly.aof"
```

---

### k8s/v0.2/log-collector/daemonset.yaml

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-collector
  labels:
    app: log-collector
spec:
  selector:
    matchLabels:
      app: log-collector
  template:
    metadata:
      labels:
        app: log-collector
    spec:
      containers:
      - name: collector
        image: log-collector:v0.2
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        volumeMounts:
        - name: varlog
          mountPath: /var/log
          readOnly: true
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      tolerations:
      - effect: NoSchedule
        operator: Exists
```

---

### k8s/v0.2/cleanup-job/cronjob.yaml

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup-job
spec:
  schedule: "0 * * * *"  # 每小时执行
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: cleanup
            image: cleanup-job:v0.2
            imagePullPolicy: IfNotPresent
            env:
            - name: REDIS_HOST
              value: "redis-service:6379"
            resources:
              requests:
                memory: "64Mi"
                cpu: "50m"
              limits:
                memory: "128Mi"
                cpu: "100m"
      backoffLimit: 3
      activeDeadlineSeconds: 300
```

---

## 🐳 Dockerfile 更新

### Dockerfile (API 服务)

```dockerfile
# 构建阶段
FROM golang:1.21-alpine AS builder

WORKDIR /app

# 复制 go.mod 和 go.sum
COPY go.mod go.sum ./
RUN go mod download

# 复制源代码
COPY src/ ./src/

# 构建（包含新增的 cache 包）
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o api ./src/main.go

# 运行阶段
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

COPY --from=builder /app/api .

EXPOSE 8080

CMD ["./api"]
```

### Dockerfile.log-collector

```dockerfile
FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY src/log-collector/ ./src/log-collector/

RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o collector ./src/log-collector/main.go

FROM alpine:latest

WORKDIR /root/

COPY --from=builder /app/collector .

EXPOSE 8080

CMD ["./collector"]
```

### Dockerfile.cleanup-job

```dockerfile
FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY src/cleanup-job/ ./src/cleanup-job/

RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o cleanup ./src/cleanup-job/main.go

FROM alpine:latest

WORKDIR /root/

COPY --from=builder /app/cleanup .

CMD ["./cleanup"]
```

---

## 📦 依赖管理

### go.mod 更新

```go
module github.com/yourname/cloudnative-go-journey

go 1.21

require (
    github.com/gin-gonic/gin v1.9.1
    github.com/go-redis/redis/v8 v8.11.5      // 新增
    github.com/prometheus/client_golang v1.18.0
)
```

---

## 🚀 构建和部署流程

### 1. 构建镜像

```bash
# API 服务
docker build -t cloudnative-go-api:v0.2 .

# 日志采集器
docker build -f Dockerfile.log-collector -t log-collector:v0.2 .

# 清理任务
docker build -f Dockerfile.cleanup-job -t cleanup-job:v0.2 .
```

### 2. 加载到 Minikube

```bash
minikube image load cloudnative-go-api:v0.2
minikube image load log-collector:v0.2
minikube image load cleanup-job:v0.2
```

### 3. 部署到 K8s

```bash
# 部署 Redis
kubectl apply -f k8s/v0.2/redis/

# 部署 API
kubectl apply -f k8s/v0.2/api/

# 部署日志采集器
kubectl apply -f k8s/v0.2/log-collector/

# 部署清理任务
kubectl apply -f k8s/v0.2/cleanup-job/
```

---

## ✅ 项目结构检查清单

完成后确认：

- [ ] 所有目录已创建
- [ ] 所有 Go 代码文件已编写
- [ ] 所有 K8s 配置文件已编写
- [ ] 所有 Dockerfile 已编写
- [ ] go.mod 已更新
- [ ] 文档已完善
- [ ] 脚本已准备

---

**项目结构规划完成！准备开始编码实施！** 🚀


