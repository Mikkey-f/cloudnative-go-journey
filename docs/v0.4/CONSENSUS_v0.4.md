# v0.4 共识文档 (CONSENSUS)

> 精确的需求规范和技术方案

**创建时间**: 2025-11-14  
**版本**: v0.4 - 服务治理版  
**状态**: 共识确认

---

## 📋 需求描述

### 版本目标

**v0.4 - 服务治理版** 是云原生学习的关键版本，聚焦于 **服务间流量管理** 和 **灰度发布**。

通过本版本，学习者将：
- 理解 Ingress 和 Service 的区别与应用场景
- 掌握 Ingress Controller 的安装和配置
- 理解服务网格（Istio）的核心概念
- 实现金丝雀发布（灰度上线）

### 核心功能

| 功能 | 说明 | 优先级 |
|------|------|--------|
| Ingress 路由 | 配置基于路径和域名的路由规则 | P0 |
| 多服务架构 | 前端 + API + 数据库 | P0 |
| Istio 集成 | 安装 Istio 和 Envoy Sidecar 注入 | P0 |
| 金丝雀发布 | 实现 90/10 流量分流 | P0 |
| 流量验证 | 验证流量分配效果 | P1 |
| 前端服务 | 简单的 Go 前端服务 | P1 |

---

## 🏗️ 技术实现方案

### 架构设计

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
│  ├─ api-service                         │
│  ├─ frontend-service                    │
│  └─ redis-service                       │
└────────────────┬────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│      Istio 集群内部流量治理             │
│  ├─ VirtualService（路由规则）         │
│  │  └─ 90% → api-v1                    │
│  │  └─ 10% → api-v2                    │
│  │                                      │
│  ├─ DestinationRule（流量策略）        │
│  │  └─ 熔断、重试、负载均衡            │
│  │                                      │
│  └─ Envoy Sidecar（每个 Pod）          │
│     └─ 拦截流量、执行规则              │
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

### 技术栈

| 组件 | 版本 | 用途 |
|------|------|------|
| Kubernetes | 1.28+ | 容器编排 |
| Nginx Ingress Controller | Latest | 入口流量管理 |
| Istio | 1.18+ | 服务网格 |
| Envoy | 1.26+ | 数据平面代理 |
| Go | 1.23+ | 应用开发 |
| Docker | 24.x+ | 容器化 |

### 部署环境

- **开发环境**: Minikube 或 Kind
- **集群模式**: 单集群
- **资源需求**: 4 CPU，8GB RAM
- **Istio 模式**: Demo（学习阶段）

---

## 📦 交付物清单

### 代码交付物

```
src/
├── handler/
│   ├── frontend.go          # 新增：前端服务处理器
│   └── ...
└── main.go                  # 更新：注册前端路由

k8s/v0.4/
├── ingress/
│   ├── ingress.yaml         # 新增：Ingress 配置
│   └── README.md
├── istio/
│   ├── namespace.yaml       # 新增：istio-system 命名空间
│   ├── virtual-service.yaml # 新增：VirtualService 配置
│   ├── destination-rule.yaml # 新增：DestinationRule 配置
│   └── README.md
├── frontend/
│   ├── deployment.yaml      # 新增：前端 Deployment
│   ├── service.yaml         # 新增：前端 Service
│   └── README.md
├── api/
│   ├── deployment-v1.yaml   # 新增：API v1 Deployment
│   ├── deployment-v2.yaml   # 新增：API v2 Deployment
│   ├── service.yaml         # 复用/更新
│   └── README.md
└── README.md                # 新增：v0.4 部署指南

scripts/
├── verify-ingress.sh        # 新增：验证 Ingress
├── verify-istio.sh          # 新增：验证 Istio
├── canary-test.sh           # 新增：金丝雀发布测试
└── traffic-verify.sh        # 新增：流量分配验证

docs/v0.4/
├── ALIGNMENT_v0.4.md        # 对齐文档
├── CONSENSUS_v0.4.md        # 本文件
├── DESIGN_v0.4.md           # 架构设计（待创建）
├── TASK_v0.4.md             # 任务分解（待创建）
├── DEPLOYMENT-GUIDE.md      # 部署指南（待创建）
├── TROUBLESHOOTING.md       # 故障排查（待创建）
└── README.md                # 版本概述（待创建）

blog/v0.4/
├── 11-ingress-guide.md      # 博客 1：Ingress 完全指南
├── 12-ingress-controller.md # 博客 2：Ingress Controller 实战
├── 13-istio-intro.md        # 博客 3：Istio 服务网格介绍
└── 14-canary-deployment.md  # 博客 4：金丝雀发布实战
```

