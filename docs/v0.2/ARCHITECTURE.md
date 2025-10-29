# v0.2 架构设计文档

> CloudNative Go Journey v0.2 - 编排升级版架构详解

---

## 📐 整体架构

### 架构图

```
┌────────────────────────────────────────────────────────────────┐
│                     Minikube 集群                               │
│                                                                │
│  用户请求                                                        │
│     ↓                                                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  API Service (NodePort 30080)                           │  │
│  │  负载均衡                                                │  │
│  └──────────────────────────────────────────────────────────┘  │
│     ↓                           ↓                              │
│  ┌─────────────────┐      ┌─────────────────┐                 │
│  │  API Pod 1      │      │  API Pod 2      │                 │
│  │  ┌───────────┐  │      │  ┌───────────┐  │                 │
│  │  │ Gin Web   │  │      │  │ Gin Web   │  │                 │
│  │  │ Server    │  │      │  │ Server    │  │                 │
│  │  └───────────┘  │      │  └───────────┘  │                 │
│  │  ┌───────────┐  │      │  ┌───────────┐  │                 │
│  │  │ Cache     │──┼──────┼─▶│ Cache     │  │                 │
│  │  │ Layer     │  │      │  │ Layer     │  │                 │
│  │  └───────────┘  │      │  └───────────┘  │                 │
│  │  ┌───────────┐  │      │  ┌───────────┐  │                 │
│  │  │ Config    │  │      │  │ Config    │  │                 │
│  │  │ (EnvVar)  │  │      │  │ (EnvVar)  │  │                 │
│  │  └───────────┘  │      │  └───────────┘  │                 │
│  └─────────────────┘      └─────────────────┘                 │
│         │                         │                            │
│         └─────────┬───────────────┘                            │
│                   ↓                                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Redis Service (Headless)                               │  │
│  │  redis-0.redis-service.default.svc.cluster.local        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                   ↓                                            │
│  ┌─────────────────────────────────────────┐                   │
│  │  Redis Pod (redis-0)                   │                   │
│  │  ┌────────────────────────────────┐    │                   │
│  │  │  Redis Server                   │    │                   │
│  │  │  - 端口: 6379                   │    │                   │
│  │  │  - 配置: redis.conf (ConfigMap) │    │                   │
│  │  └────────────────────────────────┘    │                   │
│  │                 ↓                      │                   │
│  │  ┌────────────────────────────────┐    │                   │
│  │  │  PVC (redis-data-redis-0)      │    │                   │
│  │  │  持久化存储                     │    │                   │
│  │  └────────────────────────────────┘    │                   │
│  └─────────────────────────────────────────┘                   │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  DaemonSet - Log Collector                              │  │
│  │  (每个 Node 上运行一个)                                  │  │
│  │                                                          │  │
│  │  ┌────────────────┐      ┌────────────────┐             │  │
│  │  │ Node 1         │      │ Node 2         │             │  │
│  │  │ ┌────────────┐ │      │ ┌────────────┐ │             │  │
│  │  │ │Log         │ │      │ │Log         │ │             │  │
│  │  │ │Collector   │ │      │ │Collector   │ │             │  │
│  │  │ │Pod         │ │      │ │Pod         │ │             │  │
│  │  │ └────────────┘ │      │ └────────────┘ │             │  │
│  │  └────────────────┘      └────────────────┘             │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  CronJob - Cleanup Job                                  │  │
│  │  定时任务：每小时执行一次                                │  │
│  │                                                          │  │
│  │  每小时触发 ──▶ 创建 Job ──▶ 创建 Pod ──▶ 执行清理      │  │
│  │                                      │                   │  │
│  │                                      ↓                   │  │
│  │                              连接 Redis 清理过期数据      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

---

## 🔧 核心组件详解

### 1. API 服务（Deployment）

#### 功能职责
- HTTP API 请求处理
- Redis 缓存读写
- 配置管理
- 健康检查
- Prometheus 指标暴露

#### 技术栈
```go
- Gin Web 框架
- go-redis/redis 客户端
- Prometheus client
- Viper 配置管理（可选）
```

#### K8s 资源
```yaml
资源类型: Deployment
副本数: 2
资源限制:
  CPU: 100m - 200m
  内存: 128Mi - 256Mi
