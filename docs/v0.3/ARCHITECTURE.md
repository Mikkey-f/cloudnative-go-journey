# v0.3 技术架构

> 弹性伸缩版的架构设计和技术方案

---

## 🏗️ 整体架构

### 系统架构图

```
┌─────────────────────────────────────────────────────────────┐
│                      Kubernetes Cluster                      │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                  Control Plane                          │ │
│  │                                                          │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │ │
│  │  │              │  │              │  │              │ │ │
│  │  │   API        │  │  Controller  │  │  Scheduler   │ │ │
│  │  │   Server     │  │  Manager     │  │              │ │ │
│  │  │              │  │              │  │              │ │ │
│  │  └──────┬───────┘  └──────────────┘  └──────────────┘ │ │
│  │         │                                                │ │
│  │         │ ┌────────────────────────────────────────┐   │ │
│  │         └─┤  HPA Controller (控制循环每15秒)       │   │ │
│  │           │  - 查询 Metrics API                    │   │ │
│  │           │  - 计算期望副本数                       │   │ │
│  │           │  - 更新 Deployment                     │   │ │
│  │           └────────────────────────────────────────┘   │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                    Worker Nodes                         │ │
│  │                                                          │ │
│  │  ┌──────────────────────────────────────────────────┐  │ │
│  │  │  Metrics Server (独立部署)                       │  │ │
│  │  │  ┌────────────────────────────────────────────┐  │  │ │
│  │  │  │  Metrics API Server                        │  │  │ │
│  │  │  │  /apis/metrics.k8s.io/v1beta1/nodes        │  │  │ │
│  │  │  │  /apis/metrics.k8s.io/v1beta1/pods         │  │  │ │
│  │  │  └────────────────────────────────────────────┘  │  │ │
│  │  │  │                                                 │  │ │
│  │  │  │ 每15秒轮询所有 kubelet                         │  │ │
│  │  │  ↓                                                 │  │ │
│  │  └──────────────────────────────────────────────────┘  │ │
│  │                                                          │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │ │
│  │  │   Node 1     │  │   Node 2     │  │   Node 3     │ │ │
│  │  │              │  │              │  │              │ │ │
│  │  │  ┌────────┐  │  │  ┌────────┐  │  │  ┌────────┐  │ │ │
│  │  │  │kubelet │  │  │  │kubelet │  │  │  │kubelet │  │ │ │
│  │  │  │        │  │  │  │        │  │  │  │        │  │ │ │
│  │  │  │ ┌────┐ │  │  │  │ ┌────┐ │  │  │  │ ┌────┐ │  │ │ │
│  │  │  │ │cAdv│ │  │  │  │ │cAdv│ │  │  │  │ │cAdv│ │  │ │ │
│  │  │  └─┴────┴─┘  │  │  └─┴────┴─┘  │  │  └─┴────┴─┘  │ │ │
│  │  │  │            │  │  │            │  │  │            │ │ │
│  │  │  │  ┌──────┐ │  │  │  ┌──────┐ │  │  │  ┌──────┐ │ │ │
│  │  │  │  │ Pod  │ │  │  │  │ Pod  │ │  │  │  │ Pod  │ │ │ │
│  │  │  │  │ API  │ │  │  │  │ API  │ │  │  │  │ API  │ │ │ │
│  │  │  │  └──────┘ │  │  │  └──────┘ │  │  │  └──────┘ │ │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘ │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

外部压测工具
    │
    │ HTTP 请求
    ↓
┌─────────────┐
│  k6 Load    │
│  Testing    │
└─────────────┘
```

---

## 🔄 HPA 工作流程

### 完整的扩缩容流程

