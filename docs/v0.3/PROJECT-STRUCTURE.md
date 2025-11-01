# v0.3 项目结构说明

> 详细的目录结构和文件说明

---

## 📂 完整目录树

```
cloudnative-go-journey-plan/
│
├── src/                           # Go 源代码
│   ├── main.go                   # 主入口（更新）
│   ├── handler/                  # HTTP 处理器
│   │   ├── health.go            # 健康检查（v0.1）
│   │   ├── hello.go             # Hello 接口（v0.1）
│   │   ├── cache.go             # 缓存接口（v0.2）
│   │   ├── data.go              # 数据接口（v0.2）
│   │   └── workload.go          # ⭐ 负载测试接口（v0.3 新增）
│   ├── middleware/              # 中间件
│   │   ├── logger.go            # 日志中间件（v0.1）
│   │   └── metrics.go           # 指标中间件（v0.1）
│   ├── metrics/                 # Prometheus 指标
│   │   └── prometheus.go        # 指标定义（v0.1）
│   ├── config/                  # 配置管理
│   │   └── config.go            # 配置加载（v0.1）
│   ├── cache/                   # 缓存模块（v0.2）
│   │   ├── interface.go         # 缓存接口
│   │   └── redis.go             # Redis 实现
│   ├── cleanup-job/             # 清理任务（v0.2）
│   │   └── main.go              # 清理任务入口
│   └── log-collector/           # 日志采集器（v0.2）
│       └── main.go              # 采集器入口
│
├── k8s/                          # Kubernetes 配置
│   ├── v0.1/                    # v0.1 配置
│   │   ├── deployment.yaml      # 基础 Deployment
│   │   ├── service.yaml         # 基础 Service
│   │   └── README.md            # 部署说明
│   │
│   ├── v0.2/                    # v0.2 配置
│   │   ├── api/                 # API 服务
│   │   │   ├── deployment.yaml  # Deployment
│   │   │   ├── service.yaml     # Service
│   │   │   └── configmap.yaml   # ConfigMap
│   │   ├── redis/               # Redis StatefulSet
│   │   │   ├── statefulset.yaml # StatefulSet
│   │   │   ├── service.yaml     # Headless Service
│   │   │   └── configmap.yaml   # Redis 配置
│   │   ├── log-collector/       # 日志采集器 DaemonSet
│   │   │   └── daemonset.yaml   # DaemonSet
│   │   ├── cleanup-job/         # 清理任务 CronJob
│   │   │   └── cronjob.yaml     # CronJob
│   │   └── README.md            # 部署说明
│   │
│   └── v0.3/                    # ⭐ v0.3 配置（新增）
│       ├── api/
│       │   ├── deployment.yaml  # ⭐ Deployment（更新资源配置）
│       │   ├── service.yaml     # Service（复用 v0.2）
│       │   ├── configmap.yaml   # ConfigMap（复用 v0.2）
│       │   └── hpa.yaml         # ⭐ HPA 配置（新增）
│       ├── redis/               # Redis（复用 v0.2）
│       └── README.md            # ⭐ 部署说明（新增）
│
├── k6-tests/                     # k6 压测脚本
│   ├── 01-simple-test.js        # 简单测试（已有）
│   ├── 02-with-checks.js        # 带检查的测试（已有）
│   ├── 03-virtual-users.js      # 虚拟用户测试（已有）
│   ├── 04-real-world-scenario.js # 真实场景测试（已有）
│   └── 05-hpa-validation.js     # ⭐ HPA 验证测试（新增）
│
├── docs/                         # 文档
│   ├── v0.1/                    # v0.1 文档
│   │   ├── README.md
│   │   ├── ARCHITECTURE.md
│   │   └── ...
│   ├── v0.2/                    # v0.2 文档
│   │   ├── README.md
│   │   ├── ARCHITECTURE.md
│   │   ├── COMPLETION-SUMMARY.md
│   │   └── ...
│   └── v0.3/                    # ⭐ v0.3 文档（新增）
│       ├── README.md            # 项目总览
│       ├── GOALS.md             # 学习目标
│       ├── ARCHITECTURE.md      # 技术架构
│       ├── PROJECT-STRUCTURE.md # 本文件
│       ├── DEPLOYMENT-GUIDE.md  # 部署指南
│       └── ASSESSMENT.md        # 知识评估
│
├── blog/                         # 博客文章
│   ├── v0.1/                    # v0.1 博客（3篇）
│   ├── v0.2/                    # v0.2 博客（5篇）
│   └── v0.3/                    # ⭐ v0.3 博客（待创建）
│       ├── 09-autoscaling-intro.md     # HPA 原理介绍
│       ├── 10-hpa-practice.md          # HPA 实战配置
│       └── 11-load-testing.md          # 压测验证实战
│
├── scripts/                      # 自动化脚本
│   ├── check-environment.sh     # 环境检查（Linux）
│   ├── check-environment.ps1    # 环境检查（Windows）
│   ├── deploy-v0.1.ps1          # v0.1 部署脚本
│   ├── deploy-v0.2.ps1          # v0.2 部署脚本
│   └── deploy-v0.3.ps1          # ⭐ v0.3 部署脚本（待创建）
│
├── Dockerfile                    # API 服务镜像构建
├── Dockerfile.log-collector      # 日志采集器镜像构建
├── Dockerfile.cleanup-job        # 清理任务镜像构建
│
├── go.mod                        # Go 模块定义
├── go.sum                        # Go 依赖锁定
│
├── README.md                     # 项目主 README
├── QUICKSTART.md                 # 快速开始指南
├── CHANGELOG.md                  # 变更日志
├── LICENSE                       # 开源协议
└── cloudnative-go-journey-plan.md # 完整项目规划
```