### 文档交付物

- ✅ ALIGNMENT_v0.4.md - 对齐文档
- ✅ CONSENSUS_v0.4.md - 共识文档（本文件）
- ⏳ DESIGN_v0.4.md - 架构设计文档
- ⏳ TASK_v0.4.md - 任务分解文档
- ⏳ DEPLOYMENT-GUIDE.md - 完整部署指南
- ⏳ README.md - 版本概述
- ⏳ 4 篇配套博客

---

## ✅ 验收标准

### 功能验收

| 验收项 | 标准 | 验证方式 |
|--------|------|---------|
| Ingress 正常工作 | 能通过 Ingress 访问前端和 API | curl 测试 |
| 多服务架构 | 前端、API、Redis 三个服务正常运行 | kubectl get pods |
| Istio 安装成功 | Istiod 和 Envoy 正常运行 | kubectl get pods -n istio-system |
| 金丝雀发布 | 能验证 90/10 流量分流 | 流量统计脚本 |
| 流量分配准确 | 流量分配比例在 85%-95% 范围内 | 100 次请求统计 |

### 代码质量

- ✅ 代码遵循现有风格和规范
- ✅ 新增代码有注释和文档
- ✅ 配置文件清晰易懂
- ✅ 脚本可执行且有错误处理

### 文档质量

- ✅ 部署指南完整清晰
- ✅ 架构图准确
- ✅ 故障排查文档完善
- ✅ 博客内容专业且易理解

---

## 🔧 技术约束

### 兼容性约束

- ✅ 与 v0.3 HPA 兼容（不冲突）
- ✅ 与现有 Redis 兼容
- ✅ 与现有 Prometheus 兼容
- ✅ 与现有代码风格一致

### 性能约束

- ✅ Ingress 路由延迟 < 100ms
- ✅ Istio Envoy 开销 < 10% CPU
- ✅ 金丝雀发布流量分配准确度 > 90%

### 安全约束

- ✅ 不涉及 mTLS（v1.0 再做）
- ✅ 不涉及授权策略（v1.0 再做）
- ✅ 敏感信息使用 .env 文件管理

---

## 📅 实施计划

### 时间规划

| 阶段 | 任务 | 时间 |
|------|------|------|
| Align | 需求对齐 | 1 小时 |
| Architect | 架构设计 | 2 小时 |
| Atomize | 任务分解 | 1 小时 |
| Approve | 审批确认 | 0.5 小时 |
| Automate | 代码实现 | 8-10 小时 |
| Assess | 验收评估 | 2 小时 |
| **总计** | | **14-16 小时** |

### 实施周期

- **计划周期**: 2-3 周（业余时间）
- **每周投入**: 5-8 小时
- **预计完成**: 第 11 周

---

## 🎯 成功标准

### 技术成功

- ✅ Ingress 能正确路由流量到前端和 API
- ✅ Istio 能成功注入 Envoy Sidecar
- ✅ VirtualService 能实现 90/10 流量分流
- ✅ 金丝雀发布流程完整可演示

### 学习成功

- ✅ 理解 Ingress 和 Service 的区别
- ✅ 理解 Istio 的核心概念（Istiod + Envoy）
- ✅ 理解 VirtualService 和 DestinationRule 的作用
- ✅ 能独立配置和部署 Ingress 和 Istio

### 交付成功

- ✅ 所有代码完成并测试通过
- ✅ 所有文档完整清晰
- ✅ 4 篇博客高质量完成
- ✅ 项目可独立运行和演示

---

## 🚨 风险识别

| 风险 | 影响 | 缓解方案 |
|------|------|---------|
| Istio 安装失败 | 无法进行后续开发 | 提供详细的故障排查文档 |
| 资源不足 | 集群性能下降 | 提供资源优化建议 |
| 流量分配不准确 | 无法验证金丝雀发布 | 提供多种验证方式 |
| 配置复杂 | 学习曲线陡 | 提供详细的配置说明 |

---

## ✅ 共识确认清单

- [x] 需求边界清晰无歧义
- [x] 技术方案与现有架构对齐
- [x] 验收标准具体可测试
- [x] 所有关键决策已确认
- [x] 交付物清单完整
- [x] 时间规划合理
- [x] 风险已识别和缓解

---

## 📝 共识总结

**状态**: ✅ 共识确认

**关键决定**:
1. 前端服务：简单 Go 服务
2. Ingress Controller：Nginx
3. 金丝雀发布：两种方式都演示
4. Istio 模式：Demo 模式
5. 博客：AI 生成初稿

**交付周期**: 2-3 周

**下一步**: 进入 **Architect（架构设计）阶段**

---