```
1. 应用负载增加
   │
   ├─> CPU 使用增加
   │
   ├─> cAdvisor 采集 (容器级)
   │
   ├─> kubelet 聚合 (Pod 级)
   │
   ├─> Metrics Server 收集 (集群级，每15秒)
   │
   ├─> 暴露 Metrics API
   │
2. HPA 控制循环 (每15秒)
   │
   ├─> 查询 Metrics API
   │   GET /apis/metrics.k8s.io/v1beta1/namespaces/default/pods
   │
   ├─> 计算当前使用率
   │   当前CPU = sum(所有Pod CPU) / sum(所有Pod requests)
   │
   ├─> 对比目标值
   │   if 当前使用率 > 目标值 * 1.1 → 扩容
   │   if 当前使用率 < 目标值 * 0.9 → 缩容
   │
   ├─> 计算期望副本数
   │   期望副本 = ceil(当前副本 × (当前使用率 / 目标使用率))
   │
   ├─> 检查限制
   │   期望副本 = max(minReplicas, min(期望副本, maxReplicas))
   │
   ├─> 检查冷却期
   │   扩容：检查上次扩容时间
   │   缩容：检查稳定窗口（默认5分钟）
   │
   └─> 更新 Deployment
       kubectl patch deployment ... --replicas=期望副本数
       │
3. Deployment 控制器
   │
   ├─> 创建新 Pod (扩容) 或删除 Pod (缩容)
   │
   ├─> 调度器分配节点
   │
   ├─> kubelet 启动容器
   │
   └─> Pod Ready
       │
4. 负载重新分配
   │
   └─> Service 更新 Endpoints → 流量分配到新 Pod
```

---

## 📊 数据流详解

### Metrics 数据采集流程

```
┌─────────────────────────────────────────────────────────────┐
│                     Container Runtime                        │
│  (Docker/containerd)                                         │
│                                                               │
│  ┌──────┐  ┌──────┐  ┌──────┐                               │
│  │ CPU  │  │Memory│  │ I/O  │  容器资源使用                 │
│  └──┬───┘  └──┬───┘  └──┬───┘                               │
└─────┼─────────┼─────────┼─────────────────────────────────────┘
      │         │         │
      ↓         ↓         ↓
┌─────────────────────────────────────────────────────────────┐
│                        cAdvisor                              │
│  (Container Advisor - 内嵌在 kubelet 中)                    │
│                                                               │
│  - 从 cgroups 读取资源使用数据                               │
│  - 采集间隔: 15秒                                            │
│  - 存储: 内存中保留最近2分钟数据                             │
│                                                               │
│  采集指标:                                                    │
│  - cpu.usage_total (累计纳秒)                                │
│  - memory.working_set (工作集字节)                           │
│  - network.rx_bytes / tx_bytes                               │
│  - filesystem.usage                                          │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────────────────────────────┐
│                         kubelet                              │
│  (每个节点的代理)                                            │
│                                                               │
│  功能:                                                        │
│  1. 聚合容器数据为 Pod 级别数据                              │
│  2. 添加 Pod 元数据 (namespace, name, labels)                │
│  3. 计算速率 (CPU 从累计值计算速率)                          │
│                                                               │
│  暴露 API:                                                    │
│  - /metrics/resource (推荐, v0.6.0+)                         │
│  - /stats/summary (旧版)                                     │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────────────────────────────┐
│                     Metrics Server                           │
│  (集群级别的聚合器)                                          │
│                                                               │
│  工作流程:                                                    │
│  1. 服务发现: 通过 API Server 获取所有节点列表              │
│  2. 轮询采集: 每15秒向每个 kubelet 请求 /metrics/resource   │
│  3. 数据聚合: 汇总所有节点的 Pod 数据                        │
│  4. 内存存储: 只保留最近30秒的数据                           │
│  5. API 暴露: 通过 Metrics API 提供查询接口                 │
│                                                               │
│  数据格式:                                                    │
│  {                                                            │
│    "metadata": {...},                                         │
│    "timestamp": "2025-11-01T12:00:00Z",                      │
│    "window": "30s",  ← 时间窗口                              │
│    "usage": {                                                 │
│      "cpu": "250m",    ← millicores                          │
│      "memory": "128Mi" ← MiB                                 │
│    }                                                          │
│  }                                                            │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────────────────────────────┐
│                      Metrics API                             │
│  /apis/metrics.k8s.io/v1beta1/                               │
│                                                               │
│  端点:                                                        │
│  - /nodes               ← 所有节点指标                       │
│  - /nodes/{name}        ← 单个节点指标                       │
│  - /pods                ← 所有命名空间所有Pod指标            │
│  - /namespaces/{ns}/pods ← 特定命名空间的Pod指标            │
│  - /namespaces/{ns}/pods/{name} ← 单个Pod指标               │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────────────────────────────┐
│                    HPA Controller                            │
│  (HorizontalPodAutoscaler 控制器)                           │
│                                                               │
│  查询: GET /apis/metrics.k8s.io/v1beta1/namespaces/default/pods
│        ?labelSelector=app=cloudnative-api                    │
│                                                               │
│  计算: 期望副本数 = ceil(当前副本 × (当前指标/目标指标))    │
│                                                               │
│  执行: PATCH /apis/apps/v1/namespaces/default/deployments/   │
│        cloudnative-api                                       │
│        {"spec": {"replicas": 期望副本数}}                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 HPA 算法详解

### 扩缩容计算公式

```go
// HPA 控制器的核心算法（简化版）