---

## 📝 核心文件详解

### 1. 新增的 Go 代码

#### `src/handler/workload.go` ⭐ 新增

**目的**：提供负载测试接口，用于触发 HPA 扩容

**主要函数**：
```go
// 1. 综合负载接口
func WorkloadHandler(c *gin.Context)
// 用途：可配置的 CPU/Memory/Mixed 负载
// 参数：type (cpu/memory/mixed), intensity (1-100)

// 2. CPU 密集型接口
func CPUIntensiveHandler(c *gin.Context)
// 用途：纯 CPU 计算，数学运算
// 参数：iterations (循环次数)

// 3. 内存密集型接口
func MemoryIntensiveHandler(c *gin.Context)
// 用途：大量内存分配和持有
// 参数：size (MB), duration (秒)
```

**使用场景**：
- 压测验证 HPA 扩容
- 测试资源限制
- 模拟高负载场景

---

#### `src/main.go` 🔄 更新

**新增路由**：
```go
// v0.3 工作负载测试接口
r.GET("/api/workload", handler.WorkloadHandler)
r.GET("/api/workload/cpu", handler.CPUIntensiveHandler)
r.GET("/api/workload/memory", handler.MemoryIntensiveHandler)
```

**保留的路由**（v0.1 + v0.2）：
```go
// v0.1 基础接口
r.GET("/health", handler.HealthHandler)
r.GET("/ready", handler.ReadyHandler)
r.GET("/hello", handler.HelloHandler)
r.GET("/metrics", promhttp.Handler())

// v0.2 业务接口
r.GET("/api/cache/:key", handler.GetCacheHandler)
r.POST("/api/cache", handler.SetCacheHandler)
r.DELETE("/api/cache/:key", handler.DeleteCacheHandler)
r.GET("/api/data", handler.GetDataHandler)
r.POST("/api/data", handler.CreateDataHandler)
```

---

### 2. K8s 配置文件

#### `k8s/v0.3/api/deployment.yaml` 🔄 更新

**关键变更**：
```yaml
# 1. 镜像版本更新
image: cloudnative-api:v0.3  # v0.2 → v0.3

# 2. 资源配置优化
resources:
  requests:
    memory: "128Mi"  # v0.2: 64Mi → v0.3: 128Mi
    cpu: "100m"      # 保持不变（HPA 基准）
  limits:
    memory: "256Mi"  # v0.2: 256Mi（不变）
    cpu: "300m"      # v0.2: 500m → v0.3: 300m

# 3. 标签更新
labels:
  version: v0.3    # v0.2 → v0.3
```

**原因说明**：
- 提高 memory requests：更稳定的性能
- 降低 CPU limits：更合理的突发比（3x）
- HPA 会基于 CPU requests (100m) 计算使用率

---

#### `k8s/v0.3/api/hpa.yaml` ⭐ 新增