健康检查:
  Liveness: /health
  Readiness: /ready
环境变量:
  - REDIS_HOST
  - REDIS_PORT
  - APP_ENV
```

#### 新增接口

```go
// 缓存测试
GET  /api/v1/cache/test
返回: {
  "redis_connected": true,
  "cache_hit_rate": 0.85,
  "total_requests": 1000
}

// 配置查看
GET  /api/v1/config
返回: {
  "app_env": "production",
  "redis_host": "redis-service",
  "version": "v0.2.0"
}

// 数据写入（会写入 Redis）
POST /api/v1/data
Body: {
  "key": "user:123",
  "value": "John Doe",
  "ttl": 3600
}

// 数据读取（先查 Redis，未命中查数据库）
GET  /api/v1/data/:key
返回: {
  "key": "user:123",
  "value": "John Doe",
  "cached": true,
  "timestamp": "2025-10-28T10:00:00Z"
}
```

---

### 2. Redis（StatefulSet）

#### 为什么使用 StatefulSet？

```
StatefulSet vs Deployment:

StatefulSet:
✅ 稳定的网络标识（redis-0, redis-1...）
✅ 稳定的持久化存储（每个 Pod 独立 PVC）
✅ 有序部署和扩缩容
✅ 有序滚动更新

Deployment:
❌ 随机 Pod 名称
❌ Pod 重建后存储丢失（除非手动配置）
❌ 无序部署
```

#### 持久化存储

```yaml
# PVC 配置
volumeClaimTemplates:
  - metadata:
      name: redis-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi

# 存储目录
容器内: /data
宿主机: minikube 节点上自动创建的 PV
```

#### Headless Service

```yaml
# 为什么需要 Headless Service？
clusterIP: None  # 关键：不分配 ClusterIP

# 特点：
1. 直接返回 Pod IP，而不是 VIP
2. 提供稳定的 DNS 名称
3. 格式: <pod-name>.<service-name>.<namespace>.svc.cluster.local

# 示例：
redis-0.redis-service.default.svc.cluster.local
```

#### Redis 配置

```conf
# ConfigMap 挂载的 redis.conf
bind 0.0.0.0
port 6379
maxmemory 128mb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
dir /data
```

---

### 3. 日志采集器（DaemonSet）

#### 为什么使用 DaemonSet？

```
应用场景:
✅ 日志采集（每个节点收集本节点日志）
✅ 监控代理（每个节点监控资源）
✅ 网络插件（每个节点配置网络）
✅ 存储插件（每个节点挂载存储）

特点:
- 自动调度到所有节点
- 新节点加入自动部署
- 节点移除自动清理
```

#### 功能实现

```go
package main

import (
    "fmt"
    "log"
    "os"
    "time"
)

func main() {
    // 获取节点信息
    nodeName := os.Getenv("NODE_NAME")
    
    log.Printf("日志采集器启动在节点: %s", nodeName)
    
    // 模拟日志采集
    ticker := time.NewTicker(10 * time.Second)
    defer ticker.Stop()
    
    for range ticker.C {
        // 采集节点日志
        logs := collectLogs(nodeName)
        
        // 输出日志（实际场景会发送到日志中心）
        fmt.Printf("[%s] 采集到 %d 条日志\n", nodeName, len(logs))
    }
}

func collectLogs(nodeName string) []string {
    // 简化实现：读取特定路径的日志
    // 实际场景会读取 /var/log/ 等路径
    return []string{"log1", "log2", "log3"}
}
```

#### K8s 配置特点

```yaml
# 节点选择器（可选）
nodeSelector:
  kubernetes.io/os: linux

# 容忍污点（让它能部署到所有节点）
tolerations:
- effect: NoSchedule
  operator: Exists