func calculateReplicaCount(
    currentReplicas int32,
    currentMetric float64,
    targetMetric float64,
) int32 {
    // 1. 计算使用率比例
    ratio := currentMetric / targetMetric
    
    // 2. 计算期望副本数（向上取整）
    desiredReplicas := math.Ceil(float64(currentReplicas) * ratio)
    
    // 3. 应用容忍度（10%）
    // 只有当比例 > 1.1 或 < 0.9 时才扩缩容
    if ratio > 0.9 && ratio < 1.1 {
        return currentReplicas // 保持不变
    }
    
    return int32(desiredReplicas)
}
```

### 实际案例计算

**场景 1: 扩容**
```
当前状态:
- 副本数: 2
- CPU requests: 100m (每个Pod)
- 实际 CPU 使用: Pod1=150m, Pod2=160m
- 平均使用: (150+160)/2 = 155m
- 使用率: 155/100 = 155%
- 目标使用率: 70%

计算过程:
ratio = 155% / 70% = 2.21
desiredReplicas = ceil(2 × 2.21) = ceil(4.42) = 5

结果: 扩容到 5 个副本
```

**场景 2: 缩容**
```
当前状态:
- 副本数: 5
- CPU requests: 100m (每个Pod)
- 实际 CPU 使用: 平均 30m
- 使用率: 30/100 = 30%
- 目标使用率: 70%

计算过程:
ratio = 30% / 70% = 0.43
desiredReplicas = ceil(5 × 0.43) = ceil(2.15) = 3

结果: 缩容到 3 个副本
(但需要等待5分钟稳定期)
```

---

## 🏛️ 组件设计

### 1. API 服务改进

```go
// src/handler/workload.go - 新增文件

package handler

import (
    "math"
    "github.com/gin-gonic/gin"
)

// CPUIntensiveHandler - CPU 密集型接口
// 用于触发 HPA 扩容测试
func CPUIntensiveHandler(c *gin.Context) {
    // 获取计算强度参数（默认1000万次循环）
    iterations := getIntParam(c, "iterations", 10000000)
    
    // CPU 密集型计算
    result := 0.0
    for i := 0; i < iterations; i++ {
        result += math.Sqrt(float64(i))
    }
    
    // 返回结果
    c.JSON(200, gin.H{
        "result": result,
        "iterations": iterations,
        "message": "CPU intensive task completed",
    })
}

