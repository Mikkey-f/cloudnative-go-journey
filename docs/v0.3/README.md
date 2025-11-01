# v0.3 - 弹性伸缩版

> CloudNative Go Journey v0.3 - 掌握 Kubernetes 水平自动扩缩（HPA）

**版本**：v0.3.0  
**开发周期**：2 周（Week 7-8）  
**难度**：⭐⭐⭐⭐（中高级）

---

## 📋 版本概述

v0.3 是云原生能力的重要进阶版本，主要聚焦于 **弹性伸缩**（Auto-Scaling），这是云原生的核心优势之一。

### 核心能力

通过 v0.3，你将掌握：

- ✅ **HPA（水平自动扩缩）** - 根据负载自动调整副本数
- ✅ **Metrics Server** - Kubernetes 资源指标采集
- ✅ **资源管理** - 深入理解 requests/limits 和 QoS
- ✅ **压测验证** - 使用 k6 进行性能测试
- ✅ **性能优化** - 基于监控数据调优配置

### 为什么重要？

```
传统部署：固定副本数
  - 高峰期：资源不足，服务慢或崩溃
  - 低谷期：资源浪费，成本高
  
云原生弹性伸缩：
  - 高峰期：自动扩容，保证性能
  - 低谷期：自动缩容，节省成本
  - 优势：按需分配，成本优化 30-70%
```

---

## 🎯 学习目标

### 理论知识（40%）

- [ ] 理解 HPA 的工作原理和计算公式
- [ ] 掌握 Metrics Server 的架构和数据流
- [ ] 深入理解 resources requests/limits
- [ ] 了解 QoS 三个等级及其影响
- [ ] 理解扩缩容的延迟和稳定期

### 实践技能（50%）

- [ ] 能安装和配置 Metrics Server
- [ ] 能创建和配置 HPA
- [ ] 能编写 CPU/内存密集型接口
- [ ] 能使用 k6 进行压测
- [ ] 能观察和分析扩缩容过程
- [ ] 能根据监控数据调优配置

### 工具使用（10%）

- [ ] kubectl top 查看资源使用
- [ ] kubectl get hpa 监控 HPA 状态
- [ ] k6 压测工具使用
- [ ] Prometheus 指标查询（可选）

---

## 📂 文档导航

### 核心文档

1. **[GOALS.md](./GOALS.md)** - 详细的学习目标和交付标准
2. **[ARCHITECTURE.md](./ARCHITECTURE.md)** - 技术架构和设计方案
3. **[PROJECT-STRUCTURE.md](./PROJECT-STRUCTURE.md)** - 项目结构说明
4. **[DEPLOYMENT-GUIDE.md](./DEPLOYMENT-GUIDE.md)** - 完整部署指南
5. **[ASSESSMENT.md](./ASSESSMENT.md)** - 前置知识评估清单

### 参考文档

- **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** - 常见问题排查（待完成后创建）
- **[BEST-PRACTICES.md](./BEST-PRACTICES.md)** - 最佳实践总结（待完成后创建）

---

## 🛠️ 技术栈

### 核心技术

| 组件 | 版本 | 用途 |
|------|------|------|
| Kubernetes | 1.28+ | 容器编排 |
| Metrics Server | Latest | 资源指标采集 |
| HPA | autoscaling/v2 | 自动扩缩 |
| k6 | Latest | 性能压测 |
| Go | 1.23+ | 应用开发 |

### 新增依赖

```go
// go.mod 新增
github.com/gin-gonic/gin v1.10.0  // 已有
// 不需要新增依赖，使用标准库即可
```

---

## 📊 项目结构

```
cloudnative-go-journey/
├── src/
│   ├── handler/
│   │   ├── workload.go          # 新增：负载测试接口
│   │   └── ...
│   └── main.go                  # 更新：注册新接口
│
├── k8s/v0.3/                    # 新增：v0.3 配置
│   ├── api/
│   │   ├── deployment.yaml     # 更新：优化资源配置
│   │   ├── service.yaml        # 复用 v0.2
│   │   └── hpa.yaml            # 新增：HPA 配置
│   ├── redis/                  # 复用 v0.2
│   └── README.md               # 新增：部署说明
│
├── k6-tests/                    # 已有：压测脚本
│   ├── 01-simple-test.js
│   ├── 02-with-checks.js
│   ├── 03-virtual-users.js
│   └── 04-real-world-scenario.js
│
├── docs/v0.3/                   # 本目录
│   ├── README.md               # 本文件
│   ├── GOALS.md
│   ├── ARCHITECTURE.md
│   ├── PROJECT-STRUCTURE.md
│   ├── DEPLOYMENT-GUIDE.md
│   └── ASSESSMENT.md
│
└── blog/v0.3/                   # 待创建：配套博客
    ├── 09-autoscaling-intro.md
    ├── 10-hpa-practice.md
    └── 11-load-testing.md
```

---

## 🚀 快速开始

### 前置要求

```bash
# 1. 完成 v0.2 版本
# 2. Kubernetes 集群正常运行
kubectl get nodes

# 3. 准备安装 Metrics Server
```

### 6 个开发阶段

```
Phase 1: 环境准备 (30分钟)
  └─ 安装和验证 Metrics Server

Phase 2: 代码开发 (1-2小时)
  └─ 添加 CPU/内存密集型接口

Phase 3: K8s 配置 (30分钟)
  └─ 创建 HPA 配置文件

Phase 4: 压测验证 (1-2小时)
  └─ 使用 k6 验证 HPA 效果

Phase 5: 优化调整 (1小时)
  └─ 根据测试结果优化配置

Phase 6: 文档完善 (2-3小时)
  └─ 编写部署文档和博客
```

