# v0.4 对齐文档 (ALIGNMENT)

> 从模糊需求到精确规范

**创建时间**: 2025-11-14  
**版本**: v0.4 - 服务治理版  
**状态**: 对齐阶段

---

## 📋 项目上下文分析

### 现有项目状态

**已完成版本**:
- ✅ v0.1 - 基础版：Go Gin API + Docker + K8s Deployment/Service
- ✅ v0.2 - 编排升级版：StatefulSet/DaemonSet/CronJob + ConfigMap/Secret + Redis
- ✅ v0.3 - 弹性伸缩版：HPA + Metrics Server + 压测

**现有技术栈**:
- Go 1.23+
- Gin Web 框架
- Docker 多阶段构建
- Kubernetes 1.28+
- Redis StatefulSet
- Prometheus 指标
- k6 压测工具

**现有代码模式**:
- 模块化结构（handler/middleware/config/metrics/cache）
- 中间件模式（日志、指标、恢复）
- 配置管理（环境变量 + 配置文件）
- 健康检查（Liveness + Readiness）
- Prometheus 集成

**现有 K8s 配置**:
- Deployment + Service（v0.1）
- StatefulSet（Redis）+ DaemonSet（日志采集）+ CronJob（清理任务）（v0.2）
- HPA 配置（v0.3）

---

## 🎯 原始需求

### 规划文档中的 v0.4 定义

```
### v0.4 - 服务治理版（Week 9-11，2-3周）

#### 学习目标
- 理解 Ingress 和 Service 的区别
- 掌握 Ingress Controller 安装配置
- 了解服务网格基础概念
- 学会金丝雀发布

#### 新增组件
1. **前端服务**（可选，简单静态页面）
2. **Ingress Controller**（Nginx/Traefik）
3. **Istio**（服务网格基础）

#### 交付标准
- ✅ Ingress 正常路由流量
- ✅ 多服务架构运行正常
- ✅ 金丝雀发布能正常工作
- ✅ 配套 3-4 篇博客
```

---

## 🔍 需求理解与边界确认

### 需求分解

| 需求项 | 详细说明 | 优先级 |
|--------|---------|--------|
| **Ingress 配置** | 配置 Ingress 路由规则，支持多服务路由 | P0 |
| **Ingress Controller** | 安装 Nginx 或 Traefik | P0 |
| **前端服务** | 简单的静态页面或简单 Go 服务 | P1 |
| **Istio 安装** | 安装 Istio 和 Envoy Sidecar 注入 | P0 |
| **VirtualService** | 配置 Istio VirtualService 进行金丝雀发布 | P0 |
| **DestinationRule** | 配置 Istio DestinationRule 进行流量管理 | P0 |
| **金丝雀发布演示** | 实现 90/10 流量分流的金丝雀发布 | P0 |
| **监控和验证** | 验证流量分配效果 | P1 |
| **配套博客** | 4 篇技术文章 | P1 |

### 任务范围（IN SCOPE）

✅ **包含**:
1. Ingress 配置和部署
2. Ingress Controller（Nginx）安装
3. Istio 核心功能（Istiod + Envoy）
4. VirtualService 和 DestinationRule 配置
5. 金丝雀发布实现（90/10 分流）
6. 前端服务（简单 Go 服务或静态页面）
7. 流量验证脚本
8. 完整的部署文档

❌ **不包含**:
- Istio 高级功能（mTLS、授权策略、故障注入等）
- 多集群 Istio
- Istio 可视化工具（Kiali）详细配置
- 生产级安全加固
- 性能优化和调优

### 技术约束

```
部署环境：
- Minikube 或 Kind（本地开发）
- 单集群
- 资源充足（至少 4 CPU，8GB RAM）

技术栈：
- 复用现有 Go 应用代码
- 复用现有 K8s 配置模式
- Nginx Ingress Controller（推荐）
- Istio 1.18+（最新稳定版）

兼容性：
- 与 v0.3 的 HPA 兼容
- 与现有 Redis/数据库兼容
- 与现有 Prometheus 兼容
```

---

## ❓ 疑问澄清与关键决策点

### 问题 1：前端服务的实现方式

**选项**:
- A. 简单的 Go 服务（返回 HTML）
- B. 纯静态 HTML 文件
- C. 使用现有 API 服务的 /static 路由

