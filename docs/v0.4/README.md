# v0.4 - 服务治理版

> CloudNative Go Journey v0.4 - 掌握 Ingress 和 Istio 服务网格

**版本**: v0.4.0  
**开发周期**: 2-3 周（Week 9-11）  
**难度**: ⭐⭐⭐⭐⭐（高级）  
**状态**: 📋 规划完成，等待审批

---

## 📋 版本概述

v0.4 是云原生学习的关键版本，聚焦于 **服务治理** 和 **灰度发布**。

通过本版本，你将掌握：
- ✅ **Ingress** - 外部流量入口管理
- ✅ **Istio** - 服务网格和应用层流量管理
- ✅ **金丝雀发布** - 灰度上线新版本
- ✅ **多服务架构** - 前端 + API + 数据库

---

## 🎯 学习目标

### 理论知识（40%）

- [ ] 理解 Service 和 Ingress 的区别
- [ ] 理解 Ingress Controller 的工作原理
- [ ] 理解服务网格（Service Mesh）的概念
- [ ] 理解 Istio 的架构（Istiod + Envoy）
- [ ] 理解 VirtualService 和 DestinationRule
- [ ] 理解金丝雀发布的原理

### 实践技能（50%）

- [ ] 能配置 Ingress 路由规则
- [ ] 能安装和配置 Istio
- [ ] 能创建 VirtualService 和 DestinationRule
- [ ] 能实现金丝雀发布（90/10 分流）
- [ ] 能验证流量分配效果
- [ ] 能部署多服务架构

### 工具使用（10%）

- [ ] kubectl 高级用法
- [ ] istioctl 命令行工具
- [ ] 流量验证脚本

---

## 🏗️ 架构设计

### 系统架构

```
┌─────────────────────────────────────────┐
│           外部用户                      │
└────────────────┬────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│    Ingress（Nginx Controller）          │
│  ├─ app.local/api → api-service         │
│  └─ app.local/    → frontend-service    │
└────────────────┬────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│         K8s Service 负载均衡            │
└────────────────┬────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│      Istio 集群内部流量治理             │
│  ├─ VirtualService（路由规则）         │
│  │  └─ 90% → api-v1                    │
│  │  └─ 10% → api-v2                    │
│  ├─ DestinationRule（流量策略）        │
│  └─ Envoy Sidecar（每个 Pod）          │
└────────────────┬────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│           实际 Pod                      │
│  ├─ frontend-pod (1 个)                 │
│  ├─ api-v1-pod (9 个)                   │
│  ├─ api-v2-pod (1 个)                   │
│  └─ redis-pod (1 个)                    │
└─────────────────────────────────────────┘
```

---

## 📦 新增组件

| 组件 | 说明 | 用途 |
|------|------|------|
| **Ingress** | 入口流量管理 | 路由外部请求到不同服务 |
| **Nginx Ingress Controller** | Ingress 实现 | 处理 Ingress 规则 |
| **Istio** | 服务网格 | 集群内部流量治理 |
| **Envoy** | 数据平面代理 | 拦截和转发流量 |
| **VirtualService** | 路由规则 | 定义流量如何分配 |
| **DestinationRule** | 流量策略 | 定义连接池和熔断 |
| **前端服务** | 简单 Go 服务 | 展示系统架构 |

---

## 📂 文档导航

### 核心文档

1. **[ALIGNMENT_v0.4.md](./ALIGNMENT_v0.4.md)** - 对齐文档
   - 项目上下文分析
   - 需求理解确认
   - 关键决策点

2. **[CONSENSUS_v0.4.md](./CONSENSUS_v0.4.md)** - 共识文档
   - 需求规范
   - 技术方案
   - 交付物清单

3. **[DESIGN_v0.4.md](./DESIGN_v0.4.md)** - 架构设计
   - 系统分层架构
   - 核心组件设计
   - 接口契约定义

4. **[TASK_v0.4.md](./TASK_v0.4.md)** - 任务分解
   - 12 个原子任务
   - 依赖关系
   - 时间估算

5. **[APPROVE_v0.4.md](./APPROVE_v0.4.md)** - 审批文档
   - 审批检查清单
   - 质量指标确认
   - 最终确认

### 参考文档（待创建）

- **DEPLOYMENT-GUIDE.md** - 完整部署指南
- **TROUBLESHOOTING.md** - 故障排查
- **BEST-PRACTICES.md** - 最佳实践

---

## 🚀 快速开始

### 前置要求

```bash
# 1. 完成 v0.3 版本
# 2. Kubernetes 集群正常运行
kubectl get nodes

# 3. 资源充足（4 CPU，8GB RAM）
```

### 6 个开发阶段

```
Phase 1: 环境准备 (1 小时)
  └─ 启用 Nginx Ingress Controller
  └─ 安装 Istio

Phase 2: 代码开发 (2 小时)
  └─ 开发前端服务
  └─ 开发 API v2

Phase 3: 配置部署 (2 小时)
  └─ 配置 Ingress
  └─ 配置 Istio

Phase 4: 流量验证 (1 小时)
  └─ 验证 Ingress 路由
  └─ 验证金丝雀发布

Phase 5: 文档编写 (2 小时)
  └─ 部署指南
  └─ 架构说明

Phase 6: 博客创建 (3 小时)
  └─ 4 篇技术文章
```

### 开始开发

