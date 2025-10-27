# 更新日志

所有值得注意的项目变更都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

---

## [v0.1.0] - 2025-10-27

### 🎉 首次发布

**v0.1 - 基础版**：从零开始的云原生之旅第一站

### ✨ 新增功能

#### 应用服务
- Go HTTP API 服务（Gin 框架）
- 健康检查接口（`/health` 和 `/ready`）
- 业务接口（`/api/v1/hello` 和 `/api/v1/info`）
- Prometheus 指标暴露（`/metrics`）
- 日志中间件
- 指标收集中间件
- 配置管理（环境变量）
- 优雅关闭机制

#### Docker
- 多阶段 Dockerfile 构建
- 镜像大小优化（< 20MB）
- 静态编译（CGO_ENABLED=0）
- 非 root 用户运行
- Docker HEALTHCHECK 配置
- .dockerignore 构建优化

#### Kubernetes
- Deployment 配置（2 副本）
- Service 配置（NodePort 类型）
- Liveness Probe 配置
- Readiness Probe 配置
- 资源限制（CPU/Memory requests 和 limits）
- 环境变量注入

#### 文档
- 项目 README
- 快速开始指南（QUICKSTART.md）
- v0.1 学习目标（docs/v0.1/GOALS.md）
- K8s 基础知识速成（docs/v0.1/K8S-BASICS.md）
- 环境搭建指南（docs/v0.1/SETUP-ENVIRONMENT.md）
- 架构详解（docs/v0.1/ARCHITECTURE.md）
- 部署指南（k8s/v0.1/README.md）
- FAQ（docs/v0.1/FAQ.md）
- 故障排查指南（docs/v0.1/TROUBLESHOOTING.md）
- 完成总结（docs/v0.1/COMPLETION-SUMMARY.md）
- 最终验证报告（docs/v0.1/FINAL-VERIFICATION.md）

#### 博客
- 01 - Go 应用的云原生之旅（一）容器化
- 02 - K8s 部署你的第一个 Go 服务
- 03 - 云原生最佳实践：健康检查和资源限制

#### 脚本
- 环境检查脚本（PowerShell 和 Bash）
- v0.1 自动化部署脚本

### 📚 技术栈

- **语言**：Go 1.21+
- **框架**：Gin v1.9.1
- **监控**：Prometheus Client v1.18.0
- **容器**：Docker 24.x+
- **编排**：Kubernetes 1.28+ (Minikube)

### 🐛 已知问题

#### Windows 环境特殊性
- minikube service 需要创建隧道才能访问
- kubectl port-forward 不经过 Service 负载均衡
- 建议使用集群内测试验证负载均衡

#### Minikube 镜像加载
- 本地 Docker 镜像需要手动加载到 Minikube
- 使用 `minikube image load` 命令
- 或使用 `eval $(minikube docker-env)` 在 Minikube 环境中构建

### 📝 文档改进

- 增加了详细的架构图解
- 补充了网络流量路径说明
- 添加了 kubectl port-forward 和 Service 负载均衡的区别说明
- 完善了故障排查指南

---

## [未来版本] - 计划中

### v0.2 - 编排升级版
- StatefulSet（有状态应用 - Redis）
- DaemonSet（每节点一个 - 日志采集器）
- CronJob（定时任务 - 数据清理）
- ConfigMap 和 Secret（配置管理）

### v0.3 - 弹性伸缩版
- HPA（自动弹性伸缩）
- Metrics Server
- 压测验证

### v0.4 - 服务治理版
- Ingress Controller
- Istio 服务网格基础
- 金丝雀发布

### v0.5 - 配置管理版
- Kustomize 多环境配置
- 配置热更新

### v0.6 - 可观测性版
- Prometheus + Grafana
- Loki 日志聚合
- Jaeger 链路追踪

### v0.7 - CI/CD 版
- GitHub Actions
- ArgoCD GitOps

### v1.0 - 完整版
- 微服务架构
- Istio 完整功能

### v1.5 - 边缘计算 AI 版
- 云边协同
- 边缘 AI 推理

---

## 🔗 相关链接

- **项目地址**：https://github.com/yourname/cloudnative-go-journey
- **完整规划**：[cloudnative-go-journey-plan.md](cloudnative-go-journey-plan.md)
- **博客系列**：[blog/v0.1/](blog/v0.1/)

---

## 🤝 贡献者

感谢所有为这个项目做出贡献的开发者！

---

**格式说明**：
- `✨ 新增功能`：Added
- `🔧 修复`：Fixed
- `📝 文档`：Documentation
- `🎨 优化`：Changed
- `🗑️ 删除`：Removed
- `⚠️ 废弃`：Deprecated
- `🔒 安全`：Security
