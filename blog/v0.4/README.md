# v0.4 - 服务暴露与流量管理

## 📚 博客列表

### 11. 《从 Service 到 Ingress：K8s 服务暴露完全指南》

**关键词**: Service, NodePort, LoadBalancer, Ingress, 架构演进

梳理 Kubernetes 服务暴露方式，明确何时需要引入 Ingress，并给出渐进式演进策略。

**核心内容**:

- ClusterIP/NodePort/LoadBalancer/ExternalName 的定位与适用场景
- 从 Service 到 Ingress 的架构演进路径
- NodePort → Ingress 的逐步实战示例
- 升级 Ingress 的决策清单与常见排查
- 为后续 Ingress 深度剖析奠定基础

---

### 12. 《Ingress 深度剖析：从 Service 到统一入口》

**关键词**: Ingress, IngressClass, PathType, TLS, 架构

全面解析 Ingress 的设计理念与协议分层，帮助读者在动手部署前先掌握规范与架构。

**核心内容**:

- Service 暴露方式的对比与 Ingress 定位
- Ingress 三层架构：资源、控制面、数据面
- 资源规范详解：PathType、默认后端、IngressClass
- TLS 终止、注解分类与请求生命周期
- 何时应该从 Ingress 演进到 Istio

---

### 13. 《Ingress Controller 实战：Nginx Ingress 深度解析》

**关键词**: Ingress Controller, Nginx, 路由规则, TLS

通过 Nginx Ingress Controller 掌握应用层路由的配置与优化。

**核心内容**:

- Ingress Controller 的工作原理
- Nginx Ingress 的安装和配置
- 基于路径和域名的高级路由
- TLS/HTTPS 配置
- **重要**：Ingress 与 Istio 的架构冲突说明

**⚠️ 重要提示**：

- Ingress 和 Istio Gateway **不应该混合使用**
- Ingress 工作在集群入口（北向流量）
- Istio 提供完整的服务网格方案（东西向+南北向）
- 两者选其一，不要同时部署

---

### 13. 《初探服务网格：Istio 让微服务更简单》

**关键词**: Istio, Service Mesh, Envoy, 流量管理

从传统 Ingress 迁移到 Istio，理解服务网格的核心价值。

**核心内容**:

- Istio 架构：Istiod + Envoy Sidecar
- Istio Gateway vs Kubernetes Ingress 的本质区别
- VirtualService 和 DestinationRule 配置
- 流量拦截和路由原理
- **重要**：为什么要从 Ingress 切换到 Istio

**⚠️ 架构决策**：

- **Ingress 方案**：适合简单应用，成本低，配置简单
- **Istio 方案**：适合复杂微服务，功能强大，学习成本高
- **不要混用**：选择一种方案后，删除另一种的配置
- 本项目选择 **Ist**io 方案实现金丝雀发布

---

### 14. 《金丝雀发布实战：灰度上线新版本》

**关键词**: 金丝雀发布, 灰度发布, 流量分配, A/B Testing

使用 Istio 实现 90/10 流量分配的金丝雀发布策略。

**核心内容**:

- 金丝雀发布原理和流程
- Istio 的流量分配策略
- v1/v2 版本的灰度发布实战
- 流量验证和监控
- 金丝雀发布的最佳实践

---

## 🎯 学习目标

完成 v0.4 后，你将掌握：

1. **服务暴露**：
   - 理解 ClusterIP、NodePort、LoadBalancer、Ingress 的区别
   - 能够根据场景选择合适的暴露方式

2. **Ingress vs Istio**：
   - 理解两者的本质区别和架构冲突
   - 明确两者不能混用的原因
   - 能够做出合理的技术选型

3. **Istio 服务网格**：
   - 理解 Istio 的核心组件和工作原理
   - 掌握 Gateway、VirtualService、DestinationRule 的配置
   - 理解流量劫持和 Sidecar 模式

4. **金丝雀发布**：
   - 实现基于权重的流量分配
   - 验证灰度发布效果
   - 掌握发布策略的调整

---

## 📂 相关代码

```text
k8s/v0.4/
├── api/
│   ├── deployment-v1.yaml      # API v1 部署（稳定版）
│   ├── deployment-v2.yaml      # API v2 部署（金丝雀）
│   └── service.yaml            # ClusterIP Service
├── frontend/
│   ├── deployment.yaml         # 前端服务
│   └── service.yaml
├── ingress/
│   └── ingress.yaml            # Ingress 配置（已废弃，使用 Istio）
└── istio/
    ├── gateway.yaml            # Istio Gateway
    ├── virtual-service.yaml    # 流量路由规则（90/10分流）
    └── destination-rule.yaml   # 目标规则（v1/v2子集）
```

---

## 🔄 架构演进

### 阶段 1：Ingress 方案（已废弃）

```text
外部 → Nginx Ingress Controller → Service → Pod
```

- ✅ 简单易用
- ❌ 无法实现复杂流量管理
- ❌ 无法实现金丝雀发布

### 阶段 2：Istio 方案（当前）

```text
外部 → Istio IngressGateway → VirtualService → Pod (Sidecar Envoy)
```

- ✅ 完整的服务网格能力
- ✅ 金丝雀发布、流量分割
- ✅ mTLS、熔断、限流等高级功能
- ⚠️ 学习曲线陡峭

## ⚠️ 重要说明

### Ingress 与 Istio 的选择

#### 不要混用

- 同时部署 Ingress 和 Istio Gateway 会导致路由冲突
- 端口占用冲突（都监听 80/443）
- 流量走向不明确

#### 如何选择

- **简单应用 → 使用 Ingress**
  - 只需要基本的路径/域名路由
  - 不需要复杂的流量管理
  - 团队对 K8s 不熟悉
- **复杂微服务 → 使用 Istio**
  - 需要金丝雀发布、A/B测试
  - 需要细粒度的流量控制
  - 需要服务间的 mTLS
  - 需要熔断、限流等高级功能

#### 迁移建议

- 从 Ingress 迁移到 Istio：删除 Ingress 资源，部署 Istio Gateway
- 从 Istio 回退到 Ingress：删除 Istio 组件，重新部署 Ingress

---

## 📊 性能测试

金丝雀发布流量验证（100次请求）:

```text
v1: 88-92次（88%-92%）
v2: 8-12次（8%-12%）
```

符合预期的 90/10 流量分配！

---

## 🚀 下一步

完成 v0.4 后，你可以继续：

- v0.5：配置管理（ConfigMap、Secret、外部配置中心）
- 深入学习 Istio 的其他功能（熔断、限流、超时重试）
- 学习服务网格的可观测性（Jaeger、Kiali、Prometheus）