```bash
# 1. 查看对齐文档
cat docs/v0.4/ALIGNMENT_v0.4.md

# 2. 查看共识文档
cat docs/v0.4/CONSENSUS_v0.4.md

# 3. 查看架构设计
cat docs/v0.4/DESIGN_v0.4.md

# 4. 查看任务分解
cat docs/v0.4/TASK_v0.4.md

# 5. 审批确认
cat docs/v0.4/APPROVE_v0.4.md
```

---

## 📊 项目结构

```
cloudnative-go-journey/
├── src/
│   ├── handler/
│   │   ├── frontend.go          # 新增：前端服务
│   │   └── ...
│   └── main.go                  # 更新：注册前端路由
│
├── k8s/v0.4/                    # 新增：v0.4 配置
│   ├── ingress/
│   │   └── ingress.yaml
│   ├── istio/
│   │   ├── virtual-service.yaml
│   │   └── destination-rule.yaml
│   ├── frontend/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── api/
│   │   ├── deployment-v1.yaml
│   │   ├── deployment-v2.yaml
│   │   └── service.yaml
│   └── README.md
│
├── scripts/
│   ├── verify-ingress.sh        # 新增：验证 Ingress
│   ├── verify-istio.sh          # 新增：验证 Istio
│   ├── canary-test.sh           # 新增：金丝雀测试
│   └── traffic-verify.sh        # 新增：流量验证
│
├── docs/v0.4/                   # 本目录
│   ├── ALIGNMENT_v0.4.md
│   ├── CONSENSUS_v0.4.md
│   ├── DESIGN_v0.4.md
│   ├── TASK_v0.4.md
│   ├── APPROVE_v0.4.md
│   ├── README.md                # 本文件
│   ├── DEPLOYMENT-GUIDE.md      # 待创建
│   └── TROUBLESHOOTING.md       # 待创建
│
└── blog/v0.4/                   # 待创建：配套博客
    ├── 11-ingress-guide.md
    ├── 12-ingress-controller.md
    ├── 13-istio-intro.md
    └── 14-canary-deployment.md
```

---

## ✅ 交付标准

### 功能验收

- ✅ Ingress 正常路由流量
- ✅ 多服务架构运行正常
- ✅ 金丝雀发布能正常工作
- ✅ Istio 集群内部治理有效

### 代码质量

- ✅ 代码遵循现有风格
- ✅ 新增代码有注释
- ✅ 配置文件清晰易懂
- ✅ 脚本可执行且有错误处理

### 文档质量

- ✅ 部署指南完整清晰
- ✅ 架构图准确
- ✅ 故障排查全面
- ✅ 4 篇博客高质量

---

## 📈 预期成果

### 技术成果

- ✅ Ingress 能正确路由流量
- ✅ Istio 能成功注入 Envoy
- ✅ VirtualService 能实现 90/10 分流
- ✅ 金丝雀发布流程完整

### 学习成果

- ✅ 理解 Ingress 和 Service 的区别
- ✅ 理解 Istio 的核心概念
- ✅ 理解 VirtualService 和 DestinationRule
- ✅ 能独立配置和部署

### 交付物

- ✅ 完整的代码实现
- ✅ K8s 配置文件
- ✅ 验证脚本
- ✅ 完整的文档
- ✅ 4 篇配套博客

---

## 🔗 相关资源

### 官方文档

- [Kubernetes Ingress](https://kubernetes.io/zh-cn/docs/concepts/services-networking/ingress/)
- [Nginx Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [Istio 官方文档](https://istio.io/latest/zh/docs/)
- [Envoy 代理](https://www.envoyproxy.io/)

### 学习资源

- [Ingress 完全指南](https://kubernetes.io/zh-cn/docs/concepts/services-networking/ingress/)
- [Istio 流量管理](https://istio.io/latest/zh/docs/tasks/traffic-management/)
- [VirtualService 配置](https://istio.io/latest/zh/docs/reference/config/networking/virtual-service/)

---

## 📝 工作流状态

### 6A 工作流进度

```
✅ Phase 1: Align（对齐）
   └─ ALIGNMENT_v0.4.md 已完成

✅ Phase 2: Architect（架构）
   └─ DESIGN_v0.4.md 已完成

✅ Phase 3: Atomize（原子化）
   └─ TASK_v0.4.md 已完成

⏳ Phase 4: Approve（审批）
   └─ APPROVE_v0.4.md 已完成，等待用户确认

⏳ Phase 5: Automate（自动化执行）
   └─ 待审批通过后开始

⏳ Phase 6: Assess（评估）
   └─ 待执行完成后进行
```

---

## 🎯 下一步

### 立即行动

1. **审批确认**
   - 阅读 APPROVE_v0.4.md
   - 确认所有项目
   - 反馈任何问题

2. **进入 Automate 阶段**
   - 按任务依赖顺序执行
   - 每个任务都有完整的实现
   - 实时更新进度

3. **最终交付**
   - 所有代码完成
   - 所有文档完成
   - 所有博客完成

---

## 📞 联系方式

- **项目问题**: GitHub Issues
- **技术讨论**: GitHub Discussions

---

**准备好了吗？让我们开始 v0.4 的服务治理之旅！** 🚀

📖 **下一步**: 阅读 [APPROVE_v0.4.md](./APPROVE_v0.4.md) 进行审批确认

---