# 挂载宿主机路径（读取日志）
volumeMounts:
- name: varlog
  mountPath: /var/log
  readOnly: true
volumes:
- name: varlog
  hostPath:
    path: /var/log
```

---

### 4. 清理任务（CronJob）

#### 定时任务配置

```yaml
schedule: "0 * * * *"  # 每小时执行一次
# ┌───────────── 分钟 (0 - 59)
# │ ┌───────────── 小时 (0 - 23)
# │ │ ┌───────────── 日 (1 - 31)
# │ │ │ ┌───────────── 月 (1 - 12)
# │ │ │ │ ┌───────────── 星期 (0 - 6) (0 = 周日)
# │ │ │ │ │
# * * * * *

# 常用示例：
# "0 * * * *"     - 每小时
# "*/15 * * * *"  - 每 15 分钟
# "0 2 * * *"     - 每天凌晨 2 点
# "0 0 * * 0"     - 每周日凌晨
```

#### Job 配置

```yaml
# 历史保留
successfulJobsHistoryLimit: 3  # 保留 3 个成功的 Job
failedJobsHistoryLimit: 1      # 保留 1 个失败的 Job

# 重试策略
backoffLimit: 3                # 失败重试 3 次
restartPolicy: OnFailure       # 失败时重启

# 超时设置
activeDeadlineSeconds: 300     # 5 分钟超时
```

#### 清理逻辑

```go
package main

import (
    "context"
    "log"
    "time"
    
    "github.com/go-redis/redis/v8"
)

func main() {
    // 连接 Redis
    rdb := redis.NewClient(&redis.Options{
        Addr: "redis-service:6379",
    })
    
    ctx := context.Background()
    
    // 清理过期数据（示例）
    log.Println("开始清理过期数据...")
    
    // 1. 清理过期的缓存键
    keys, _ := rdb.Keys(ctx, "cache:*").Result()
    cleaned := 0
    
    for _, key := range keys {
        ttl := rdb.TTL(ctx, key).Val()
        if ttl < 0 {  // 已过期
            rdb.Del(ctx, key)
            cleaned++
        }
    }
    
    log.Printf("清理完成，删除了 %d 个过期键", cleaned)
}
```

---

## 🔄 数据流详解

### 1. API 请求流程

```
用户 ──▶ NodePort (30080) ──▶ Service ──▶ 负载均衡
                                           │
                     ┌─────────────────────┴─────────────────┐
                     ↓                                       ↓
                 API Pod 1                              API Pod 2
                     │                                       │
                     ├─ 查询缓存 ──▶ Redis ◀── 查询缓存 ─────┤
                     │                                       │
                     └─ 返回结果                  返回结果 ───┘
```

### 2. 缓存读取流程

```go
// 伪代码
func GetData(key string) (string, error) {
    // 1. 先查 Redis
    value, err := redisClient.Get(ctx, key).Result()
    if err == nil {
        return value, nil  // 缓存命中
    }
    
    // 2. 缓存未命中，查数据库（模拟）
    value = queryFromDatabase(key)
    
    // 3. 写入缓存
    redisClient.Set(ctx, key, value, 1*time.Hour)
    
    return value, nil
}
```

### 3. 定时清理流程

```
CronJob 控制器 ──▶ 每小时检查时间
                      │
                      ↓
                 创建 Job
                      │
                      ↓
                 创建 Pod
                      │
                      ↓
              执行清理脚本 ──▶ 连接 Redis ──▶ 删除过期数据
                      │
                      ↓
               Pod 完成 (Completed)
                      │
                      ↓
              Job 标记成功
```

---

## 🌐 网络通信详解

### Service 之间的通信

```
API Pod 访问 Redis:

方式 1: 通过 Service DNS
redisClient.Connect("redis-service:6379")
↓
K8s DNS 解析: redis-service.default.svc.cluster.local
↓
返回 Headless Service（Redis Pod IP）
↓
直连 Redis Pod