**决策**: 选择 **A - 简单的 Go 服务**
- 原因：与现有代码风格一致，便于演示 Ingress 路由
- 实现：新增 handler/frontend.go，返回简单 HTML

---

### 问题 2：Ingress Controller 的选择

**选项**:
- A. Nginx Ingress Controller
- B. Traefik
- C. 两者都支持

**决策**: 选择 **A - Nginx Ingress Controller**
- 原因：生态成熟，文档完善，Minikube 内置支持
- 备注：文档中会提及 Traefik 的对比

---

### 问题 3：金丝雀发布的实现方式

**选项**:
- A. 只用 K8s 原生方式（replicas 比例）
- B. 只用 Istio VirtualService
- C. 两种都演示

**决策**: 选择 **C - 两种都演示**
- 原因：帮助用户理解两种方式的区别和优缺点
- 实现：
  - 方式 1：使用 replicas 比例（简单）
  - 方式 2：使用 Istio VirtualService（高级）

---

### 问题 4：Istio 的部署模式

**选项**:
- A. 完整安装（所有组件）
- B. 最小安装（只有必要组件）
- C. Demo 模式（用于学习）

**决策**: 选择 **C - Demo 模式**
- 原因：学习阶段，资源充足，便于演示所有功能
- 命令：`istioctl install --set profile=demo -y`

---

### 问题 5：博客的编写方式

**选项**:
- A. AI 生成初稿，用户审核修改
- B. 用户自己编写
- C. 提供详细大纲，用户编写

**决策**: 选择 **A - AI 生成初稿**
- 原因：加快交付速度，用户可以快速审核修改
- 实现：生成 4 篇博客的初稿

---

## 📊 现有项目的关键信息

### 代码结构

```
src/
├── handler/          # HTTP 处理器
│   ├── health.go     # 健康检查
│   ├── hello.go      # 基础接口
│   ├── cache.go      # 缓存接口
│   ├── data.go       # 数据接口
│   └── workload.go   # 负载测试接口
├── middleware/       # 中间件
│   ├── logging.go    # 日志
│   └── metrics.go    # Prometheus 指标
├── config/          # 配置管理
├── metrics/         # Prometheus 初始化
├── cache/           # Redis 缓存
└── main.go          # 主入口
```

### K8s 配置结构

```
k8s/
├── v0.1/            # Deployment + Service
├── v0.2/            # StatefulSet + DaemonSet + CronJob
├── v0.3/            # HPA 配置
└── v0.4/            # 新增：Ingress + Istio（待创建）
```

### 现有最佳实践

- ✅ 模块化代码结构
- ✅ 中间件模式
- ✅ 配置管理
- ✅ 健康检查
- ✅ Prometheus 集成
- ✅ 优雅关闭
- ✅ 错误处理

---

## 🎯 v0.4 的精确需求规范

### 功能需求

| 功能 | 描述 | 验收标准 |
|------|------|---------|
| **Ingress 路由** | 配置 Ingress 路由规则 | 能通过 Ingress 访问前端和 API |
| **多服务架构** | 前端 + API + Redis | 三个服务正常运行 |
| **金丝雀发布** | 实现 90/10 流量分流 | 能验证流量分配比例 |
| **Istio 集成** | 安装和配置 Istio | Envoy Sidecar 自动注入 |
| **流量验证** | 验证流量分配 | 脚本能统计流量分配 |

### 非功能需求

| 需求 | 描述 |
|------|------|
| **可维护性** | 代码遵循现有风格，配置清晰 |
| **可扩展性** | 便于后续添加更多服务 |
| **文档完整性** | 部署指南、架构文档、博客 |
| **学习价值** | 清晰展示 Ingress 和 Istio 的概念 |

---

## 📝 对齐检查清单

- [x] 理解现有项目架构和代码模式
- [x] 明确 v0.4 的功能范围
- [x] 确认技术栈和约束
- [x] 解决关键决策点
- [x] 确认交付物清单

---

## ✅ 对齐阶段总结

**状态**: ✅ 完成

**关键决定**:
1. 前端服务：简单 Go 服务
2. Ingress Controller：Nginx
3. 金丝雀发布：两种方式都演示
4. Istio 模式：Demo 模式
5. 博客：AI 生成初稿

**下一步**: 进入 **Architect（架构）阶段**

---