// MemoryIntensiveHandler - 内存密集型接口
func MemoryIntensiveHandler(c *gin.Context) {
    // 获取内存分配大小（默认100MB）
    sizeMB := getIntParam(c, "size", 100)
    
    // 分配内存
    data := make([]byte, sizeMB*1024*1024)
    
    // 填充数据（防止编译器优化掉）
    for i := range data {
        data[i] = byte(i % 256)
    }
    
    // 模拟使用内存一段时间
    time.Sleep(time.Duration(getIntParam(c, "duration", 5)) * time.Second)
    
    c.JSON(200, gin.H{
        "allocated_mb": sizeMB,
        "message": "Memory intensive task completed",
    })
}

// WorkloadHandler - 综合负载接口
func WorkloadHandler(c *gin.Context) {
    // 可配置的 CPU + Memory + 延迟
    // 模拟真实业务场景
}
```

### 2. Deployment 配置优化

```yaml
# k8s/v0.3/api/deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudnative-api
  labels:
    app: cloudnative-api
    version: v0.3
spec:
  replicas: 2  # 初始副本数（HPA 会管理）
  selector:
    matchLabels:
      app: cloudnative-api
  template:
    metadata:
      labels:
        app: cloudnative-api
        version: v0.3
    spec:
      containers:
      - name: api
        image: cloudnative-api:v0.3
        ports:
        - containerPort: 8080
        
        # 关键：资源配置
        # HPA 会基于这个 requests 计算使用率
        resources:
          requests:
            memory: "128Mi"  # 提高基准（v0.2是64Mi）
            cpu: "100m"      # 保持不变
          limits:
            memory: "256Mi"  # 2x 突发比
            cpu: "300m"      # 3x 突发比（v0.2是500m）
        
        # 健康检查
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
        
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

### 3. HPA 配置设计

```yaml
# k8s/v0.3/api/hpa.yaml

apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: cloudnative-api-hpa
  labels:
    app: cloudnative-api
spec:
  # 扩缩目标
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: cloudnative-api
  
  # 副本数范围
  minReplicas: 2   # 最小2个保证高可用
  maxReplicas: 10  # 最大10个控制成本
  
  # 扩缩指标
  metrics:
  # 指标1: CPU 使用率
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70  # 目标70%
  
  # 指标2: 内存使用率（可选）
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80  # 目标80%
  
  # 扩缩行为控制（v2 特性）
  behavior:
    # 缩容行为
    scaleDown:
      stabilizationWindowSeconds: 300  # 5分钟稳定期
      policies:
      - type: Pods
        value: 1            # 每次最多缩容1个Pod
        periodSeconds: 60   # 每60秒评估一次
      - type: Percent
        value: 10           # 或每次最多缩容10%
        periodSeconds: 60
      selectPolicy: Min     # 选择更保守的策略
    
    # 扩容行为
    scaleUp:
      stabilizationWindowSeconds: 0    # 立即扩容
      policies:
      - type: Pods
        value: 2            # 每次最多增加2个Pod
        periodSeconds: 60
      - type: Percent
        value: 100          # 或每次最多翻倍
        periodSeconds: 15
      selectPolicy: Max     # 选择更激进的策略
```

---

## 🧪 压测设计

### k6 压测策略

```javascript
// k6-tests/05-hpa-validation.js

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// 自定义指标
const errorRate = new Rate('errors');

// 压测配置
export let options = {
    // 阶段性增加负载
    stages: [
        { duration: '1m', target: 10 },    // 预热: 1分钟到10VU
        { duration: '3m', target: 50 },    // 增压: 3分钟到50VU
        { duration: '3m', target: 100 },   // 峰值: 3分钟到100VU
        { duration: '2m', target: 50 },    // 降压: 2分钟到50VU
        { duration: '3m', target: 0 },     // 冷却: 3分钟到0VU
    ],
    
    // 性能阈值
    thresholds: {
        'http_req_duration': ['p(95)<500'],  // 95%请求<500ms
        'errors': ['rate<0.1'],               // 错误率<10%
    },
};

export default function() {
    // 请求CPU密集型接口
    let res = http.get('http://localhost:8080/api/workload/cpu?iterations=5000000');
    
    // 检查响应
    check(res, {
        'status is 200': (r) => r.status === 200,
        'response time < 1s': (r) => r.timings.duration < 1000,
    }) || errorRate.add(1);
    
    sleep(1);  // 请求间隔1秒
}
```

