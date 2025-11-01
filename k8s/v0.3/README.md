# Kubernetes 配置文件 - v0.3（弹性伸缩版）

## 📋 目录结构

```
k8s/v0.3/
├── api/
│   ├── deployment.yaml    # 应用部署配置
│   ├── service.yaml       # 服务暴露配置
│   └── hpa.yaml           # HPA 自动扩缩容配置
└── README.md              # 本文件
```

---

## 🎯 v0.3 核心特性

### 1. **Horizontal Pod Autoscaler (HPA)**
- **目标**: 根据 CPU/内存使用率自动调整 Pod 副本数
- **指标**: 
  - CPU 利用率 > 70% 时扩容
  - 内存利用率 > 80% 时扩容
- **副本数范围**: 2-10 个 Pod
- **扩缩容策略**: 
  - 快速扩容（0 秒稳定窗口，每 15 秒最多翻倍）
  - 保守缩容（5 分钟稳定窗口，每分钟最多减少 1 个 Pod）

### 2. **优化的资源配置**
- **Requests**: CPU 100m, Memory 128Mi
- **Limits**: CPU 300m, Memory 256Mi
- **突发比**: CPU 3x, Memory 2x

### 3. **工作负载测试接口**
- `/api/v1/workload/cpu` - CPU 密集型负载
- `/api/v1/workload/memory` - 内存密集型负载
- `/api/v1/workload?type=mixed` - 混合负载

---

## 🚀 快速部署

### 前置条件

1. **安装 Metrics Server**（HPA 必需）

```powershell
# 安装
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# 本地环境需要打补丁
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  }
]'

# 等待就绪
kubectl wait --for=condition=available --timeout=60s deployment/metrics-server -n kube-system

# 验证
kubectl top nodes
```

2. **构建镜像**

```powershell
docker build -t cloudnative-api:v0.3 -f Dockerfile .
```

### 一键部署

```powershell
# 使用自动化脚本
.\scripts\deploy-v0.3.ps1

# 或者手动部署
kubectl apply -f k8s/v0.3/api/deployment.yaml
kubectl apply -f k8s/v0.3/api/service.yaml
kubectl apply -f k8s/v0.3/api/hpa.yaml
```

---

## 📊 监控和验证

### 查看 HPA 状态

```powershell
# 实时监控 HPA
kubectl get hpa cloudnative-api-hpa -w

# 详细信息
kubectl describe hpa cloudnative-api-hpa
```

**示例输出**:
```
NAME                   REFERENCE                     TARGETS         MINPODS   MAXPODS   REPLICAS
cloudnative-api-hpa    Deployment/cloudnative-api    45%/70%, 30%/80%   2         10        3
```

字段说明:
- **TARGETS**: `当前值/目标值` (CPU%, Memory%)
- **REPLICAS**: 当前副本数
- **MINPODS/MAXPODS**: 副本数范围

### 查看 Pod 状态

```powershell
# 实时监控 Pods
kubectl get pods -l app=cloudnative-api -w

# 查看资源使用
kubectl top pods -l app=cloudnative-api
```

**示例输出**:
```
NAME                                CPU(cores)   MEMORY(bytes)
cloudnative-api-7f8d6f9b45-2xqzk    85m          120Mi
cloudnative-api-7f8d6f9b45-8hjkl    92m          115Mi
```

### 查看扩缩容事件

```powershell
# 查看 HPA 事件
kubectl describe hpa cloudnative-api-hpa | Select-String -Pattern "Events:" -Context 0,20

# 查看所有事件
kubectl get events --sort-by='.lastTimestamp' | Select-String "cloudnative-api"
```

---

## 🧪 压力测试

### 方式 1: 使用 k6（推荐）

```powershell
# 运行 HPA 专用压测脚本
k6 run k6-tests/hpa-test.js

# 自定义目标地址
$env:BASE_URL="http://localhost:30080"; k6 run k6-tests/hpa-test.js
```

**测试阶段**:
1. 预热（30 秒，5 用户）
2. 缓慢增压（1 分钟，20 用户）
3. 激增负载（2 分钟，100 用户）- **触发扩容**
4. 保持高负载（3 分钟，100 用户）- **观察扩容**
5. 缓慢降压（2 分钟，20 用户）
6. 完全冷却（1 分钟，5 用户）- **观察缩容**

### 方式 2: 手动触发

**触发 CPU 扩容**:
```powershell
# 循环请求 CPU 密集型接口
while ($true) {
    Invoke-WebRequest -Uri "http://localhost:30080/api/v1/workload/cpu?iterations=20000000" -Method GET
    Start-Sleep -Milliseconds 100
}
```

**触发内存扩容**:
```powershell
# 循环请求内存密集型接口
while ($true) {
    Invoke-WebRequest -Uri "http://localhost:30080/api/v1/workload/memory?size=100&duration=2" -Method GET
    Start-Sleep -Seconds 1
}
```