### 开始开发

```bash
# 1. 切换到项目目录
cd cloudnative-go-journey-plan

# 2. 查看完整部署指南
cat docs/v0.3/DEPLOYMENT-GUIDE.md

# 3. 开始 Phase 1
# 按照 DEPLOYMENT-GUIDE.md 中的步骤执行
```

---

## 📈 预期成果

### 技术成果

- ✅ Metrics Server 成功部署
- ✅ HPA 能根据 CPU 负载自动扩缩容
- ✅ 压测能触发扩容（1→5+ 副本）
- ✅ 负载降低后自动缩容（5→1 副本）
- ✅ 扩缩容响应时间 < 2 分钟

### 性能指标

```
扩容测试：
- 触发条件：CPU 使用率 > 70%
- 扩容速度：30-60 秒内增加副本
- 最大副本：10 个

缩容测试：
- 触发条件：CPU 使用率 < 30%（持续 5 分钟）
- 缩容速度：5-10 分钟后减少副本
- 最小副本：2 个（高可用）

资源节省：
- 低谷期相比固定 10 副本：节省 80% 资源
- 高峰期相比固定 2 副本：避免性能下降
```

### 交付物

- ✅ 完整的代码实现
- ✅ K8s 配置文件（HPA + Deployment）
- ✅ k6 压测脚本
- ✅ 完整的部署文档
- ✅ 2-3 篇配套博客

---

## 🎓 学习路径

### 推荐顺序

```
Day 1-2: 理论学习和环境准备
  1. 阅读 GOALS.md（学习目标）
  2. 阅读 ARCHITECTURE.md（架构设计）
  3. 完成 ASSESSMENT.md（知识评估）
  4. Phase 1: 安装 Metrics Server

Day 3-4: 代码开发和配置
  5. Phase 2: 开发负载接口
  6. Phase 3: 配置 HPA
  7. 构建和部署

Day 5-6: 测试和优化
  8. Phase 4: 压测验证
  9. Phase 5: 优化调整
  10. 性能调优

Day 7: 文档和总结
  11. Phase 6: 完善文档
  12. 编写博客
  13. 项目总结
```

### 深度学习

完成基础实践后，可以深入学习：

- 📚 VPA（垂直自动扩缩）
- 📚 KEDA（事件驱动扩缩）
- 📚 自定义指标（Custom Metrics）
- 📚 集群自动扩缩（Cluster Autoscaler）

---

## 🔗 相关资源

### 官方文档

- [Kubernetes HPA 官方文档](https://kubernetes.io/zh-cn/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Metrics Server GitHub](https://github.com/kubernetes-sigs/metrics-server)
- [资源管理指南](https://kubernetes.io/zh-cn/docs/concepts/configuration/manage-resources-containers/)

### 学习资源

- [HPA 演练教程](https://kubernetes.io/zh-cn/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)
- [k6 文档](https://k6.io/docs/)
- [Prometheus 查询语言](https://prometheus.io/docs/prometheus/latest/querying/basics/)

### 项目链接

- **GitHub 仓库**: https://github.com/yourname/cloudnative-go-journey
- **v0.2 版本**: [../v0.2/](../v0.2/)
- **v0.4 规划**: [../v0.4/](../v0.4/)（待创建）

---

## ❓ FAQ

### Q1: 必须完成 v0.2 才能开始 v0.3 吗？

**A:** 是的。v0.3 依赖 v0.2 的以下内容：
- API 服务代码
- Deployment 配置
- Redis 缓存（可选）
- 基础资源配置

### Q2: Metrics Server 在生产环境怎么部署？

**A:** 生产环境需要：
- 正确配置 TLS 证书
- 不使用 `--kubelet-insecure-tls`
- 配置高可用（多副本）
- 监控 Metrics Server 自身

### Q3: HPA 最小副本能设为 0 吗？

**A:** 不能。HPA 的 `minReplicas` 最小是 1。如果需要缩容到 0，使用 KEDA。

### Q4: 如何选择合适的目标 CPU 使用率？

**A:** 建议：
- Web 服务：60-80%
- 计算密集型：70-85%
- 内存密集型：60-75%
- 留出 20-30% 缓冲应对突发流量

### Q5: 扩缩容太慢怎么办？

**A:** 检查：
- Metrics Server 是否正常工作
- 配置 behavior 调整扩缩速度
- 减少 stabilizationWindowSeconds
- 优化应用启动时间

---

## 📝 更新日志

### v0.3.0 (2025-11-01)

**新增功能**
- ✨ HPA 配置支持
- ✨ CPU/内存密集型测试接口
- ✨ k6 压测集成
- ✨ 完整的部署文档

**优化改进**
- 🔧 优化资源配置
- 🔧 改进健康检查
- 📚 完善文档体系

---

## 👥 贡献者

感谢所有为 v0.3 做出贡献的开发者！

---

## 📧 联系方式

- **项目问题**: [GitHub Issues](https://github.com/yourname/cloudnative-go-journey/issues)
- **技术讨论**: [GitHub Discussions](https://github.com/yourname/cloudnative-go-journey/discussions)

---

**准备好了吗？让我们开始 v0.3 的云原生之旅！** 🚀

📖 **下一步**: 阅读 [GOALS.md](./GOALS.md) 了解详细学习目标

