# 从零开始的云原生之旅（六）：DaemonSet 实战日志采集器

> 每个节点都自动部署一个，新节点加入也自动部署！

## 📖 文章目录

- [前言](#前言)
- [一、为什么需要 DaemonSet？](#一为什么需要-daemonset)
  - [1.1 我用 Deployment 踩的坑](#11-我用-deployment-踩的坑)
  - [1.2 DaemonSet 的解决方案](#12-daemonset-的解决方案)
- [二、日志采集器设计](#二日志采集器设计)
  - [2.1 功能需求](#21-功能需求)
  - [2.2 架构设计](#22-架构设计)
  - [2.3 技术选型](#23-技术选型)
- [三、编写日志采集器](#三编写日志采集器)
  - [3.1 核心功能实现](#31-核心功能实现)
  - [3.2 Prometheus 指标](#32-prometheus-指标)
  - [3.3 健康检查接口](#33-健康检查接口)
- [四、配置 DaemonSet](#四配置-daemonset)
  - [4.1 基础配置](#41-基础配置)
  - [4.2 环境变量注入](#42-环境变量注入)
  - [4.3 访问宿主机资源](#43-访问宿主机资源)
  - [4.4 节点选择和容忍](#44-节点选择和容忍)
- [五、构建和部署](#五构建和部署)
  - [5.1 编写 Dockerfile](#51-编写-dockerfile)
  - [5.2 构建镜像](#52-构建镜像)
  - [5.3 部署 DaemonSet](#53-部署-daemonset)
- [六、验证和测试](#六验证和测试)
  - [6.1 验证部署状态](#61-验证部署状态)
  - [6.2 查看日志输出](#62-查看日志输出)
  - [6.3 测试健康检查](#63-测试健康检查)
  - [6.4 查看 Prometheus 指标](#64-查看-prometheus-指标)
- [七、节点扩缩容测试](#七节点扩缩容测试)
  - [7.1 模拟节点加入](#71-模拟节点加入)
  - [7.2 模拟节点下线](#72-模拟节点下线)
- [八、高级特性](#八高级特性)
  - [8.1 更新策略](#81-更新策略)
  - [8.2 Tolerations 详解](#82-tolerations-详解)
  - [8.3 NodeSelector 详解](#83-nodeselector-详解)
- [九、常见问题排查](#九常见问题排查)
  - [9.1 Pod 未在所有节点运行](#91-pod-未在所有节点运行)
  - [9.2 Pod 无法访问宿主机目录](#92-pod-无法访问宿主机目录)
  - [9.3 更新时服务中断](#93-更新时服务中断)
- [十、生产环境优化建议](#十生产环境优化建议)
- [结语](#结语)

---

## 前言

在前面的文章中，我学会了：
- **Deployment**：部署无状态的 API 服务
- **StatefulSet**：部署有状态的 Redis

这次，我遇到了一个新需求：

> **运维："我们要在每个 K8s 节点上部署日志采集器，收集节点日志"**

**我的第一反应：用 Deployment？**

但很快发现问题：
- ❌ Deployment 不保证每个节点都有 Pod
- ❌ 新节点加入，需要手动调整 replicas
- ❌ 节点下线，Pod 可能调度到其他节点（不符合需求）

**这就需要 DaemonSet！**

这篇文章，我会**从零实现一个日志采集器**，并用 DaemonSet 部署，包括：
- ✅ 如何访问宿主机目录？
- ✅ 如何保证每个节点都有一个 Pod？
- ✅ 新节点加入，如何自动部署？
- ✅ 如何更新 DaemonSet？
- ✅ **我踩过的所有坑！**

---

## 一、为什么需要 DaemonSet？

### 1.1 我用 Deployment 踩的坑

**需求：每个节点部署一个日志采集器**

我的第一次尝试：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: log-collector
spec:
  replicas: 1  # 假设只有 1 个节点
```

**部署后：**

```bash
kubectl get pods -o wide
# NAME                  NODE     READY   STATUS    RESTARTS   AGE
# log-collector-xxx     node-1   1/1     Running   0          1m
```

**看起来没问题！但...：**

---

**问题 1：新节点加入，没有自动部署**

```bash
# 集群扩容，新增 node-2
kubectl get nodes
# NAME     STATUS   AGE
# node-1   Ready    10d
# node-2   Ready    1m   ← 新节点

# 查看 Pod
kubectl get pods -o wide
# NAME                  NODE     READY   STATUS    RESTARTS   AGE
# log-collector-xxx     node-1   1/1     Running   0          5m

# node-2 上没有 Pod！
```

**我需要手动调整 replicas：**
```bash
kubectl scale deployment log-collector --replicas=2
```

**太麻烦了！每次加节点都要手动调整！**

---

**问题 2：Deployment 不保证每个节点都有**

```bash
# 扩容到 3 个副本
kubectl scale deployment log-collector --replicas=3

# 查看 Pod 分布
kubectl get pods -o wide
# NAME                  NODE     READY   STATUS    RESTARTS   AGE
# log-collector-xxx     node-1   1/1     Running   0          1m
# log-collector-yyy     node-1   1/1     Running   0          30s  ← 都在 node-1
# log-collector-zzz     node-2   1/1     Running   0          20s
```

**node-1 有 2 个 Pod，node-2 有 1 个！**

**这不符合需求：我要每个节点只有一个！**

---

**问题 3：节点下线，Pod 被迁移**

```bash
# node-2 下线（维护）
kubectl drain node-2

# Pod 被调度到 node-1
kubectl get pods -o wide
# NAME                  NODE     READY   STATUS    RESTARTS   AGE
# log-collector-xxx     node-1   1/1     Running   0          5m
# log-collector-zzz     node-1   1/1     Running   0          30s  ← 从 node-2 迁移来的
```

**但日志采集器应该跟随节点！节点不在了，采集器也应该停止！**

---

### 1.2 DaemonSet 的解决方案

**DaemonSet 的特点：**

**① 自动在每个节点运行一个 Pod**
```
┌──────────┐  ┌──────────┐  ┌──────────┐
│  node-1  │  │  node-2  │  │  node-3  │
│          │  │          │  │          │
│ ┌──────┐ │  │ ┌──────┐ │  │ ┌──────┐ │
│ │ Pod  │ │  │ │ Pod  │ │  │ │ Pod  │ │
│ └──────┘ │  │ └──────┘ │  │ └──────┘ │
└──────────┘  └──────────┘  └──────────┘

每个节点自动有一个 Pod！
```

**② 节点加入，自动部署**
```
新增 node-4：
┌──────────┐
│  node-4  │
│          │
│ ┌──────┐ │  ← 自动创建 Pod
│ │ Pod  │ │
│ └──────┘ │
└──────────┘
```

**③ 节点下线，自动清理**
```
node-2 下线：
┌──────────┐
│  node-2  │  ← 节点不在了
│          │
│   (无)   │  ← Pod 也被删除
│          │
└──────────┘
```

**完美符合需求！**

---

## 二、日志采集器设计

### 2.1 功能需求

**核心功能：**
- ✅ 读取宿主机的日志目录（`/var/log/`）
- ✅ 解析日志内容（这里模拟）
- ✅ 上报日志到日志中心（这里模拟）
- ✅ 提供健康检查接口
- ✅ 暴露 Prometheus 指标

**v0.2 的简化实现：**
- 不读取真实日志文件（避免权限问题）
- 模拟日志采集过程
- 重点演示 DaemonSet 的部署和管理

---

### 2.2 架构设计

```
┌─────────────────────────────────────────────┐
│              K8s 节点（node-1）              │
│                                             │
│  ┌────────────────────────────────────┐    │
│  │    Pod: log-collector-xxx          │    │
│  │                                     │    │
│  │  ┌──────────────────────────────┐  │    │
│  │  │  Container: log-collector    │  │    │
│  │  │  - 每 10 秒采集一次          │  │    │
│  │  │  - 输出日志统计             │  │    │
│  │  │  - 暴露 HTTP 接口（8080）   │  │    │
│  │  └──────────────────────────────┘  │    │
│  │          ↓ volumeMount             │    │
│  │  ┌──────────────────────────────┐  │    │
│  │  │  hostPath: /var/log          │  │    │
│  │  │  (只读挂载宿主机日志目录)    │  │    │
│  │  └──────────────────────────────┘  │    │
│  └────────────────────────────────────┘    │
│                                             │
│  宿主机文件系统:                             │
│  /var/log/                                  │
│    ├─ syslog                                │
│    ├─ kern.log                              │
│    └─ ...                                   │
│                                             │
└─────────────────────────────────────────────┘
```

---

### 2.3 技术选型

| 组件 | 选择 | 原因 |
|-----|-----|-----|
| **编程语言** | Go | 性能好，部署简单 |
| **HTTP 框架** | 标准库 `net/http` | 轻量，无需依赖 |
| **指标采集** | Prometheus Client | K8s 生态标准 |
| **日志输出** | 标准输出 | K8s 自动收集 |

---

## 三、编写日志采集器

### 3.1 核心功能实现

**代码结构：**

```
src/log-collector/
└── main.go
```

**核心逻辑：**

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

func main() {
    // 获取节点名称（从环境变量，DaemonSet 注入）
    nodeName := os.Getenv("NODE_NAME")
    if nodeName == "" {
        nodeName = "unknown-node"
    }

    log.Printf("📊 日志采集器启动")
    log.Printf("📍 节点名称: %s", nodeName)
    log.Printf("🔧 版本: v0.2.0")

    // 启动 HTTP 服务（健康检查 + 指标）
    go startHTTPServer()

    // 启动日志采集
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
```

**关键点：**
- 从环境变量获取节点名称（`NODE_NAME`）
- 每 10 秒执行一次采集
- 输出日志到标准输出（K8s 会自动收集）
- 记录指标到 Prometheus

---

### 3.2 Prometheus 指标

```go
var (
    // 采集的日志总数（按节点分组）
    logsCollected = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "logs_collected_total",
            Help: "Total number of logs collected by this collector",
        },
        []string{"node"},  // 按节点标签分组
    )

    // 采集器运行时间
    collectorUptime = prometheus.NewCounter(
        prometheus.CounterOpts{
            Name: "log_collector_uptime_seconds",
            Help: "Time since the log collector started",
        },
    )
)

func init() {
    // 注册指标
    prometheus.MustRegister(logsCollected)
    prometheus.MustRegister(collectorUptime)
}
```

**暴露的指标：**
```
# TYPE logs_collected_total counter
logs_collected_total{node="node-1"} 1250

# TYPE log_collector_uptime_seconds counter
log_collector_uptime_seconds 3600
```

**用途：**
- 监控每个节点的日志采集量
- 监控采集器的运行时间
- 发现日志量异常的节点

---

### 3.3 健康检查接口

```go
func startHTTPServer() {
    mux := http.NewServeMux()

    // 健康检查
    mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        w.Write([]byte("OK"))
    })

    // Prometheus 指标
    mux.Handle("/metrics", promhttp.Handler())

    // 服务信息
    mux.HandleFunc("/info", func(w http.ResponseWriter, r *http.Request) {
        nodeName := os.Getenv("NODE_NAME")
        info := fmt.Sprintf(`{
  "service": "log-collector",
  "version": "v0.2.0",
  "node": "%s",
  "status": "running"
}`, nodeName)
        w.Header().Set("Content-Type", "application/json")
        w.Write([]byte(info))
    })

    log.Printf("🌐 HTTP 服务启动在端口 8080")
    http.ListenAndServe(":8080", mux)
}
```

**提供的接口：**
- `GET /health` - 健康检查（K8s Probe 使用）
- `GET /metrics` - Prometheus 指标
- `GET /info` - 服务信息

---

## 四、配置 DaemonSet

### 4.1 基础配置

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-collector
  labels:
    app: log-collector
    version: v0.2
spec:
  selector:
    matchLabels:
      app: log-collector
  
  template:
    metadata:
      labels:
        app: log-collector
      annotations:
        # Prometheus 自动发现
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: collector
        image: log-collector:v0.2
        ports:
        - containerPort: 8080
          name: http
```

**关键点：**
- `kind: DaemonSet`（不是 Deployment）
- 不需要指定 `replicas`（自动管理）
- Annotations 用于 Prometheus 自动发现

---

### 4.2 环境变量注入

**DaemonSet 可以把 Pod 和节点的信息注入到容器：**

```yaml
spec:
  containers:
  - name: collector
    env:
    # 注入节点名称
    - name: NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
    
    # 注入 Pod 名称
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    
    # 注入命名空间
    - name: POD_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
```

**可用的字段：**
- `spec.nodeName` - 节点名称
- `spec.serviceAccountName` - ServiceAccount
- `status.hostIP` - 节点 IP
- `status.podIP` - Pod IP
- `metadata.name` - Pod 名称
- `metadata.namespace` - 命名空间
- `metadata.labels['<KEY>']` - 标签值
- `metadata.annotations['<KEY>']` - 注解值

---

### 4.3 访问宿主机资源

**DaemonSet 常用 `hostPath` 访问宿主机目录：**

```yaml
spec:
  containers:
  - name: collector
    volumeMounts:
    # 挂载宿主机 /var/log
    - name: varlog
      mountPath: /var/log
      readOnly: true  # 只读，安全
    
    # 挂载 Docker 容器日志
    - name: varlibdockercontainers
      mountPath: /var/lib/docker/containers
      readOnly: true
  
  volumes:
  # 定义 hostPath 卷
  - name: varlog
    hostPath:
      path: /var/log
      type: Directory  # 必须是目录
  
  - name: varlibdockercontainers
    hostPath:
      path: /var/lib/docker/containers
      type: DirectoryOrCreate  # 不存在就创建
```

**hostPath 的类型：**

| 类型 | 说明 | 用途 |
|-----|-----|-----|
| `Directory` | 必须是已存在的目录 | 日志目录 |
| `DirectoryOrCreate` | 不存在就创建 | 临时目录 |
| `File` | 必须是已存在的文件 | 配置文件 |
| `FileOrCreate` | 不存在就创建文件 | 锁文件 |
| `Socket` | UNIX socket | Docker socket |

---

**⚠️ 安全注意事项：**

```yaml
volumeMounts:
- name: varlog
  mountPath: /var/log
  readOnly: true  # 只读，避免误操作
```

**为什么要只读？**
- ❌ 可写：容器可能删除或修改宿主机日志
- ✅ 只读：容器只能读取，安全

**特殊情况（需要写入）：**
- 日志轮转工具（logrotate）
- 需要创建锁文件
- 需要设置 `readOnly: false`

---

### 4.4 节点选择和容忍

**① nodeSelector（选择节点）**

```yaml
spec:
  template:
    spec:
      nodeSelector:
        kubernetes.io/os: linux  # 只在 Linux 节点运行
```

**常用 nodeSelector：**
```yaml
nodeSelector:
  kubernetes.io/os: linux          # 操作系统
  kubernetes.io/arch: amd64        # CPU 架构
  node-role.kubernetes.io/worker: ""  # 角色：工作节点
  region: us-west                  # 自定义标签：区域
  disktype: ssd                    # 自定义标签：磁盘类型
```

---

**② tolerations（容忍污点）**

**K8s 的污点（Taint）机制：**
```
节点有"污点" → Pod 默认不能调度 → 除非 Pod 有"容忍"
```

**示例：Master 节点默认有污点**
```bash
kubectl describe node master | Select-String "Taints"
# Taints: node-role.kubernetes.io/control-plane:NoSchedule
```

**DaemonSet 如果要在 Master 上也运行：**

```yaml
spec:
  template:
    spec:
      tolerations:
      # 容忍所有 NoSchedule 污点
      - effect: NoSchedule
        operator: Exists
      
      # 容忍所有 NoExecute 污点
      - effect: NoExecute
        operator: Exists
```

**Toleration 语法：**

| 字段 | 说明 | 值 |
|-----|-----|---|
| `key` | 污点的键 | 如 `node-role.kubernetes.io/master` |
| `operator` | 操作符 | `Exists`（存在即可）或 `Equal`（值相等） |
| `value` | 污点的值 | 与 `operator: Equal` 配合使用 |
| `effect` | 污点的效果 | `NoSchedule`、`NoExecute`、`PreferNoSchedule` |

**示例：**

```yaml
# 容忍特定污点
tolerations:
- key: node-role.kubernetes.io/master
  operator: Exists
  effect: NoSchedule

# 容忍所有污点
tolerations:
- operator: Exists

# 容忍特定值的污点
tolerations:
- key: dedicated
  operator: Equal
  value: logging
  effect: NoSchedule
```

---

## 五、构建和部署

### 5.1 编写 Dockerfile

```dockerfile
# 构建阶段
FROM golang:1.23-alpine AS builder

WORKDIR /build

# 复制依赖文件
COPY go.mod go.sum ./
RUN go mod download

# 复制源码
COPY src/log-collector/ ./

# 构建
RUN CGO_ENABLED=0 GOOS=linux go build -o log-collector main.go

# 运行阶段
FROM alpine:latest

WORKDIR /app

# 复制二进制文件
COPY --from=builder /build/log-collector .

# 暴露端口
EXPOSE 8080

# 运行
CMD ["./log-collector"]
```

---

### 5.2 构建镜像

```bash
# 切换到 Minikube 的 Docker 环境
minikube docker-env | Invoke-Expression

# 构建镜像
docker build -f Dockerfile.log-collector -t log-collector:v0.2 .

# 验证镜像
docker images | Select-String "log-collector"
# REPOSITORY       TAG    IMAGE ID      CREATED        SIZE
# log-collector    v0.2   abc123def     5 seconds ago  20MB
```

---

### 5.3 部署 DaemonSet

```bash
# 部署
kubectl apply -f k8s/v0.2/log-collector/daemonset.yaml
# daemonset.apps/log-collector created

# 查看 DaemonSet
kubectl get daemonsets
# NAME            DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
# log-collector   1         1         1       1            1           <none>          10s

# 查看 Pod
kubectl get pods -l app=log-collector -o wide
# NAME                  READY   STATUS    RESTARTS   AGE   NODE       
# log-collector-abcde   1/1     Running   0          20s   minikube
```

**字段说明：**
- `DESIRED`：期望的 Pod 数（等于节点数）
- `CURRENT`：当前的 Pod 数
- `READY`：就绪的 Pod 数
- `NODE SELECTOR`：节点选择器

---

## 六、验证和测试

### 6.1 验证部署状态

```bash
# 查看 DaemonSet 详情
kubectl describe daemonset log-collector

# 输出：
# Name:           log-collector
# Selector:       app=log-collector
# Node-Selector:  kubernetes.io/os=linux
# Labels:         app=log-collector
# Desired Number of Nodes Scheduled: 1
# Current Number of Nodes Scheduled: 1
# Number of Nodes Scheduled with Up-to-date Pods: 1
# Number of Nodes Scheduled with Available Pods: 1
```

---

### 6.2 查看日志输出

```bash
# 查看 Pod 日志
kubectl logs -l app=log-collector --tail=20

# 输出：
# 📊 日志采集器启动
# 📍 节点名称: minikube
# 🔧 版本: v0.2.0
# 🌐 HTTP 服务启动在端口 8080
#    健康检查: http://localhost:8080/health
#    指标接口: http://localhost:8080/metrics
#    信息接口: http://localhost:8080/info
# ✅ 开始采集日志...
# [2025-10-30 10:30:15] [minikube] 采集日志: 23 条
# [2025-10-30 10:30:25] [minikube] 采集日志: 35 条
# [2025-10-30 10:30:35] [minikube] 采集日志: 18 条

# 持续查看日志
kubectl logs -l app=log-collector -f
```

---

### 6.3 测试健康检查

```bash
# 方法1：直接访问 Pod
kubectl exec -it $(kubectl get pod -l app=log-collector -o name | head -1) -- sh

# 在 Pod 内测试
wget -qO- http://localhost:8080/health
# OK

wget -qO- http://localhost:8080/info
# {
#   "service": "log-collector",
#   "version": "v0.2.0",
#   "node": "minikube",
#   "status": "running"
# }

exit
```

```bash
# 方法2：端口转发
kubectl port-forward daemonset/log-collector 8080:8080

# 在本地浏览器访问：
# http://localhost:8080/health
# http://localhost:8080/info
# http://localhost:8080/metrics
```

---

### 6.4 查看 Prometheus 指标

```bash
# 获取指标
kubectl exec -it $(kubectl get pod -l app=log-collector -o name | head -1) -- \
  wget -qO- http://localhost:8080/metrics

# 输出：
# # HELP logs_collected_total Total number of logs collected
# # TYPE logs_collected_total counter
# logs_collected_total{node="minikube"} 1250

# # HELP log_collector_uptime_seconds Time since the log collector started
# # TYPE log_collector_uptime_seconds counter
# log_collector_uptime_seconds 300
```

**指标含义：**
- `logs_collected_total`：累计采集的日志数
- `log_collector_uptime_seconds`：运行时长（秒）

---

## 七、节点扩缩容测试

### 7.1 模拟节点加入

**在生产环境，新节点加入集群：**

```bash
# 查看当前节点
kubectl get nodes
# NAME       STATUS   AGE
# node-1     Ready    10d

# 新增 node-2（这里用 Minikube 模拟）
# minikube node add

# DaemonSet 自动在 node-2 创建 Pod
kubectl get pods -l app=log-collector -o wide
# NAME                  READY   STATUS    RESTARTS   AGE   NODE
# log-collector-aaa     1/1     Running   0          10m   node-1
# log-collector-bbb     1/1     Running   0          10s   node-2  ← 自动创建
```

**太智能了！不需要任何手动操作！**

---

### 7.2 模拟节点下线

```bash
# 标记节点为不可调度
kubectl cordon node-2

# 驱逐节点上的 Pod
kubectl drain node-2 --ignore-daemonsets=false

# DaemonSet 的 Pod 会被删除（不会迁移到其他节点）
kubectl get pods -l app=log-collector -o wide
# NAME                  READY   STATUS    RESTARTS   AGE   NODE
# log-collector-aaa     1/1     Running   0          15m   node-1

# 节点上线后，Pod 自动重建
kubectl uncordon node-2
kubectl get pods -l app=log-collector -o wide
# NAME                  READY   STATUS    RESTARTS   AGE   NODE
# log-collector-aaa     1/1     Running   0          20m   node-1
# log-collector-ccc     1/1     Running   0          10s   node-2  ← 重新创建
```

---

## 八、高级特性

### 8.1 更新策略

**DaemonSet 支持滚动更新：**

```yaml
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1  # 最多 1 个节点的 Pod 不可用
```

**更新过程：**

```bash
# 更新镜像
kubectl set image daemonset/log-collector collector=log-collector:v0.3

# 查看更新状态
kubectl rollout status daemonset/log-collector

# 输出：
# Waiting for daemon set "log-collector" rollout to finish: 0 out of 3 new pods have been updated...
# Waiting for daemon set "log-collector" rollout to finish: 1 out of 3 new pods have been updated...
# Waiting for daemon set "log-collector" rollout to finish: 2 out of 3 new pods have been updated...
# daemon set "log-collector" successfully rolled out
```

**更新流程（3 个节点）：**

```
原有状态：
  node-1: Pod v0.2
  node-2: Pod v0.2
  node-3: Pod v0.2

第1步：删除 node-1 的 Pod
  node-1: (无)  ← maxUnavailable=1，允许 1 个节点不可用
  node-2: Pod v0.2
  node-3: Pod v0.2

第2步：创建 node-1 的新 Pod
  node-1: Pod v0.3  ← 新版本
  node-2: Pod v0.2
  node-3: Pod v0.2

第3步：删除 node-2 的 Pod
  node-1: Pod v0.3
  node-2: (无)
  node-3: Pod v0.2

...依此类推
```

**回滚：**

```bash
# 查看历史版本
kubectl rollout history daemonset/log-collector

# 回滚到上一个版本
kubectl rollout undo daemonset/log-collector

# 回滚到指定版本
kubectl rollout undo daemonset/log-collector --to-revision=2
```

---

### 8.2 Tolerations 详解

**污点效果（Effect）：**

| Effect | 说明 | Pod 行为 |
|--------|-----|---------|
| `NoSchedule` | 不允许调度 | 新 Pod 不会调度到该节点，已有 Pod 不受影响 |
| `PreferNoSchedule` | 尽量不调度 | 尽量不调度，但资源不足时可以 |
| `NoExecute` | 不允许执行 | 新 Pod 不调度，已有 Pod 被驱逐 |

**示例：**

```bash
# 给节点添加污点
kubectl taint nodes node-1 key=value:NoSchedule

# 查看污点
kubectl describe node node-1 | Select-String "Taints"
# Taints: key=value:NoSchedule
```

**DaemonSet 容忍：**

```yaml
tolerations:
# 容忍上面的污点
- key: key
  operator: Equal
  value: value
  effect: NoSchedule

# 容忍所有污点
- operator: Exists
```

---

### 8.3 NodeSelector 详解

**给节点打标签：**

```bash
# 添加标签
kubectl label node node-1 role=logging

# 查看标签
kubectl get nodes --show-labels
# NAME     STATUS   LABELS
# node-1   Ready    role=logging,...
```

**DaemonSet 使用：**

```yaml
spec:
  template:
    spec:
      nodeSelector:
        role: logging  # 只在有这个标签的节点运行
```

**结果：**
```bash
kubectl get pods -l app=log-collector -o wide
# NAME                  READY   STATUS    RESTARTS   AGE   NODE
# log-collector-xxx     1/1     Running   0          1m    node-1  ← 只在 node-1
```

---

## 九、常见问题排查

### 9.1 Pod 未在所有节点运行

**症状：**
```bash
kubectl get nodes
# NAME     STATUS   AGE
# node-1   Ready    10d
# node-2   Ready    10d

kubectl get pods -l app=log-collector -o wide
# NAME                  READY   STATUS    RESTARTS   AGE   NODE
# log-collector-xxx     1/1     Running   0          1m    node-1
# 只有 node-1，node-2 没有！
```

**排查：**

```bash
# 检查 nodeSelector
kubectl get daemonset log-collector -o yaml | Select-String "nodeSelector"
# nodeSelector:
#   disktype: ssd  ← node-2 没有这个标签

# 检查节点标签
kubectl get nodes --show-labels
# node-1   Ready   disktype=ssd
# node-2   Ready   (无 disktype 标签)

# 解决：给 node-2 添加标签
kubectl label node node-2 disktype=ssd
```

---

**检查污点：**

```bash
# 查看节点污点
kubectl describe node node-2 | Select-String "Taints"
# Taints: dedicated=special:NoSchedule

# DaemonSet 没有容忍这个污点
# 解决：添加 toleration
```

---

### 9.2 Pod 无法访问宿主机目录

**症状：**
```bash
kubectl logs log-collector-xxx
# Error: open /var/log/syslog: permission denied
```

**原因：**
- 容器内用户没有权限读取宿主机文件
- SELinux/AppArmor 阻止访问

**解决方案：**

```yaml
spec:
  template:
    spec:
      # 方案1：以 root 用户运行（不推荐）
      securityContext:
        runAsUser: 0
      
      # 方案2：挂载为只读
      containers:
      - volumeMounts:
        - name: varlog
          mountPath: /var/log
          readOnly: true  # 只读，更安全
```

---

### 9.3 更新时服务中断

**症状：更新时，某些节点的日志采集停止了**

**原因：**
```yaml
updateStrategy:
  rollingUpdate:
    maxUnavailable: 3  # 太大！允许 3 个节点同时不可用
```

**解决：**
```yaml
updateStrategy:
  rollingUpdate:
    maxUnavailable: 1  # 一次只更新 1 个节点
```

---

## 十、生产环境优化建议

**1. 资源限制**
```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "50m"
  limits:
    memory: "128Mi"
    cpu: "100m"
```

**2. 日志轮转**
```yaml
# 避免日志文件过大
volumeMounts:
- name: varlog
  mountPath: /var/log
  readOnly: true  # 只读，不写入宿主机
```

**3. 监控告警**
- 监控 `logs_collected_total`，发现采集量异常
- 监控 Pod 状态，节点故障时及时告警

**4. 权限最小化**
```yaml
securityContext:
  runAsNonRoot: true  # 不以 root 运行
  readOnlyRootFilesystem: true  # 只读根文件系统
  capabilities:
    drop:
    - ALL  # 删除所有 Linux Capabilities
```

**5. 更新策略**
```yaml
updateStrategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 1  # 保证服务可用性
```

---

## 结语

**这篇文章，我学会了：**

✅ **DaemonSet 的核心特性**
  - 每个节点自动运行一个 Pod
  - 节点加入/退出，自动部署/清理
  - 不需要手动管理副本数

✅ **环境变量注入**
  - 通过 `fieldRef` 获取节点/Pod 信息
  - 传递上下文给应用

✅ **访问宿主机资源**
  - 使用 `hostPath` 挂载宿主机目录
  - 注意权限和安全问题

✅ **节点选择和容忍**
  - `nodeSelector`：选择特定节点
  - `tolerations`：容忍污点，部署到特殊节点

✅ **滚动更新**
  - `maxUnavailable` 控制更新速度
  - 支持回滚

---

**最大的收获：**

> **DaemonSet 是节点级服务的最佳选择！**  
> **每个节点一个 Pod，自动跟随节点扩缩容！**  
> **日志采集、监控 Agent、网络插件都用它！**

---

**下一步（v0.2 继续）：**

在下一篇文章中，我会讲解 **ConfigMap 和 Secret：配置管理最佳实践**，包括：
- ✅ ConfigMap 的 4 种使用方式
- ✅ Secret 的加密存储
- ✅ 动态更新配置
- ✅ 配置管理最佳实践

敬请期待！

---

**如果这篇文章对你有帮助，欢迎点赞、收藏、分享！**

**有问题欢迎在评论区讨论！** 👇