### 压测观察点

```bash
# 终端1: 观察HPA状态
watch kubectl get hpa cloudnative-api-hpa

# 终端2: 观察Pod数量
watch kubectl get pods -l app=cloudnative-api

# 终端3: 观察资源使用
watch kubectl top pods

# 终端4: 运行压测
k6 run k6-tests/05-hpa-validation.js

# 终端5: 观察事件
kubectl get events --sort-by='.lastTimestamp' -w
```

---

## 📈 监控和观测

### 关键指标

```yaml
# Prometheus 指标（应用暴露）

# HPA 相关指标
kube_horizontalpodautoscaler_status_current_replicas  # 当前副本数
kube_horizontalpodautoscaler_status_desired_replicas  # 期望副本数
kube_horizontalpodautoscaler_spec_min_replicas        # 最小副本数
kube_horizontalpodautoscaler_spec_max_replicas        # 最大副本数

# Pod 资源使用
container_cpu_usage_seconds_total     # CPU 使用（累计）
container_memory_working_set_bytes    # 内存工作集

# 应用指标
api_requests_total                    # 总请求数
api_request_duration_seconds          # 请求延迟
api_cpu_intensive_requests_total      # CPU密集型请求数
```

---

## 🔍 技术难点和解决方案

### 难点 1: Metrics Server 数据延迟

**问题**: 
- cAdvisor 采集延迟: 15秒
- Metrics Server 查询延迟: 15秒
- HPA 查询延迟: 15秒
- 总延迟: 30-45秒

**影响**:
- 扩容响应不够实时
- 突发流量可能导致短时过载

**解决方案**:
- 预留足够的资源缓冲（limits > requests）
- 设置合理的目标使用率（不要100%）
- 考虑使用更快的自定义指标
- 优化应用启动时间

### 难点 2: 冷启动问题

**问题**:
- 新 Pod 创建需要时间（镜像拉取、启动）
- 健康检查需要时间
- 这期间现有 Pod 可能过载

**解决方案**:
```yaml
# 1. 优化镜像大小
# 2. 使用 imagePullPolicy: IfNotPresent
# 3. 优化启动时间
# 4. 合理设置健康检查延迟

readinessProbe:
  initialDelaySeconds: 5   # 不要太长
  periodSeconds: 5         # 检查频率
  successThreshold: 1      # 1次成功即可
```

### 难点 3: 频繁抖动

**问题**:
- 负载波动导致频繁扩缩
- 浪费资源，影响稳定性

**解决方案**:
```yaml
behavior:
  scaleDown:
    stabilizationWindowSeconds: 300  # 增加稳定窗口
  scaleUp:
    policies:
    - type: Percent
      value: 50  # 限制单次扩容幅度
```

---

## 🎯 设计原则

### 1. 可靠性优先
- minReplicas >= 2（高可用）
- 保留资源缓冲
- 渐进式扩缩容

### 2. 成本优化
- 合理的 maxReplicas
- 及时缩容（但不要太激进）
- 资源配置优化

### 3. 性能保证
- 目标使用率不要太高（70-80%）
- 快速扩容，保守缩容
- 监控响应时间

### 4. 可观测性
- 完整的指标暴露
- 事件记录
- 日志详细

---

## 📊 性能目标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| 扩容响应时间 | < 2分钟 | 从触发到新Pod Ready |
| 缩容稳定期 | 5分钟 | 防止抖动 |
| CPU 使用率 | 60-80% | 保留缓冲 |
| 内存使用率 | 60-80% | 保留缓冲 |
| 请求成功率 | > 99% | 扩缩过程不影响服务 |
| P95 延迟 | < 500ms | 性能保证 |

---

**下一步**: 查看 [PROJECT-STRUCTURE.md](./PROJECT-STRUCTURE.md) 了解详细项目结构