方式 2: 通过环境变量
REDIS_SERVICE_HOST=10.96.xxx.xxx
REDIS_SERVICE_PORT=6379
```

### ConfigMap 注入方式

```yaml
# 方式 1: 环境变量
env:
- name: REDIS_HOST
  valueFrom:
    configMapKeyRef:
      name: api-config
      key: redis.host

# 方式 2: 文件挂载
volumes:
- name: config
  configMap:
    name: redis-config
volumeMounts:
- name: config
  mountPath: /etc/redis/redis.conf
  subPath: redis.conf
```

---

## 💾 存储架构

### PV/PVC/StorageClass 关系

```
StorageClass (标准存储类)
    ↓ (动态创建)
PV (持久卷 - 1Gi)
    ↓ (绑定)
PVC (持久卷声明 - redis-data-redis-0)
    ↓ (挂载)
Pod (redis-0)
    ↓
容器 /data 目录
```

### 数据持久化验证

```bash
# 1. 写入数据
kubectl exec -it redis-0 -- redis-cli SET test "hello"

# 2. 删除 Pod
kubectl delete pod redis-0

# 3. 等待 Pod 重建
kubectl get pods -w

# 4. 验证数据还在
kubectl exec -it redis-0 -- redis-cli GET test
# 输出: "hello" ✅
```

---

## 📊 监控指标

### API 服务指标

```prometheus
# 缓存命中率
cache_hit_rate = cache_hits / (cache_hits + cache_misses)

# Redis 连接状态
redis_connected{pod="api-pod-1"} 1

# 缓存操作延迟
cache_operation_duration_seconds{operation="get"} 0.002
cache_operation_duration_seconds{operation="set"} 0.001
```

### Redis 指标

```prometheus
# 内存使用
redis_memory_used_bytes{pod="redis-0"} 12345678

# 连接数
redis_connected_clients{pod="redis-0"} 2

# 命令执行次数
redis_commands_total{cmd="get"} 1000
redis_commands_total{cmd="set"} 500
```

### 清理任务指标

```prometheus
# 任务执行次数
cleanup_job_runs_total 24

# 清理的键数量
cleanup_keys_deleted_total 150
```

---

## 🔐 安全考虑

### Redis 密码（可选）

```yaml
# Secret 存储密码
apiVersion: v1
kind: Secret
metadata:
  name: redis-secret
type: Opaque
data:
  password: cGFzc3dvcmQxMjM=  # base64("password123")

# 注入到 Pod
env:
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: redis-secret
      key: password
```

### 资源隔离

```yaml
# 使用 namespace 隔离
kubectl create namespace app-v02

# 网络策略（可选，v0.4 详细讲）
# 限制只有 API Pod 能访问 Redis
```

---

## 🎯 架构优势

### v0.1 vs v0.2 对比

| 特性 | v0.1 | v0.2 |
|------|------|------|
| 工作负载类型 | 1 种 (Deployment) | 4 种 (Deployment, StatefulSet, DaemonSet, CronJob) |
| 持久化存储 | ❌ | ✅ (PVC) |
| 配置管理 | 环境变量 | ConfigMap/Secret |
| 外部依赖 | ❌ | ✅ (Redis) |
| 定时任务 | ❌ | ✅ (CronJob) |
| 节点级服务 | ❌ | ✅ (DaemonSet) |

---

## 📈 扩展性考虑

### 未来扩展方向

```
v0.2 → v0.3:
- Redis 改为主从架构（多副本）
- HPA 自动扩缩容
- 添加数据库（PostgreSQL StatefulSet）

v0.2 → v0.4:
- 添加 Ingress（统一入口）
- 服务网格（Istio）
- 多服务架构
```

---

## 🎓 学习要点总结

通过 v0.2 架构，你将深入理解：

✅ **K8s 多种工作负载的适用场景**  
✅ **有状态应用的部署和管理**  
✅ **持久化存储的使用**  
✅ **配置和密钥的管理**  
✅ **定时任务的实现**  
✅ **节点级服务的部署**  
✅ **服务间通信和发现**  

---

**架构设计完成！准备开始实施！** 🚀