**完整配置**：
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: cloudnative-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: cloudnative-api
  minReplicas: 2      # 最小副本数
  maxReplicas: 10     # 最大副本数
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70  # 目标使用率
  behavior:             # 扩缩行为控制
    scaleDown:          # 缩容行为
      stabilizationWindowSeconds: 300  # 5分钟稳定期
    scaleUp:            # 扩容行为
      stabilizationWindowSeconds: 0    # 立即扩容
```

**配置说明**：
- `minReplicas: 2`：保证高可用
- `maxReplicas: 10`：控制成本
- `averageUtilization: 70`：目标 70% CPU 使用率
- `behavior`：控制扩缩速度和稳定性

---

### 3. 压测脚本

#### `k6-tests/05-hpa-validation.js` ⭐ 新增

**压测策略**：
```javascript
stages: [
  { duration: '30s', target: 5 },    // 预热阶段
  { duration: '2m', target: 20 },    // 增压阶段
  { duration: '3m', target: 50 },    // 峰值阶段
  { duration: '2m', target: 20 },    // 降压阶段
  { duration: '2m', target: 0 },     // 冷却阶段
]
```

**测试目标**：
- CPU 密集型接口：`/api/workload/cpu?iterations=8000000`
- 触发 HPA 扩容
- 验证扩缩容时间
- 记录性能指标

---

### 4. 文档系统

#### `docs/v0.3/` 目录结构

```
docs/v0.3/
├── README.md              # 入口文档，项目总览
│   ├─ 版本概述
│   ├─ 学习目标
│   ├─ 文档导航
│   └─ 快速开始
│
├── GOALS.md               # 详细学习目标
│   ├─ 理论知识目标（40%）
│   ├─ 实践技能目标（50%）
│   ├─ 工具使用目标（10%）
│   └─ 交付标准
│
├── ARCHITECTURE.md        # 技术架构设计
│   ├─ 系统架构图
│   ├─ HPA 工作流程
│   ├─ 数据流详解
│   ├─ HPA 算法详解
│   └─ 组件设计
│
├── PROJECT-STRUCTURE.md   # 本文件
│   ├─ 完整目录树
│   ├─ 核心文件详解
│   ├─ 新增内容说明
│   └─ 文件职责划分
│
├── DEPLOYMENT-GUIDE.md    # 完整部署指南
│   ├─ 前置检查
│   ├─ Phase 1: 环境准备
│   ├─ Phase 2: 代码开发
│   ├─ Phase 3: K8s 配置
│   ├─ Phase 4: 压测验证
│   ├─ Phase 5: 优化调整
│   ├─ Phase 6: 文档完善
│   └─ 常见问题排查
│
└── ASSESSMENT.md          # 前置知识评估
    ├─ Part 1: Kubernetes 基础
    ├─ Part 2: 弹性伸缩理论
    ├─ Part 3: 实践操作
    ├─ Part 4: 工具使用
    └─ 综合评估和学习建议