---

## 📈 HPA 工作原理

### 计算公式

```
期望副本数 = ceil[当前副本数 × (当前指标值 / 目标指标值)]
```

**示例 1: CPU 扩容**
- 当前副本数: 2
- 当前 CPU 使用率: 140%（相对于 requests）
- 目标 CPU 使用率: 70%
- 计算: `ceil[2 × (140 / 70)] = ceil[4] = 4`
- **结果**: 扩容到 4 个副本

**示例 2: 多指标**
- CPU 指标建议: 4 个副本
- 内存指标建议: 3 个副本
- **结果**: 取最大值，扩容到 4 个副本

### 扩缩容时间线

**扩容**:
- **检测周期**: 每 15 秒检查一次指标
- **稳定窗口**: 0 秒（立即响应）
- **最快速度**: 每 15 秒翻倍（策略 1）
- **预计时间**: 30 秒内从 2 个扩容到 4 个

**缩容**:
- **检测周期**: 每 15 秒检查一次指标
- **稳定窗口**: 5 分钟（防抖动）
- **最快速度**: 每分钟减少 1 个 Pod（策略 1）
- **预计时间**: 5-10 分钟从 4 个缩容到 2 个

---

## 🔧 配置说明

### HPA 关键字段

```yaml
spec:
  minReplicas: 2              # 最小副本数
  maxReplicas: 10             # 最大副本数
  
  metrics:
  - type: Resource            # 资源指标
    resource:
      name: cpu
      target:
        type: Utilization     # 利用率类型
        averageUtilization: 70  # 目标 70%
  
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # 5 分钟稳定窗口
      policies:
      - type: Pods
        value: 1              # 每分钟最多减少 1 个
        periodSeconds: 60
```

### Deployment 资源配置

```yaml
resources:
  requests:
    cpu: "100m"        # HPA 计算基准
    memory: "128Mi"    # HPA 计算基准
  limits:
    cpu: "300m"        # 最大 CPU（3x）
    memory: "256Mi"    # 最大内存（2x）
```

**为什么要设置 requests?**
- HPA 的 CPU/内存利用率是**相对于 requests** 计算的
- 如果不设置 requests，HPA 无法工作
- 示例: `requests.cpu=100m`, 实际使用 `70m` → 利用率 70%

---

## 🐛 常见问题

### 1. HPA 显示 `<unknown>` 指标

**原因**: Metrics Server 未安装或未就绪

**解决**:
```powershell
# 检查 Metrics Server
kubectl get deployment metrics-server -n kube-system

# 查看日志
kubectl logs -n kube-system deployment/metrics-server

# 验证 Metrics API
kubectl top nodes
```

### 2. HPA 不扩容

**原因 1**: CPU/内存使用率未达到阈值
```powershell
# 查看当前使用率
kubectl top pods -l app=cloudnative-api

# 查看 HPA 详情
kubectl describe hpa cloudnative-api-hpa
```

**原因 2**: 已达到 maxReplicas
```powershell
# 检查当前副本数
kubectl get hpa cloudnative-api-hpa
```

**原因 3**: 扩容策略限制
```powershell
# 查看 HPA events
kubectl describe hpa cloudnative-api-hpa | Select-String -Pattern "Events:" -Context 0,10
```

### 3. HPA 不缩容

**原因**: 稳定窗口期（5 分钟）
- HPA 需要在 5 分钟内指标持续低于阈值才会缩容
- 这是正常的防抖机制
- 耐心等待即可

### 4. Pod 反复重启

**原因**: OOM (Out of Memory)
```powershell
# 查看 Pod 状态
kubectl get pods -l app=cloudnative-api

# 查看 Pod 事件
kubectl describe pod <pod-name> | Select-String "OOMKilled"
```

**解决**: 提高 `resources.limits.memory`

---

## 📚 相关文档

- [v0.3 部署指南](../../docs/v0.3/DEPLOYMENT-GUIDE.md)
- [v0.3 架构设计](../../docs/v0.3/ARCHITECTURE.md)
- [HPA 官方文档](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Metrics Server 文档](https://github.com/kubernetes-sigs/metrics-server)

---

## 🎓 学习提示

### 观察重点

1. **扩容触发时机**: CPU/内存达到多少时开始扩容？
2. **扩容速度**: 多久从 2 个 Pod 扩到 4 个？
3. **缩容延迟**: 负载降低后多久开始缩容？
4. **稳定状态**: 在中等负载下稳定在多少个副本？

### 实验建议

1. **调整阈值**: 修改 `averageUtilization` 观察效果
2. **调整策略**: 修改 `behavior` 中的策略参数
3. **调整资源**: 修改 `resources` 中的 requests/limits
4. **对比测试**: 关闭 HPA，对比手动扩容的差异

---

**祝你实验顺利！** 🚀

