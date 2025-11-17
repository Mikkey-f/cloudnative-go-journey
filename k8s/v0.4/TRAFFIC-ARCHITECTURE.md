# v0.4 流量分配架构

> 详细说明 K8s Service 和 Istio VirtualService 的协作机制

## 📊 架构设计

### 核心原则

**对称副本 + Istio 权重控制**

```
API v1 Deployment: 5 副本 ─┐
                           ├─→ api Service (50% 初始分配)
API v2 Deployment: 5 副本 ─┘
                           ↓
                    Istio VirtualService
                           ├─ 90% → v1 subset
                           └─ 10% → v2 subset
                           ↓
                    最终流量分配: 90% v1, 10% v2
```

## 🔄 流量分配流程

### 第一层：K8s Service 负载均衡

```
10 个请求到达
    ↓
K8s Service 选择器: app=api
    ├─ 匹配 5 个 v1 Pod
    └─ 匹配 5 个 v2 Pod
    ↓
轮询分配（Round Robin）
    ├─ Pod 1 (v1):   1 个请求
    ├─ Pod 2 (v1):   1 个请求
    ├─ Pod 3 (v1):   1 个请求
    ├─ Pod 4 (v1):   1 个请求
    ├─ Pod 5 (v1):   1 个请求
    ├─ Pod 6 (v2):   1 个请求
    ├─ Pod 7 (v2):   1 个请求
    ├─ Pod 8 (v2):   1 个请求
    ├─ Pod 9 (v2):   1 个请求
    └─ Pod 10 (v2):  1 个请求
    ↓
结果: 50% v1, 50% v2
```

### 第二层：Istio VirtualService 权重分配

```
10 个请求（已分配到 Pod）
    ↓
Envoy Sidecar 拦截
    ↓
VirtualService 规则应用
    ├─ 90% 权重 → v1 subset
    │  └─ 选择标签 version=v1 的 Pod
    │     (Pod 1-5)
    │
    └─ 10% 权重 → v2 subset
       └─ 选择标签 version=v2 的 Pod
          (Pod 6-10)
    ↓
权重分配
    ├─ 9 个请求 → v1 Pod
    └─ 1 个请求 → v2 Pod
    ↓
最终结果: 90% v1, 10% v2
```

## 📈 流量分配对比

### 方案对比

| 方案 | v1 副本 | v2 副本 | Service 分配 | VirtualService | 最终结果 | 优点 | 缺点 |
|------|--------|--------|------------|----------------|--------|------|------|
| **当前方案** | 5 | 5 | 50% v1, 50% v2 | 90% v1, 10% v2 | ✅ 90% v1, 10% v2 | 清晰、可靠 | 需要两层配置 |
| 旧方案 | 9 | 1 | 90% v1, 10% v2 | 90% v1, 10% v2 | ✅ 90% v1, 10% v2 | 副本数体现比例 | 不对称、难扩展 |
| 仅 Service | 9 | 1 | 90% v1, 10% v2 | 无 | ✅ 90% v1, 10% v2 | 简单 | 无 Istio 功能 |
| 仅 Istio | 5 | 5 | 50% v1, 50% v2 | 90% v1, 10% v2 | ✅ 90% v1, 10% v2 | Istio 完全控制 | Istio 故障时均衡 |

## 🎯 当前方案的优势

### 1. 清晰的流量控制

```
VirtualService 中明确定义:
  - v1: 90% 权重
  - v2: 10% 权重

调整流量比例只需修改 VirtualService:
  kubectl edit virtualservice api-vs
```

### 2. 对称的副本设计

```
两个版本副本数相同:
  - api-v1: 5 副本
  - api-v2: 5 副本

优点:
  ✅ 易于理解和维护
  ✅ 便于后续扩展（如改为 50/50）
  ✅ 资源分配公平
```

### 3. 双重保障

```
即使 Istio 故障:
  - Service 仍能保证 50% 的初始分配
  - 不会导致 100% 流量到 v1

即使 Service 故障:
  - Istio VirtualService 仍能控制流量
```

### 4. 完整的 Istio 功能

```
VirtualService 配置:
  ✅ 超时控制: 5s
  ✅ 重试策略: 最多 3 次
  ✅ 权重分配: 90/10

DestinationRule 配置:
  ✅ 连接池限制
  ✅ 熔断检测
  ✅ 异常隔离
```

## 🔍 验证流量分配

### 方式 1: 查看 Pod 分布

