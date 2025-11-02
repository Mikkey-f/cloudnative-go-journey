# 从零开始的云原生之旅（九）：云原生的核心优势：自动弹性伸缩实战

> 终于体验到云原生的真正威力！流量来了自动扩容，流量下降自动缩容！

## 📖 文章目录

- [前言](#前言)
- [一、为什么需要弹性伸缩？](#一为什么需要弹性伸缩)
  - [1.1 传统方式的痛点](#11-传统方式的痛点)
  - [1.2 弹性伸缩的价值](#12-弹性伸缩的价值)
  - [1.3 真实场景](#13-真实场景)
- [二、Kubernetes 弹性伸缩全景](#二kubernetes-弹性伸缩全景)
  - [2.1 三种伸缩方式](#21-三种伸缩方式)
  - [2.2 HPA 工作原理](#22-hpa-工作原理)
  - [2.3 架构图解](#23-架构图解)
- [三、准备工作：理解资源管理](#三准备工作理解资源管理)
  - [3.1 Resources Requests 和 Limits](#31-resources-requests-和-limits)
  - [3.2 为什么 HPA 依赖 Requests？](#32-为什么-hpa-依赖-requests)
  - [3.3 配置建议](#33-配置建议)
- [四、安装 Metrics Server](#四安装-metrics-server)
  - [4.1 什么是 Metrics Server？](#41-什么是-metrics-server)
  - [4.2 安装步骤](#42-安装步骤)
  - [4.3 我踩的坑：Metrics API not available](#43-我踩的坑metrics-api-not-available)
  - [4.4 验证安装](#44-验证安装)
- [五、添加负载测试接口](#五添加负载测试接口)
  - [5.1 为什么需要负载接口？](#51-为什么需要负载接口)
  - [5.2 实现 CPU 密集型接口](#52-实现-cpu-密集型接口)
  - [5.3 实现内存密集型接口](#53-实现内存密集型接口)
  - [5.4 代码解析](#54-代码解析)
- [六、优化资源配置](#六优化资源配置)
  - [6.1 调整 Deployment 资源](#61-调整-deployment-资源)
  - [6.2 优化探针配置](#62-优化探针配置)
  - [6.3 为什么这样配置？](#63-为什么这样配置)
- [七、初次测试](#七初次测试)
  - [7.1 构建和部署](#71-构建和部署)
  - [7.2 手动触发负载](#72-手动触发负载)
  - [7.3 观察资源使用](#73-观察资源使用)
- [结语](#结语)

---

## 前言

在完成了 v0.2 的所有 Kubernetes 工作负载实战后，我意识到：

> **手动管理副本数太低效了！**  
> **流量高峰时手动扩容，凌晨时手动缩容？**  
> **这不就是把自己变成了"人肉运维"吗？**

这就是为什么我要学习 v0.3 - **弹性伸缩版**。这篇文章记录我：
- ✅ 理解为什么弹性伸缩是云原生的核心能力
- ✅ 安装和配置 Metrics Server
- ✅ 优化应用的资源配置
- ✅ 添加负载测试接口
- ✅ **为 HPA 做好准备工作**

**下一篇**将详细讲解 HPA 的配置和实战。

---

## 一、为什么需要弹性伸缩？

### 1.1 传统方式的痛点

在没有弹性伸缩之前，我是这样运维的：

```bash
# 早上 9 点，流量上来了
kubectl scale deployment api-server --replicas=10

# 晚上 11 点，流量下去了
kubectl scale deployment api-server --replicas=2

# 周末活动，临时加机器
kubectl scale deployment api-server --replicas=50

# 活动结束，再手动缩回去
kubectl scale deployment api-server --replicas=2
```

**问题一大堆**：
```
❌ 需要时刻盯着监控
❌ 半夜流量突增怎么办？我在睡觉啊！
❌ 扩容不及时 → 服务卡顿，用户流失
❌ 缩容忘记了 → 资源浪费，成本增加
❌ 每个服务都要手动管理 → 累死人
```

**简单说**：手动伸缩 = 低效 + 不可靠 + 浪费资源

### 1.2 弹性伸缩的价值

启用弹性伸缩后：

```yaml
# 只需要配置一次
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa
spec:
  minReplicas: 2      # 最少 2 个
  maxReplicas: 10     # 最多 10 个
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70  # CPU 超过 70% 就扩容
```

**然后，魔法发生了**：
```
✅ 流量增加 → CPU 超过 70% → 自动扩容 → 性能恢复
✅ 流量下降 → CPU 低于 70% → 自动缩容 → 节省资源
✅ 半夜突发流量 → 自动处理，不需要运维起床
✅ 多个服务 → 各自独立伸缩，互不影响
✅ 按需使用资源 → 成本优化
```

**这就是云原生的核心能力之一！**

### 1.3 真实场景

以我的 API 服务为例：

| 时间段 | 流量 | 传统方式 | 弹性伸缩 |
|--------|------|---------|---------|
| 凌晨 2-6 点 | 低 | 10 个 Pod（浪费） | 2 个 Pod（自动缩容）|
| 工作日 9-18 点 | 中 | 10 个 Pod（勉强够） | 4-6 个 Pod（按需）|
| 晚上 20-22 点 | 高峰 | 10 个 Pod（不够！） | 8-10 个 Pod（自动扩容）|
| 周末活动 | 爆发 | 10 个 Pod（卡死） | 动态扩容到 50+（自动）|

**节省资源**：
- 传统方式：按峰值配置，平均利用率只有 30%
- 弹性伸缩：平均利用率 60-70%，**资源成本降低 40%**

---

## 二、Kubernetes 弹性伸缩全景

### 2.1 三种伸缩方式

Kubernetes 提供了 3 个层次的伸缩：

```
┌─────────────────────────────────────────────┐
│  1. Pod 水平伸缩 (HPA)                      │
│     调整 Pod 副本数                          │
│     ↓ 最常用，本系列重点！                   │
├─────────────────────────────────────────────┤
│  2. Pod 垂直伸缩 (VPA)                      │
│     调整 Pod 的 CPU/内存配置                 │
│     ↓ 适合无状态应用                         │
├─────────────────────────────────────────────┤
│  3. 集群节点伸缩 (Cluster Autoscaler)       │
│     增加或减少节点数量                       │
│     ↓ 云平台自动管理                         │
└─────────────────────────────────────────────┘
```

**对比**：

| 类型 | 调整对象 | 适用场景 | 本系列 |
|------|---------|---------|--------|
| **HPA** | Pod 副本数 | 无状态应用、流量波动大 | ✅ v0.3 重点 |
| **VPA** | Pod 资源配置 | 资源需求变化的应用 | ❌ 暂不涉及 |
| **CA** | 集群节点数 | 云环境、资源池不足 | ❌ 暂不涉及 |

**为什么选择 HPA？**
- ✅ 最常用，覆盖 90% 的场景
- ✅ 响应快（秒级）
- ✅ 风险低（不会改变 Pod 配置）
- ✅ 适合我的 API 服务

### 2.2 HPA 工作原理

HPA 的核心逻辑很简单：

```
期望副本数 = 当前副本数 × (当前指标 / 目标指标)
```

**举例**：
```
当前: 2 个 Pod，CPU 使用率 140%
目标: 70%
计算: 2 × (140% / 70%) = 4 个 Pod

→ HPA 扩容到 4 个 Pod
→ 流量分散，CPU 降到 70%
→ 达到平衡
```

**完整流程**：

```
1. Metrics Server 每 15 秒采集一次指标
   ↓
2. HPA 控制器每 15 秒检查一次（可配置）
   ↓
3. 计算当前指标 vs 目标指标
   ↓
4. 决定扩容/缩容/不变
   ↓
5. 更新 Deployment 的 replicas
   ↓
6. Kubernetes 创建/删除 Pod
```

### 2.3 架构图解

```
┌──────────────┐
│   kubelet    │ ← 运行在每个节点
│   (cAdvisor) │ ← 收集容器指标
└──────┬───────┘
       │ 指标
       ↓
┌──────────────┐
│ Metrics      │ ← 聚合并暴露指标
│ Server       │ ← /apis/metrics.k8s.io/v1beta1
└──────┬───────┘
       │ 查询
       ↓
┌──────────────┐
│ HPA          │ ← 根据指标计算副本数
│ Controller   │ ← 更新 Deployment
└──────┬───────┘
       │ 调整
       ↓
┌──────────────┐
│ Deployment   │ ← 创建/删除 Pod
└──────────────┘
```

**关键点**：
- **cAdvisor**：内置在 kubelet 中，负责收集容器指标
- **Metrics Server**：聚合指标，提供 API（必须安装！）
- **HPA Controller**：Kubernetes 内置，自动运行
- **Deployment**：被 HPA 控制，副本数会自动变化

---

## 三、准备工作：理解资源管理

### 3.1 Resources Requests 和 Limits

在配置 HPA 之前，**必须理解资源管理**：

```yaml
resources:
  requests:      # 调度和计费的基准
    cpu: "100m"     # 100 毫核 = 0.1 核
    memory: "128Mi" # 128 兆字节
  limits:        # 硬性限制
    cpu: "500m"     # 最多用 0.5 核
    memory: "512Mi" # 最多用 512 MB
```

**requests vs limits**：

| 配置 | 作用 | 超出后果 |
|------|------|---------|
| **requests** | 调度保证、HPA 计算基准 | 可以超出（只要节点有余量）|
| **limits** | 硬性上限 | CPU 被限流，内存被 OOMKilled |

**为什么重要？**
```
HPA 的 CPU 利用率 = 实际使用 / requests

例如：
- requests: 100m
- 实际使用: 70m
- 利用率: 70%

如果没设置 requests → HPA 无法工作！
```

### 3.2 为什么 HPA 依赖 Requests？

**原因**：HPA 需要一个"基准"来计算利用率。

```yaml
# ❌ 错误：没有 requests，HPA 无法工作
resources:
  limits:
    cpu: "500m"
# HPA: "我不知道 100m 的实际使用算多少利用率！"

# ✅ 正确：有 requests，HPA 可以计算
resources:
  requests:
    cpu: "100m"   # 基准
  limits:
    cpu: "500m"   # 上限
# HPA: "70m / 100m = 70% 利用率，很好！"
```

### 3.3 配置建议

基于我的实践经验：

```yaml
# 推荐配置（适用于大多数 API 服务）
resources:
  requests:
    cpu: "100m"      # 保守一点，确保能调度
    memory: "128Mi"  # 基础内存
  limits:
    cpu: "500m"      # 5 倍突发空间
    memory: "512Mi"  # 4 倍突发空间（防止 OOM）
```

**为什么这样配置？**
- **requests 小**：Pod 容易调度，HPA 容易触发（CPU 容易超过 70%）
- **limits 大**：给突发流量足够的缓冲空间
- **比例合理**：避免资源浪费

**错误配置示例**：

```yaml
# ❌ 错误 1：limits = requests（无突发空间）
resources:
  requests:
    cpu: "500m"
  limits:
    cpu: "500m"  # 没有突发空间，容易卡顿

# ❌ 错误 2：requests 过大（HPA 难以触发）
resources:
  requests:
    cpu: "500m"  # 太大了，CPU 很难超过 70%
  limits:
    cpu: "1000m"

# ❌ 错误 3：limits 过小（容易 OOM）
resources:
  requests:
    memory: "128Mi"
  limits:
    memory: "200Mi"  # 太小，高负载时容易 OOMKilled
```

---

## 四、安装 Metrics Server

### 4.1 什么是 Metrics Server？

Metrics Server 是 Kubernetes 的**核心组件**，负责：
- ✅ 收集节点和 Pod 的 CPU、内存使用情况
- ✅ 提供 Metrics API（`kubectl top` 和 HPA 依赖它）
- ✅ 每 15 秒更新一次数据

**依赖关系**：
```
kubectl top nodes/pods → Metrics Server → HPA
                              ↓
                         必须先安装！
```

### 4.2 安装步骤

**Step 1: 下载并安装**

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

**Step 2: 等待部署完成**

```bash
kubectl get deployment metrics-server -n kube-system
```

预期输出：
```
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
metrics-server   1/1     1            1           30s
```

**Step 3: 验证 Pod 状态**

```bash
kubectl get pods -n kube-system -l k8s-app=metrics-server
```

预期输出：
```
NAME                              READY   STATUS    RESTARTS   AGE
metrics-server-xxxxxxxxx-xxxxx    1/1     Running   0          1m
```

### 4.3 我踩的坑：Metrics API not available

**问题现象**：

```bash
$ kubectl top nodes
Error from server (ServiceUnavailable): the server is currently unable to handle the request (get nodes.metrics.k8s.io)
```

**原因**：
- 本地 Kubernetes 环境（Docker Desktop、Minikube、Kind）
- Metrics Server 默认配置需要 TLS 证书
- 本地环境没有有效的证书 → 连接失败

**解决方案：禁用 TLS 验证**

```bash
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  }
]'
```

**等待 Pod 重启**：

```bash
kubectl rollout status deployment metrics-server -n kube-system
```

**再次验证**：

```bash
$ kubectl top nodes
NAME             CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
docker-desktop   250m         3%     1500Mi          19%
```

✅ 成功！

**注意**：
- ⚠️ `--kubelet-insecure-tls` 仅用于**本地开发环境**
- ⚠️ 生产环境必须配置正确的 TLS 证书
- ⚠️ Minikube 用户可能还需要添加 `--kubelet-preferred-address-types=InternalIP`

### 4.4 验证安装

**测试 1: 查看节点指标**

```bash
kubectl top nodes
```

**测试 2: 查看 Pod 指标**

```bash
kubectl top pods --all-namespaces
```

**测试 3: 查看 Metrics API**

```bash
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes | jq .
```

如果都能正常返回数据，说明 Metrics Server 安装成功！

---

## 五、添加负载测试接口

### 5.1 为什么需要负载接口？

为了测试 HPA，我需要：
- 能够**主动触发 CPU 负载**（让 CPU 使用率上升）
- 能够**主动触发内存负载**（让内存使用率上升）
- 观察 HPA 的自动扩缩容行为

**所以我在 API 服务中添加了 3 个测试接口**：
1. `/api/v1/workload/cpu` - CPU 密集型任务
2. `/api/v1/workload/memory` - 内存密集型任务
3. `/api/v1/workload` - 混合负载

### 5.2 实现 CPU 密集型接口

**核心思路**：通过大量数学计算消耗 CPU。

```go
// src/handler/workload.go
package handler

import (
	"math"
	"runtime"
	"strconv"
	"time"
	
	"github.com/gin-gonic/gin"
)

// CPUIntensiveHandler CPU 密集型接口
func CPUIntensiveHandler(c *gin.Context) {
	iterations := getIntParam(c, "iterations", 10000000)
	
	startTime := time.Now()
	result := cpuWorkload(iterations / 1000000)
	duration := time.Since(startTime)
	
	c.JSON(200, gin.H{
		"result":      result,
		"iterations":  iterations,
		"duration_ms": duration.Milliseconds(),
		"goroutines":  runtime.NumGoroutine(),
		"cpu_cores":   runtime.NumCPU(),
		"message":     "CPU intensive task completed",
	})
}

// cpuWorkload 执行 CPU 密集型计算
func cpuWorkload(intensity int) float64 {
	result := 0.0
	iterations := intensity * 1000000
	
	for i := 0; i < iterations; i++ {
		result += math.Sqrt(float64(i))
		result += math.Sin(float64(i))
		result += math.Cos(float64(i))
		result += math.Tan(float64(i))
		
		if i%10000 == 0 {
			result += math.Pow(float64(i), 2)
			result += math.Log(float64(i + 1))
		}
	}
	
	return result
}
```

**使用示例**：

```bash
# 低强度（10 百万次迭代）
curl "http://localhost:8080/api/v1/workload/cpu?iterations=10000000"

# 高强度（50 百万次迭代）
curl "http://localhost:8080/api/v1/workload/cpu?iterations=50000000"
```

### 5.3 实现内存密集型接口

**核心思路**：分配大量内存并持有一段时间。

```go
// MemoryIntensiveHandler 内存密集型接口
func MemoryIntensiveHandler(c *gin.Context) {
	sizeMB := getIntParam(c, "size", 50)
	durationSec := getIntParam(c, "duration", 3)
	
	// 限制最大内存分配（防止 OOM）
	if sizeMB > 200 {
		c.JSON(400, gin.H{
			"error":   "Size too large",
			"max_mb":  200,
			"message": "请求的内存大小超过限制",
		})
		return
	}
	
	startTime := time.Now()
	
	// 分配内存
	data := make([]byte, sizeMB*1024*1024)
	
	// 填充数据（防止编译器优化掉）
	for i := range data {
		data[i] = byte(i % 256)
	}
	
	// 持有内存一段时间
	time.Sleep(time.Duration(durationSec) * time.Second)
	
	elapsed := time.Since(startTime)
	
	// 获取内存统计
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	
	c.JSON(200, gin.H{
		"allocated_mb": sizeMB,
		"duration_sec": durationSec,
		"actual_ms":    elapsed.Milliseconds(),
		"memory_stats": gin.H{
			"alloc_mb":       m.Alloc / 1024 / 1024,
			"total_alloc_mb": m.TotalAlloc / 1024 / 1024,
			"sys_mb":         m.Sys / 1024 / 1024,
			"num_gc":         m.NumGC,
		},
		"message": "Memory intensive task completed",
	})
}
```

**使用示例**：

```bash
# 分配 50MB，持有 3 秒
curl "http://localhost:8080/api/v1/workload/memory?size=50&duration=3"

# 分配 100MB，持有 5 秒
curl "http://localhost:8080/api/v1/workload/memory?size=100&duration=5"
```

### 5.4 代码解析

**为什么 CPU 接口要做这么多计算？**

```go
result += math.Sqrt(float64(i))  // 平方根
result += math.Sin(float64(i))   // 正弦
result += math.Cos(float64(i))   // 余弦
result += math.Tan(float64(i))   // 正切
```

- 数学计算是 CPU 密集型操作
- 多种运算增加 CPU 负载
- 迭代次数越多，CPU 使用率越高

**为什么内存接口要填充数据？**

```go
for i := range data {
    data[i] = byte(i % 256)  // 填充每个字节
}
```

- 防止 Go 编译器优化掉未使用的内存
- 确保内存真实分配和占用
- 模拟真实的内存使用场景

**为什么要限制最大值？**

```go
if sizeMB > 200 {
    return error
}
```

- 防止恶意请求导致 OOM
- 保护 Pod 稳定性
- 200MB 已经足够测试 HPA

---

## 六、优化资源配置

### 6.1 调整 Deployment 资源

为了支持负载测试和 HPA，我调整了 Deployment 配置：

```yaml
# k8s/v0.3/api/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudnative-api
spec:
  replicas: 2  # 初始 2 个副本
  template:
    spec:
      containers:
      - name: api
        image: cloudnative-api:v0.3
        ports:
        - containerPort: 8080
        
        # ⭐ 关键：资源配置
        resources:
          requests:
            cpu: "100m"      # HPA 基准
            memory: "128Mi"
          limits:
            cpu: "500m"      # 5 倍突发
            memory: "512Mi"  # 4 倍突发（从 256Mi 提升）
        
        # ... 省略其他配置
```

**关键变化**：

| 配置项 | v0.2 | v0.3 | 原因 |
|-------|------|------|------|
| **memory limits** | 256Mi | **512Mi** | 支持负载测试（防止 OOM）|
| **cpu limits** | 300m | **500m** | 更大的突发空间 |
| **memory requests** | 64Mi | **128Mi** | 提高基准，更合理 |

### 6.2 优化探针配置

在高负载下，探针可能会失败导致 Pod 重启。我优化了探针配置：

```yaml
# 存活探针（优化：增加超时和失败阈值）
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 15      # 增加初始延迟
  periodSeconds: 15            # 降低检查频率
  timeoutSeconds: 10           # 增加超时时间
  failureThreshold: 5          # 允许更多失败（75 秒）

# 就绪探针（优化：适应负载测试）
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10            # 降低检查频率
  timeoutSeconds: 10           # ⭐ 关键：增加超时
  failureThreshold: 6          # 允许更多失败（60 秒）
```

### 6.3 为什么这样配置？

**问题：高负载下探针超时**

```
场景：30 个并发请求，CPU 100%
↓
就绪探针 3 秒超时
↓
应用忙于处理请求，无法及时响应探针
↓
探针失败 3 次
↓
Kubernetes: "Pod 不健康，重启！"
↓
Pod 重启 → 正在处理的请求全部丢失
↓
恶性循环：CrashLoopBackOff
```

**解决方案：放宽探针配置**

```
timeoutSeconds: 3 → 10       # 给 7 秒额外时间
failureThreshold: 3 → 6      # 允许失败 60 秒
periodSeconds: 5 → 10        # 降低检查频率
```

**效果**：
- ✅ Pod 不会因为短暂的高负载被误杀
- ✅ 给应用足够的缓冲时间
- ✅ 压测期间 Pod 稳定运行

---

## 七、初次测试

### 7.1 构建和部署

```bash
# 1. 构建新镜像（包含负载接口）
docker build -t cloudnative-api:v0.3 .

# 2. 如果是 Minikube，设置 Docker 环境
eval $(minikube docker-env)
docker build -t cloudnative-api:v0.3 .

# 3. 部署应用
kubectl apply -f k8s/v0.3/api/deployment.yaml
kubectl apply -f k8s/v0.3/api/service.yaml

# 4. 等待 Pod 就绪
kubectl wait --for=condition=available --timeout=60s deployment/cloudnative-api

# 5. 查看状态
kubectl get pods -l app=cloudnative-api
```

### 7.2 手动触发负载

**测试 CPU 接口**：

```bash
# 使用 Minikube Service（推荐）
export SERVICE_URL=$(minikube service cloudnative-api-service --url)

# 轻量测试（10 百万次迭代）
curl "$SERVICE_URL/api/v1/workload/cpu?iterations=10000000"

# 重量测试（30 百万次迭代）
curl "$SERVICE_URL/api/v1/workload/cpu?iterations=30000000"
```

**测试内存接口**：

```bash
# 分配 50MB
curl "$SERVICE_URL/api/v1/workload/memory?size=50&duration=3"

# 分配 100MB
curl "$SERVICE_URL/api/v1/workload/memory?size=100&duration=5"
```

### 7.3 观察资源使用

**实时监控 Pod 资源**：

```bash
# 终端 1：实时查看资源使用
watch -n 1 kubectl top pods -l app=cloudnative-api

# 输出示例：
NAME                               CPU(cores)   MEMORY(bytes)
cloudnative-api-xxxxxxxxx-xxxxx    15m          85Mi         # 空闲
cloudnative-api-xxxxxxxxx-xxxxx    250m         180Mi        # 负载中
```

**发送多个请求观察变化**：

```bash
# 终端 2：循环发送请求
for i in {1..20}; do
  echo "Request $i"
  curl -s "$SERVICE_URL/api/v1/workload/cpu?iterations=20000000" > /dev/null
  sleep 1
done
```

**观察现象**：
- CPU 使用从 15m 上升到 150m+
- 内存使用从 85Mi 上升到 150Mi+
- 请求完成后，资源逐渐降低

**计算利用率**：

```
CPU 利用率 = 实际使用 / requests = 150m / 100m = 150%
内存利用率 = 实际使用 / requests = 150Mi / 128Mi = 117%
```

✅ 这就是 HPA 会看到的指标！

---

## 结语

这篇文章中，我完成了 HPA 的所有**准备工作**：

### ✅ 我学到了什么

1. **弹性伸缩的价值**
   - 自动应对流量变化
   - 节省资源成本
   - 提高系统可靠性

2. **Kubernetes 弹性伸缩体系**
   - HPA（Pod 水平伸缩）← 本系列重点
   - VPA（Pod 垂直伸缩）
   - Cluster Autoscaler（节点伸缩）

3. **资源管理的重要性**
   - requests 是 HPA 的计算基准
   - limits 防止资源耗尽
   - 合理配置才能发挥 HPA 效果

4. **Metrics Server**
   - 提供资源指标 API
   - kubectl top 和 HPA 的依赖
   - 本地环境需要禁用 TLS 验证

5. **负载测试接口**
   - CPU 密集型：数学计算
   - 内存密集型：分配和持有内存
   - 为 HPA 测试做好准备

6. **探针优化**
   - 高负载下需要放宽超时
   - 避免误杀繁忙的 Pod
   - failureThreshold 很重要

### 🚀 下一步

**下一篇文章**，我会：
- ✅ 详细讲解 HPA 的配置
- ✅ 实战部署 HPA
- ✅ 观察自动扩缩容过程
- ✅ 调优 HPA 策略

**敬请期待《HPA 完全指南：从原理到实践》！**

---

**相关文章**：
- 上一篇：[CronJob 实战：定时清理 Redis 过期数据](../v0.2/08-cronjob-cleanup-practice.md)
- 下一篇：[HPA 完全指南：从原理到实践](./10-hpa-complete-guide.md)
- 再下一篇：[压测实战：验证弹性伸缩效果](./11-load-testing-hpa-validation.md)

**项目代码**：[GitHub - cloudnative-go-journey](https://github.com/yourusername/cloudnative-go-journey)

