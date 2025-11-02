# 从零开始的云原生之旅（十）：HPA 完全指南：从原理到实践

> 配置 HPA 后，看着 Pod 自动扩缩容，太爽了！

## 📖 文章目录

- [前言](#前言)
- [一、HPA 核心概念深度解析](#一hpa-核心概念深度解析)
  - [1.1 HPA 的三个核心问题](#11-hpa-的三个核心问题)
  - [1.2 HPA 计算公式详解](#12-hpa-计算公式详解)
  - [1.3 指标类型详解](#13-指标类型详解)
- [二、HPA 配置文件完全解读](#二hpa-配置文件完全解读)
  - [2.1 基础配置结构](#21-基础配置结构)
  - [2.2 Metrics 配置详解](#22-metrics-配置详解)
  - [2.3 Behavior 行为控制](#23-behavior-行为控制)
  - [2.4 完整配置示例](#24-完整配置示例)
- [三、部署第一个 HPA](#三部署第一个-hpa)
  - [3.1 创建 HPA 配置](#31-创建-hpa-配置)
  - [3.2 应用 HPA](#32-应用-hpa)
  - [3.3 验证 HPA 状态](#33-验证-hpa-状态)
  - [3.4 我踩的坑：TARGETS 显示 unknown](#34-我踩的坑targets-显示-unknown)
- [四、观察自动扩容](#四观察自动扩容)
  - [4.1 准备监控窗口](#41-准备监控窗口)
  - [4.2 触发扩容](#42-触发扩容)
  - [4.3 扩容过程解析](#43-扩容过程解析)
  - [4.4 扩容时间线](#44-扩容时间线)
- [五、观察自动缩容](#五观察自动缩容)
  - [5.1 停止负载](#51-停止负载)
  - [5.2 缩容过程解析](#52-缩容过程解析)
  - [5.3 为什么缩容这么慢？](#53-为什么缩容这么慢)
- [六、HPA 行为策略详解](#六hpa-行为策略详解)
  - [6.1 ScaleUp 策略](#61-scaleup-策略)
  - [6.2 ScaleDown 策略](#62-scaledown-策略)
  - [6.3 稳定窗口的作用](#63-稳定窗口的作用)
  - [6.4 策略组合示例](#64-策略组合示例)
- [七、多指标 HPA 配置](#七多指标-hpa-配置)
  - [7.1 CPU + 内存双指标](#71-cpu--内存双指标)
  - [7.2 多指标计算逻辑](#72-多指标计算逻辑)
  - [7.3 指标优先级](#73-指标优先级)
- [八、HPA 调优技巧](#八hpa-调优技巧)
  - [8.1 如何让 HPA 更敏感？](#81-如何让-hpa-更敏感)
  - [8.2 如何避免频繁抖动？](#82-如何避免频繁抖动)
  - [8.3 如何快速扩容、缓慢缩容？](#83-如何快速扩容缓慢缩容)
  - [8.4 如何设置合理的阈值？](#84-如何设置合理的阈值)
- [九、常见问题排查](#九常见问题排查)
  - [9.1 HPA 不工作](#91-hpa-不工作)
  - [9.2 HPA 显示 unknown](#92-hpa-显示-unknown)
  - [9.3 HPA 扩容太慢](#93-hpa-扩容太慢)
  - [9.4 HPA 频繁抖动](#94-hpa-频繁抖动)
  - [9.5 Pod 被 OOMKilled](#95-pod-被-oomkilled)
- [结语](#结语)

---

## 前言

在上一篇文章中，我完成了 HPA 的所有准备工作：
- ✅ 安装了 Metrics Server
- ✅ 优化了资源配置
- ✅ 添加了负载测试接口

现在，终于到了**最激动人心的时刻** - 配置 HPA，看着 Pod 自动扩缩容！

这篇文章，我会：
- ✅ 深入理解 HPA 的工作原理
- ✅ 手把手配置 HPA
- ✅ 观察和分析自动扩缩容过程
- ✅ 掌握 HPA 调优技巧
- ✅ **记录所有踩过的坑**

---

## 一、HPA 核心概念深度解析

### 1.1 HPA 的三个核心问题

HPA（HorizontalPodAutoscaler）要回答 3 个问题：

```
1. 什么时候扩容/缩容？
   → 根据指标判断（CPU、内存、自定义指标）

2. 扩容/缩容到多少个副本？
   → 根据公式计算期望副本数

3. 扩容/缩容的速度是多少？
   → 根据 behavior 策略控制
```

### 1.2 HPA 计算公式详解

HPA 的核心计算公式：

```
期望副本数 = ceil(当前副本数 × (当前指标值 / 目标指标值))
```

**ceil**: 向上取整函数

**举例 1 - CPU 扩容**：
```
当前状态：
- 当前副本数: 2
- 当前 CPU 使用率: 140%
- 目标 CPU 使用率: 70%

计算：
期望副本数 = ceil(2 × (140% / 70%))
          = ceil(2 × 2)
          = 4

结果: 扩容到 4 个副本
```

**举例 2 - 内存扩容**：
```
当前状态：
- 当前副本数: 4
- 当前内存使用率: 90%
- 目标内存使用率: 80%

计算：
期望副本数 = ceil(4 × (90% / 80%))
          = ceil(4 × 1.125)
          = ceil(4.5)
          = 5

结果: 扩容到 5 个副本
```

**举例 3 - 缩容**：
```
当前状态：
- 当前副本数: 10
- 当前 CPU 使用率: 30%
- 目标 CPU 使用率: 70%

计算：
期望副本数 = ceil(10 × (30% / 70%))
          = ceil(10 × 0.43)
          = ceil(4.3)
          = 5

结果: 缩容到 5 个副本
```

**关键点**：
- 使用率 > 目标 → 扩容
- 使用率 < 目标 → 缩容
- 使用率 ≈ 目标 → 不变

### 1.3 指标类型详解

HPA 支持 4 种指标类型：

| 类型 | 说明 | 使用场景 | 示例 |
|------|------|---------|------|
| **Resource** | CPU、内存 | 最常用，90% 的场景 | CPU > 70% 扩容 |
| **Pods** | 每个 Pod 的自定义指标 | 业务指标 | QPS > 100 扩容 |
| **Object** | Kubernetes 对象的指标 | Service、Ingress | Ingress RPS > 1000 |
| **External** | 外部指标 | 云平台、第三方服务 | SQS 队列长度 > 100 |

**本篇重点：Resource 类型（CPU 和内存）**

---

## 二、HPA 配置文件完全解读

### 2.1 基础配置结构

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa                    # HPA 名称
spec:
  scaleTargetRef:                  # 要控制的对象
    apiVersion: apps/v1
    kind: Deployment
    name: cloudnative-api          # Deployment 名称
  
  minReplicas: 2                   # 最少副本数
  maxReplicas: 10                  # 最多副本数
  
  metrics:                         # 指标配置
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  
  behavior:                        # 行为策略（可选）
    scaleUp: {}
    scaleDown: {}
```

### 2.2 Metrics 配置详解

**CPU 指标配置**：

```yaml
metrics:
- type: Resource                   # 资源类型
  resource:
    name: cpu                      # CPU 指标
    target:
      type: Utilization            # 利用率类型
      averageUtilization: 70       # 目标 70%
```

**计算方式**：
```
CPU 利用率 = (实际使用的 CPU / requests.cpu) × 100%

例如：
- requests.cpu: 100m
- 实际使用: 70m
- 利用率: 70%
```

**内存指标配置**：

```yaml
metrics:
- type: Resource
  resource:
    name: memory                   # 内存指标
    target:
      type: Utilization
      averageUtilization: 80       # 目标 80%
```

**为什么内存阈值通常比 CPU 高？**
- CPU 可以超用（throttling）
- 内存超用 → OOMKilled（进程被杀）
- 所以内存要留更多buffer（80% vs 70%）

**绝对值配置（不常用）**：

```yaml
metrics:
- type: Resource
  resource:
    name: memory
    target:
      type: AverageValue           # 绝对值类型
      averageValue: "100Mi"        # 每个 Pod 平均 100Mi
```

### 2.3 Behavior 行为控制

**为什么需要 behavior？**

默认的 HPA 行为可能不符合你的需求：
- 扩容可能太慢（流量突增时）
- 缩容可能太快（导致抖动）
- 需要细粒度控制

**Behavior 结构**：

```yaml
behavior:
  scaleUp:                         # 扩容策略
    stabilizationWindowSeconds: 0  # 稳定窗口（0 = 立即）
    policies:
    - type: Percent                # 百分比策略
      value: 100                   # 每次翻倍
      periodSeconds: 15            # 每 15 秒
    - type: Pods                   # 绝对数量策略
      value: 4                     # 或者增加 4 个
      periodSeconds: 15
    selectPolicy: Max              # 选择最激进的策略
  
  scaleDown:                       # 缩容策略
    stabilizationWindowSeconds: 300  # 5 分钟稳定期
    policies:
    - type: Pods
      value: 1                     # 每次减少 1 个
      periodSeconds: 60            # 每 60 秒
    selectPolicy: Min              # 选择最保守的策略
```

**关键参数解释**：

| 参数 | 作用 | 典型值 |
|------|------|--------|
| **stabilizationWindowSeconds** | 稳定窗口，防止抖动 | 扩容: 0-60s, 缩容: 300-600s |
| **type: Percent** | 按百分比调整 | 50%（增加一半）, 100%（翻倍）|
| **type: Pods** | 按绝对数量调整 | 1-5 个 |
| **periodSeconds** | 策略周期 | 15-60 秒 |
| **selectPolicy** | 策略选择 | Max（激进）, Min（保守）|

### 2.4 完整配置示例

```yaml
# k8s/v0.3/api/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: cloudnative-api-hpa
  labels:
    app: cloudnative-api
    version: v0.3
spec:
  # 1. 控制目标
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: cloudnative-api
  
  # 2. 副本数范围
  minReplicas: 2                   # 最少保持 2 个（高可用）
  maxReplicas: 10                  # 最多扩展到 10 个
  
  # 3. 扩缩容指标
  metrics:
  # CPU 指标
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70     # CPU 超过 70% 扩容
  
  # 内存指标
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80     # 内存超过 80% 扩容
  
  # 4. 扩缩容行为
  behavior:
    # 扩容策略：快速响应
    scaleUp:
      stabilizationWindowSeconds: 0    # 不等待，立即扩容
      policies:
      - type: Percent
        value: 100                     # 可以翻倍
        periodSeconds: 15              # 每 15 秒评估
      - type: Pods
        value: 2                       # 或者加 2 个
        periodSeconds: 60
      selectPolicy: Max                # 选择扩容更多的策略
    
    # 缩容策略：保守缓慢
    scaleDown:
      stabilizationWindowSeconds: 300  # 5 分钟稳定期
      policies:
      - type: Pods
        value: 1                       # 每次只减 1 个
        periodSeconds: 60              # 每 60 秒评估
      selectPolicy: Min                # 选择保守策略
```

---

## 三、部署第一个 HPA

### 3.1 创建 HPA 配置

创建文件 `k8s/v0.3/api/hpa.yaml`（内容见上面的完整示例）。

### 3.2 应用 HPA

```bash
# 应用 HPA 配置
kubectl apply -f k8s/v0.3/api/hpa.yaml

# 输出：
# horizontalpodautoscaler.autoscaling/cloudnative-api-hpa created
```

### 3.3 验证 HPA 状态

**Step 1: 查看 HPA 列表**

```bash
kubectl get hpa
```

**预期输出**：
```
NAME                   REFERENCE                     TARGETS           MINPODS   MAXPODS   REPLICAS   AGE
cloudnative-api-hpa    Deployment/cloudnative-api    <unknown>/70%, <unknown>/80%   2         10        2          10s
```

**等待 15-30 秒后再查看**：

```bash
kubectl get hpa cloudnative-api-hpa
```

**预期输出**：
```
NAME                   REFERENCE                     TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
cloudnative-api-hpa    Deployment/cloudnative-api    5%/70%, 15%/80%   2         10        2          45s
```

✅ TARGETS 显示实际值了！

**TARGETS 字段解读**：
```
5%/70%, 15%/80%
│  │    │  │
│  │    │  └─ 目标内存利用率: 80%
│  │    └──── 目标 CPU 利用率: 70%
│  └───────── 当前内存利用率: 15%
└──────────── 当前 CPU 利用率: 5%
```

**Step 2: 查看详细信息**

```bash
kubectl describe hpa cloudnative-api-hpa
```

**输出示例**：
```
Name:                                                  cloudnative-api-hpa
Namespace:                                             default
Labels:                                                app=cloudnative-api
                                                       version=v0.3
Annotations:                                           <none>
CreationTimestamp:                                     Sun, 02 Nov 2025 16:30:00 +0800
Reference:                                             Deployment/cloudnative-api
Metrics:                                               ( current / target )
  resource cpu on pods  (as a percentage of request):  5% (5m) / 70%
  resource memory on pods  (as a percentage of request):  15% (19456Ki) / 80%
Min replicas:                                          2
Max replicas:                                          10
Deployment pods:                                       2 current / 2 desired
Conditions:
  Type            Status  Reason              Message
  ----            ------  ------              -------
  AbleToScale     True    ReadyForNewScale    recommended size matches current size
  ScalingActive   True    ValidMetricFound    the HPA was able to successfully calculate a replica count from cpu resource utilization (percentage of request)
  ScalingLimited  False   DesiredWithinRange  the desired count is within the acceptable range
Events:           <none>
```

**关键字段解释**：
- **Metrics**: 当前值 / 目标值
- **AbleToScale**: 是否可以扩缩容
- **ScalingActive**: 指标是否有效
- **Events**: 扩缩容事件（初始时为空）

### 3.4 我踩的坑：TARGETS 显示 unknown

**问题现象**：

```bash
$ kubectl get hpa
NAME                   TARGETS           REPLICAS
cloudnative-api-hpa    <unknown>/70%     2
```

**可能原因**：

**原因 1: Metrics Server 未安装或未就绪**

```bash
# 检查 Metrics Server
kubectl get deployment metrics-server -n kube-system

# 如果不存在或不就绪，重新安装
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# 本地环境需要打补丁
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  }
]'
```

**原因 2: Pod 未设置 resources.requests**

```bash
# 检查 Pod 配置
kubectl get pod -l app=cloudnative-api -o yaml | grep -A 5 "resources:"

# 确保有 requests 配置：
# resources:
#   requests:
#     cpu: 100m
#     memory: 128Mi
```

**原因 3: 指标还没收集（刚启动）**

```bash
# 等待 30-60 秒让 Metrics Server 收集数据
sleep 30
kubectl get hpa cloudnative-api-hpa
```

**原因 4: Pod 未就绪**

```bash
# 检查 Pod 状态
kubectl get pods -l app=cloudnative-api

# 确保所有 Pod 都是 Running 且 READY 是 1/1
```

---

## 四、观察自动扩容

### 4.1 准备监控窗口

**强烈建议打开 4 个终端窗口同时监控**：

**终端 1 - HPA 实时监控**：
```bash
kubectl get hpa cloudnative-api-hpa -w
```

**终端 2 - Pod 实时监控**：
```bash
kubectl get pods -l app=cloudnative-api -w
```

**终端 3 - 资源使用监控**（PowerShell）：
```powershell
while ($true) {
    Clear-Host
    Write-Host "=== $(Get-Date -Format 'HH:mm:ss') ===" -ForegroundColor Cyan
    kubectl top pods -l app=cloudnative-api
    Start-Sleep -Seconds 5
}
```

**终端 4 - 执行命令**：
```bash
# 用于发送负载请求
```

### 4.2 触发扩容

**方式 1: 循环发送 CPU 负载**（PowerShell）：

```powershell
# 获取 Service URL（Minikube）
$serviceUrl = minikube service cloudnative-api-service --url

# 循环发送 50 个请求
for ($i = 1; $i -le 50; $i++) {
    Write-Host "Request $i" -ForegroundColor Yellow
    Invoke-WebRequest -Uri "$serviceUrl/api/v1/workload/cpu?iterations=30000000" -TimeoutSec 30 | Out-Null
    Start-Sleep -Milliseconds 100
}
```

**方式 2: 并发发送请求**（Bash）：

```bash
# 并发 10 个请求
for i in {1..10}; do
  (curl -s "$SERVICE_URL/api/v1/workload/cpu?iterations=30000000" &)
done
```

### 4.3 扩容过程解析

**观察终端 1（HPA）的变化**：

```
TIME    TARGETS         REPLICAS
16:30   5%/70%, 15%/80%    2        ← 初始状态：低负载
16:31   85%/70%, 25%/80%   2        ← 负载上升：CPU 超过目标
16:31   85%/70%, 25%/80%   4        ← 扩容触发：2 → 4
16:32   65%/70%, 30%/80%   4        ← 新 Pod 分担负载
16:33   45%/70%, 20%/80%   4        ← 趋于稳定
```

**观察终端 2（Pod）的变化**：

```
NAME                               READY   STATUS              AGE
cloudnative-api-xxxxxxxxx-aaa      1/1     Running             10m    ← 原有
cloudnative-api-xxxxxxxxx-bbb      1/1     Running             10m    ← 原有
cloudnative-api-xxxxxxxxx-ccc      0/1     Pending             1s     ← 新建（等待调度）
cloudnative-api-xxxxxxxxx-ddd      0/1     Pending             1s     ← 新建（等待调度）
cloudnative-api-xxxxxxxxx-ccc      0/1     ContainerCreating   5s     ← 创建容器
cloudnative-api-xxxxxxxxx-ddd      0/1     ContainerCreating   5s
cloudnative-api-xxxxxxxxx-ccc      1/1     Running             15s    ← 就绪
cloudnative-api-xxxxxxxxx-ddd      1/1     Running             15s    ← 就绪
```

**观察终端 3（资源）的变化**：

```
=== 16:30:00 ===
NAME                               CPU(cores)   MEMORY(bytes)
cloudnative-api-xxxxxxxxx-aaa      15m          85Mi          ← 空闲
cloudnative-api-xxxxxxxxx-bbb      18m          90Mi

=== 16:31:00 ===
NAME                               CPU(cores)   MEMORY(bytes)
cloudnative-api-xxxxxxxxx-aaa      180m         150Mi         ← 高负载！
cloudnative-api-xxxxxxxxx-bbb      175m         145Mi

=== 16:32:00 ===
NAME                               CPU(cores)   MEMORY(bytes)
cloudnative-api-xxxxxxxxx-aaa      95m          120Mi         ← 负载分散
cloudnative-api-xxxxxxxxx-bbb      90m          118Mi
cloudnative-api-xxxxxxxxx-ccc      88m          115Mi         ← 新 Pod
cloudnative-api-xxxxxxxxx-ddd      92m          120Mi         ← 新 Pod
```

### 4.4 扩容时间线

完整的扩容时间线：

```
T+0s    负载开始，CPU 从 5% 上升
T+15s   Metrics Server 采集到新指标
T+15s   HPA 检查指标，发现 CPU 85% > 70%
T+16s   HPA 计算：ceil(2 × 85% / 70%) = 3
        但由于 behavior 策略允许翻倍，决定扩到 4
T+16s   HPA 更新 Deployment.replicas = 4
T+17s   Deployment 创建 2 个新 Pod（Pending）
T+20s   调度器分配节点，Pod 状态变为 ContainerCreating
T+25s   容器启动，应用初始化
T+30s   Startup Probe 通过
T+35s   Readiness Probe 通过，Pod 变为 Running (1/1)
T+35s   Service 开始将流量分发到新 Pod
T+40s   负载均衡，CPU 从 85% 降至 65%
T+50s   系统稳定
```

**关键延迟**：
- Metrics 采集延迟：15 秒
- HPA 计算延迟：<1 秒
- Pod 启动延迟：15-20 秒
- **总延迟：30-40 秒**

---

## 五、观察自动缩容

### 5.1 停止负载

```bash
# 按 Ctrl+C 停止发送请求

# 或者等待所有请求完成
```

### 5.2 缩容过程解析

**观察 HPA 的变化**：

```
TIME    TARGETS         REPLICAS
16:35   45%/70%, 20%/80%   4        ← 负载停止
16:36   15%/70%, 18%/80%   4        ← CPU 降低
16:37   10%/70%, 16%/80%   4        ← 仍然 4 个
16:38   8%/70%, 15%/80%    4        ← 稳定窗口中...
16:39   5%/70%, 15%/80%    4        ← 稳定窗口中...
...     (等待 5 分钟)
16:40   5%/70%, 15%/80%    4        ← 稳定窗口中...
16:41   5%/70%, 15%/80%    3        ← 缩容：4 → 3
16:42   6%/70%, 16%/80%    3        ← 观察中
16:43   5%/70%, 15%/80%    2        ← 缩容：3 → 2
16:44   5%/70%, 15%/80%    2        ← 回到最小值
```

**观察 Pod 的变化**：

```
=== 16:41:00 ===
cloudnative-api-xxxxxxxxx-aaa      1/1     Running       10m
cloudnative-api-xxxxxxxxx-bbb      1/1     Running       10m
cloudnative-api-xxxxxxxxx-ccc      1/1     Running       5m
cloudnative-api-xxxxxxxxx-ddd      1/1     Terminating   5m    ← 被终止

=== 16:43:00 ===
cloudnative-api-xxxxxxxxx-aaa      1/1     Running       10m
cloudnative-api-xxxxxxxxx-bbb      1/1     Running       10m
cloudnative-api-xxxxxxxxx-ccc      1/1     Terminating   5m    ← 又一个被终止

=== 16:44:00 ===
cloudnative-api-xxxxxxxxx-aaa      1/1     Running       10m   ← 保留
cloudnative-api-xxxxxxxxx-bbb      1/1     Running       10m   ← 保留
```

### 5.3 为什么缩容这么慢？

**缩容比扩容慢得多！为什么？**

**原因 1: 稳定窗口（Stabilization Window）**

```yaml
behavior:
  scaleDown:
    stabilizationWindowSeconds: 300  # 5 分钟
```

- HPA 会观察过去 5 分钟内的最高指标值
- 只有持续 5 分钟低于目标，才会缩容
- **防止频繁抖动**

**原因 2: 保守的缩容策略**

```yaml
policies:
- type: Pods
  value: 1              # 每次只减 1 个
  periodSeconds: 60     # 每 60 秒
```

- 每分钟最多缩减 1 个 Pod
- 从 4 → 2 需要 2 分钟（还要加上稳定窗口）

**为什么要这样设计？**

```
场景 1：快速扩容
- 流量突增 → 服务卡顿 → 用户流失
- 影响：严重！
- 策略：立即扩容（0 秒稳定窗口）

场景 2：快速缩容
- 流量短暂下降 → 立即缩容 → 流量再次上升 → 又要扩容
- 影响：频繁抖动，浪费资源
- 策略：缓慢缩容（5 分钟稳定窗口）
```

**设计原则**：
> **宁可多保留一会儿 Pod（多花点钱）**  
> **也不能让服务卡顿（影响用户体验）**

---

## 六、HPA 行为策略详解

### 6.1 ScaleUp 策略

**策略 1：百分比策略**

```yaml
scaleUp:
  policies:
  - type: Percent
    value: 50          # 增加 50%
    periodSeconds: 60
```

**举例**：
```
当前: 4 个 Pod
策略: 50% 每 60 秒
计算: 4 × 50% = 2
结果: 每分钟最多增加 2 个 Pod
```

**策略 2：绝对数量策略**

```yaml
scaleUp:
  policies:
  - type: Pods
    value: 3           # 增加 3 个
    periodSeconds: 60
```

**举例**：
```
当前: 2 个 Pod
策略: +3 每 60 秒
结果: 每分钟最多增加 3 个 Pod
```

**策略 3：组合策略**

```yaml
scaleUp:
  policies:
  - type: Percent
    value: 100         # 翻倍
    periodSeconds: 15
  - type: Pods
    value: 4           # 或者 +4
    periodSeconds: 15
  selectPolicy: Max    # 选择更激进的
```

**举例**：
```
当前: 3 个 Pod
策略 1（翻倍）: 3 × 100% = 3 → 总共 6 个
策略 2（+4）: 3 + 4 = 7 个
selectPolicy: Max → 选择 7 个
```

### 6.2 ScaleDown 策略

**保守策略（推荐）**：

```yaml
scaleDown:
  stabilizationWindowSeconds: 300  # 5 分钟
  policies:
  - type: Pods
    value: 1                       # 每次 -1
    periodSeconds: 60              # 每分钟
  selectPolicy: Min                # 保守
```

**激进策略（不推荐）**：

```yaml
scaleDown:
  stabilizationWindowSeconds: 60   # 仅 1 分钟
  policies:
  - type: Percent
    value: 50                      # 减半
    periodSeconds: 30
  selectPolicy: Max                # 激进
```

**为什么不推荐激进缩容？**
- 容易导致频繁抖动
- 用户体验差（响应时间忽快忽慢）
- 反而浪费资源（不断创建/删除 Pod）

### 6.3 稳定窗口的作用

**没有稳定窗口的问题**：

```
16:00  流量高 → CPU 80% → 扩到 6 个
16:02  流量降 → CPU 40% → 缩到 3 个
16:04  流量高 → CPU 80% → 扩到 6 个
16:06  流量降 → CPU 40% → 缩到 3 个
...    不断抖动！
```

**有稳定窗口（5 分钟）**：

```
16:00  流量高 → CPU 80% → 扩到 6 个
16:02  流量降 → CPU 40% → 开始观察
16:03  流量高 → CPU 70% → 取消缩容
16:05  流量降 → CPU 40% → 开始观察
16:10  持续低负载 5 分钟 → 缩到 3 个
```

**稳定窗口算法**：

```
HPA 在决定缩容时，会查看过去 N 秒的历史指标
取其中的最大值进行计算

例如：稳定窗口 = 300 秒
16:10 时的指标历史：
- 16:05: 40%
- 16:06: 50%  ← 最大值
- 16:07: 45%
- 16:08: 42%
- 16:09: 40%
- 16:10: 38%

计算时使用: 50%（最大值）
只有当 50% < 70% 且持续 5 分钟，才缩容
```

### 6.4 策略组合示例

**场景 1：电商秒杀（快速扩容，慢速缩容）**

```yaml
behavior:
  scaleUp:
    stabilizationWindowSeconds: 0
    policies:
    - type: Percent
      value: 200             # 可以 3 倍扩容
      periodSeconds: 15
    - type: Pods
      value: 10              # 或者直接 +10
      periodSeconds: 15
    selectPolicy: Max
  
  scaleDown:
    stabilizationWindowSeconds: 600  # 10 分钟
    policies:
    - type: Pods
      value: 1
      periodSeconds: 120     # 每 2 分钟 -1
    selectPolicy: Min
```

**场景 2：夜间定时任务（允许快速缩容）**

```yaml
behavior:
  scaleUp:
    stabilizationWindowSeconds: 30
    policies:
    - type: Pods
      value: 5
      periodSeconds: 60
  
  scaleDown:
    stabilizationWindowSeconds: 60   # 仅 1 分钟
    policies:
    - type: Percent
      value: 50              # 可以快速减半
      periodSeconds: 30
```

---

## 七、多指标 HPA 配置

### 7.1 CPU + 内存双指标

```yaml
metrics:
# CPU 指标
- type: Resource
  resource:
    name: cpu
    target:
      type: Utilization
      averageUtilization: 70

# 内存指标
- type: Resource
  resource:
    name: memory
    target:
      type: Utilization
      averageUtilization: 80
```

### 7.2 多指标计算逻辑

**HPA 会为每个指标单独计算期望副本数，然后取最大值。**

**示例**：

```
当前副本数: 2

指标 1 - CPU:
- 当前: 50%
- 目标: 70%
- 计算: ceil(2 × 50% / 70%) = 2

指标 2 - 内存:
- 当前: 85%
- 目标: 80%
- 计算: ceil(2 × 85% / 80%) = 3

最终结果: max(2, 3) = 3 个副本
```

**逻辑**：
```
期望副本数 = MAX(
  根据 CPU 计算的副本数,
  根据内存计算的副本数,
  ...其他指标
)
```

**为什么取最大值？**
- 确保所有指标都满足
- 避免某个指标超限

### 7.3 指标优先级

**问题：CPU 和内存哪个更重要？**

```yaml
# ❌ 错误：只配置 CPU
metrics:
- type: Resource
  resource:
    name: cpu
    target:
      averageUtilization: 70

# 问题：内存可能达到 100%，导致 OOMKilled
```

```yaml
# ✅ 正确：同时配置 CPU 和内存
metrics:
- type: Resource
  resource:
    name: cpu
    target:
      averageUtilization: 70
- type: Resource
  resource:
    name: memory
    target:
      averageUtilization: 80

# 任何一个超标都会触发扩容
```

**建议**：
- **始终配置 CPU 和内存双指标**
- CPU 阈值：60-70%
- 内存阈值：70-80%（留更多 buffer）

---

## 八、HPA 调优技巧

### 8.1 如何让 HPA 更敏感？

**降低目标利用率**：

```yaml
# 更敏感（容易触发扩容）
metrics:
- type: Resource
  resource:
    name: cpu
    target:
      averageUtilization: 50  # 降低到 50%
```

**效果**：
- CPU 超过 50% 就扩容
- 更早响应负载变化
- 但会增加资源成本

**降低 requests**：

```yaml
resources:
  requests:
    cpu: "50m"     # 降低 requests
  limits:
    cpu: "500m"    # limits 不变
```

**效果**：
- 利用率 = 实际使用 / requests
- requests 越小，利用率越容易超标
- 更容易触发 HPA

### 8.2 如何避免频繁抖动？

**增加稳定窗口**：

```yaml
behavior:
  scaleDown:
    stabilizationWindowSeconds: 600  # 增加到 10 分钟
```

**增加缩容间隔**：

```yaml
behavior:
  scaleDown:
    policies:
    - type: Pods
      value: 1
      periodSeconds: 120  # 增加到 2 分钟
```

**增加 minReplicas**：

```yaml
spec:
  minReplicas: 3  # 提高最小值
  maxReplicas: 10
```

**效果**：
- 保持更多 Pod，减少缩容次数
- 更好的抗冲击能力

### 8.3 如何快速扩容、缓慢缩容？

**这是最佳实践！**

```yaml
behavior:
  scaleUp:
    stabilizationWindowSeconds: 0     # 立即扩容
    policies:
    - type: Percent
      value: 100
      periodSeconds: 15                # 快速翻倍
    selectPolicy: Max
  
  scaleDown:
    stabilizationWindowSeconds: 300   # 5 分钟观察
    policies:
    - type: Pods
      value: 1
      periodSeconds: 60                # 缓慢缩容
    selectPolicy: Min
```

**原理**：
- 扩容影响用户体验 → 必须快
- 缩容只影响成本 → 可以慢

### 8.4 如何设置合理的阈值？

**经验值表**：

| 应用类型 | CPU 阈值 | 内存阈值 | 原因 |
|---------|---------|---------|------|
| **API 服务** | 60-70% | 70-80% | 平衡性能和成本 |
| **计算密集型** | 70-80% | 60-70% | CPU 是瓶颈 |
| **内存密集型** | 50-60% | 70-80% | 内存是瓶颈，要留 buffer |
| **关键业务** | 50-60% | 60-70% | 性能优先 |
| **非关键业务** | 70-80% | 80-90% | 成本优先 |

**测试方法**：

1. 先设置保守值（50%/60%）
2. 压测观察
3. 逐步提高阈值
4. 找到性能和成本的平衡点

---

## 九、常见问题排查

### 9.1 HPA 不工作

**现象**：负载很高，但 HPA 不扩容

**排查步骤**：

```bash
# 1. 检查 HPA 状态
kubectl describe hpa cloudnative-api-hpa

# 查看 Conditions 部分：
# - AbleToScale: 是否可以扩缩容
# - ScalingActive: 指标是否有效
# - ScalingLimited: 是否达到上限
```

**常见原因**：

**原因 1：已达到 maxReplicas**

```
ScalingLimited  True  TooManyReplicas  the desired replica count is more than the maximum replica count
```

**解决**：增加 maxReplicas

**原因 2：Pod 无 resources.requests**

```
ScalingActive  False  FailedGetResourceMetric  missing request for cpu
```

**解决**：在 Deployment 中添加 resources.requests

**原因 3：Metrics Server 问题**

```
ScalingActive  False  FailedGetResourceMetric  unable to get metrics for resource cpu
```

**解决**：检查并修复 Metrics Server

### 9.2 HPA 显示 unknown

见本文 [3.4 我踩的坑：TARGETS 显示 unknown](#34-我踩的坑targets-显示-unknown)

### 9.3 HPA 扩容太慢

**原因分析**：

1. Metrics 采集延迟（15 秒）
2. HPA 检查间隔（15 秒）
3. Pod 启动时间（10-30 秒）

**优化方案**：

**方案 1：降低阈值**

```yaml
metrics:
- type: Resource
  resource:
    name: cpu
    target:
      averageUtilization: 50  # 降低阈值
```

**方案 2：激进的扩容策略**

```yaml
behavior:
  scaleUp:
    stabilizationWindowSeconds: 0
    policies:
    - type: Percent
      value: 200     # 可以 3 倍扩容
      periodSeconds: 15
```

**方案 3：提高 minReplicas**

```yaml
spec:
  minReplicas: 5   # 保持更多 Pod
```

### 9.4 HPA 频繁抖动

**现象**：副本数不断变化（2 → 4 → 2 → 4）

**原因**：
- 稳定窗口太短
- 缩容策略太激进
- 阈值设置不合理

**解决方案**：

```yaml
behavior:
  scaleDown:
    stabilizationWindowSeconds: 600  # 增加到 10 分钟
    policies:
    - type: Pods
      value: 1
      periodSeconds: 120  # 每 2 分钟 -1
```

### 9.5 Pod 被 OOMKilled

**现象**：扩容过程中，Pod 突然被杀

```bash
kubectl describe pod cloudnative-api-xxx
# 查看 Events：
# OOMKilled  Container cloudnative-api was killed due to OOM
```

**原因**：内存 limits 太小

**解决**：

```yaml
resources:
  requests:
    memory: "128Mi"
  limits:
    memory: "512Mi"  # 提高 limits（原来 256Mi）
```

---

## 结语

这篇文章中，我深入学习了 HPA 的配置和实战：

### ✅ 我学到了什么

1. **HPA 核心原理**
   - 计算公式：期望副本数 = 当前副本数 × (当前指标 / 目标指标)
   - 多指标取最大值
   - 每 15 秒检查一次

2. **HPA 配置详解**
   - scaleTargetRef：控制目标
   - metrics：扩缩容指标（CPU、内存）
   - behavior：扩缩容策略
   - minReplicas/maxReplicas：范围控制

3. **Behavior 策略**
   - scaleUp：快速响应（0 秒稳定窗口）
   - scaleDown：保守缩容（300 秒稳定窗口）
   - 稳定窗口防止抖动

4. **扩缩容过程**
   - 扩容：30-40 秒
   - 缩容：5+ 分钟
   - 扩容快、缩容慢是最佳实践

5. **调优技巧**
   - 降低阈值 → 更敏感
   - 增加稳定窗口 → 避免抖动
   - CPU 60-70%, 内存 70-80%
   - 始终配置双指标

6. **常见问题**
   - unknown → Metrics Server 或 requests 问题
   - 不扩容 → 达到上限或指标无效
   - 频繁抖动 → 缩容策略太激进

### 🎯 实战成果

- ✅ 成功配置 HPA
- ✅ 观察到自动扩容（2 → 4）
- ✅ 观察到自动缩容（4 → 2）
- ✅ 理解并优化 behavior 策略
- ✅ 掌握问题排查方法

### 🚀 下一步

**下一篇文章**，我会：
- ✅ 使用 k6 进行专业的压测
- ✅ 验证 HPA 在真实负载下的表现
- ✅ 分析性能指标和扩缩容效果
- ✅ 给出完整的性能报告

**敬请期待《压测实战：验证弹性伸缩效果》！**

---

**相关文章**：
- 上一篇：[云原生的核心优势：自动弹性伸缩实战](./09-cloud-native-autoscaling-practice.md)
- 下一篇：[压测实战：验证弹性伸缩效果](./11-load-testing-hpa-validation.md)

**项目代码**：[GitHub - cloudnative-go-journey](https://github.com/yourusername/cloudnative-go-journey)