```bash
# 查看所有 Pod
kubectl get pods -l app=api -o wide

# 输出示例:
# NAME                    READY   STATUS    RESTARTS   AGE
# api-v1-xxxxx            1/1     Running   0          5m
# api-v1-yyyyy            1/1     Running   0          5m
# api-v1-zzzzz            1/1     Running   0          5m
# api-v1-aaaaa            1/1     Running   0          5m
# api-v1-bbbbb            1/1     Running   0          5m
# api-v2-ccccc            1/1     Running   0          5m
# api-v2-ddddd            1/1     Running   0          5m
# api-v2-eeeee            1/1     Running   0          5m
# api-v2-fffff            1/1     Running   0          5m
# api-v2-ggggg            1/1     Running   0          5m
```

### 方式 2: 测试 API 版本端点

```bash
# 运行 100 次请求，统计版本分布
for i in {1..100}; do
  curl -s http://app.local/api/v1/version | jq '.version'
done | sort | uniq -c

# 期望输出:
#  90 "v1"
#  10 "v2"
```

### 方式 3: 查看 VirtualService 配置

```bash
# 查看 VirtualService
kubectl get virtualservice api-vs -o yaml

# 验证权重配置
kubectl get virtualservice api-vs -o jsonpath='{.spec.http[0].route[*].weight}'
# 输出: 90 10
```

### 方式 4: 查看 DestinationRule 子集

```bash
# 查看 DestinationRule
kubectl get destinationrule api-dr -o yaml

# 验证子集定义
kubectl get destinationrule api-dr -o jsonpath='{.spec.subsets[*].name}'
# 输出: v1 v2
```

## 📝 配置文件关键点

### deployment-v1.yaml

```yaml
spec:
  replicas: 5  # 对称副本数
  selector:
    matchLabels:
      app: api
      version: v1  # 关键：用于 DestinationRule 子集匹配
  template:
    metadata:
      labels:
        app: api
        version: v1  # 必须与 selector 一致
    spec:
      containers:
      - env:
        - name: API_VERSION
          value: "v1"  # 用于应用层识别版本
```

### deployment-v2.yaml

```yaml
spec:
  replicas: 5  # 对称副本数
  selector:
    matchLabels:
      app: api
      version: v2  # 关键：用于 DestinationRule 子集匹配
  template:
    metadata:
      labels:
        app: api
        version: v2  # 必须与 selector 一致
    spec:
      containers:
      - env:
        - name: API_VERSION
          value: "v2"  # 用于应用层识别版本
```

### virtual-service.yaml

```yaml
spec:
  hosts:
  - api-service  # 作用于 api Service
  http:
  - route:
    - destination:
        host: api-service
        subset: v1  # 对应 DestinationRule 中的子集名称
      weight: 90
    - destination:
        host: api-service
        subset: v2  # 对应 DestinationRule 中的子集名称
      weight: 10
```

### destination-rule.yaml

```yaml
spec:
  host: api-service  # 作用于 api Service
  subsets:
  - name: v1  # 子集名称，对应 VirtualService 中的 subset
    labels:
      version: v1  # 匹配 Pod 标签
  - name: v2  # 子集名称，对应 VirtualService 中的 subset
    labels:
      version: v2  # 匹配 Pod 标签
```

## 🚀 调整流量比例

### 场景 1: 改为 50/50

```bash
# 编辑 VirtualService
kubectl edit virtualservice api-vs

# 修改权重:
# weight: 50  (v1)
# weight: 50  (v2)

# 验证
kubectl get virtualservice api-vs -o jsonpath='{.spec.http[0].route[*].weight}'
# 输出: 50 50
```

### 场景 2: 改为 100/0（全量切换）

```bash
# 编辑 VirtualService
kubectl edit virtualservice api-vs

# 修改权重:
# weight: 100  (v1)
# weight: 0    (v2)
```

### 场景 3: 改为 0/100（灰度完成）

```bash
# 编辑 VirtualService
kubectl edit virtualservice api-vs

# 修改权重:
# weight: 0    (v1)
# weight: 100  (v2)

# 然后删除 v1 Deployment
kubectl delete deployment api-v1
```

## 📚 相关文档

- [Kubernetes Service](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Istio VirtualService](https://istio.io/latest/docs/reference/config/networking/virtual-service/)
- [Istio DestinationRule](https://istio.io/latest/docs/reference/config/networking/destination-rule/)
- [Canary Deployments](https://istio.io/latest/docs/tasks/traffic-management/traffic-shifting/)

---

**总结**: 当前方案通过对称副本 + Istio 权重控制，实现了清晰、可靠、易于维护的流量分配架构。