```

---

## 🆕 v0.3 新增内容总结

### 代码层面

| 文件 | 状态 | 说明 |
|------|------|------|
| `src/handler/workload.go` | ⭐ 新增 | 负载测试接口 |
| `src/main.go` | 🔄 更新 | 注册新路由 |

### K8s 配置层面

| 文件 | 状态 | 说明 |
|------|------|------|
| `k8s/v0.3/api/deployment.yaml` | 🔄 更新 | 优化资源配置 |
| `k8s/v0.3/api/service.yaml` | ♻️ 复用 | 与 v0.2 相同 |
| `k8s/v0.3/api/configmap.yaml` | ♻️ 复用 | 与 v0.2 相同 |
| `k8s/v0.3/api/hpa.yaml` | ⭐ 新增 | HPA 配置 |
| `k8s/v0.3/README.md` | ⭐ 新增 | 部署说明 |

### 测试层面

| 文件 | 状态 | 说明 |
|------|------|------|
| `k6-tests/05-hpa-validation.js` | ⭐ 新增 | HPA 压测脚本 |

### 文档层面

| 文件 | 状态 | 说明 |
|------|------|------|
| `docs/v0.3/README.md` | ⭐ 新增 | 总览文档 |
| `docs/v0.3/GOALS.md` | ⭐ 新增 | 学习目标 |
| `docs/v0.3/ARCHITECTURE.md` | ⭐ 新增 | 技术架构 |
| `docs/v0.3/PROJECT-STRUCTURE.md` | ⭐ 新增 | 本文件 |
| `docs/v0.3/DEPLOYMENT-GUIDE.md` | ⭐ 新增 | 部署指南 |
| `docs/v0.3/ASSESSMENT.md` | ⭐ 新增 | 知识评估 |

### 脚本层面

| 文件 | 状态 | 说明 |
|------|------|------|
| `scripts/deploy-v0.3.ps1` | ⭐ 待创建 | 一键部署脚本 |

---

## 📊 文件职责划分

### 配置类文件

```
Deployment  → Pod 定义、资源配置、健康检查
Service     → 服务暴露、端口映射
ConfigMap   → 应用配置、环境变量
HPA         → 自动扩缩策略
```

### 代码类文件

```
main.go         → 应用入口、路由注册
handler/*.go    → HTTP 处理器、业务逻辑
middleware/*.go → 中间件（日志、指标）
metrics/*.go    → Prometheus 指标定义
cache/*.go      → 缓存层抽象和实现
config/*.go     → 配置加载和管理
```

### 文档类文件

```
README.md            → 快速了解，导航
GOALS.md             → 明确目标
ARCHITECTURE.md      → 理解设计
PROJECT-STRUCTURE.md → 熟悉结构
DEPLOYMENT-GUIDE.md  → 具体操作
ASSESSMENT.md        → 自我评估
```

---

## 🔗 文件关联关系

### 依赖关系

```
HPA → Deployment
  └→ Metrics Server → kubelet → Pod

Deployment → ConfigMap (可选)
          → Service (关联)

Service → Pod (通过 selector)

压测脚本 → Service → Pod
```

### 开发流程

```
1. 编写代码: src/handler/workload.go
2. 更新路由: src/main.go
3. 构建镜像: Dockerfile
4. 创建配置: k8s/v0.3/api/*.yaml
5. 部署应用: kubectl apply
6. 压测验证: k6-tests/05-hpa-validation.js
7. 观察结果: kubectl get hpa -w
```

---

## 💡 使用建议

### 阅读顺序

1. **开始前**: `ASSESSMENT.md` → 评估知识水平
2. **了解概况**: `README.md` → 项目总览
3. **明确目标**: `GOALS.md` → 学习目标
4. **理解设计**: `ARCHITECTURE.md` → 技术架构
5. **熟悉结构**: `PROJECT-STRUCTURE.md` → 本文件
6. **开始实践**: `DEPLOYMENT-GUIDE.md` → 逐步部署

### 文件查找

**找配置**：
```
kubectl apply -f k8s/v0.3/api/hpa.yaml     # HPA 配置
kubectl apply -f k8s/v0.3/api/deployment.yaml  # Deployment 配置
```

**找代码**：
```
src/handler/workload.go  # 负载测试接口
src/main.go              # 路由注册
```

**找文档**：
```
docs/v0.3/README.md              # 从这里开始
docs/v0.3/DEPLOYMENT-GUIDE.md    # 部署步骤
```

**找脚本**：
```
scripts/deploy-v0.3.ps1          # 一键部署
k6-tests/05-hpa-validation.js    # 压测脚本
```

---

## 📈 代码统计

### v0.3 代码量

```
新增 Go 代码:     ~150 行
  - workload.go:   ~130 行
  - main.go 更新:  ~20 行

新增 YAML 配置:   ~100 行
  - hpa.yaml:      ~70 行
  - deployment更新: ~30 行

新增 k6 脚本:     ~50 行

新增文档:         ~3000 行
  - README.md:            ~400 行
  - GOALS.md:             ~600 行
  - ARCHITECTURE.md:      ~800 行
  - PROJECT-STRUCTURE.md: ~500 行
  - DEPLOYMENT-GUIDE.md:  ~600 行
  - ASSESSMENT.md:        ~500 行

总计新增:         ~3300 行
```

---

## 🎯 下一步

了解项目结构后：

1. **如果要开始开发** → 阅读 [DEPLOYMENT-GUIDE.md](./DEPLOYMENT-GUIDE.md)
2. **如果要理解架构** → 阅读 [ARCHITECTURE.md](./ARCHITECTURE.md)
3. **如果要评估知识** → 阅读 [ASSESSMENT.md](./ASSESSMENT.md)

---

**项目结构清晰了吗？开始你的 v0.3 之旅吧！** 🚀
