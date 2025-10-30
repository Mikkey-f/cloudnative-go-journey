# CloudNative Go Journey

> 云原生 Go 实战之旅 - 从零开始的渐进式云原生学习项目

[![Go Version](https://img.shields.io/badge/Go-1.21+-00ADD8?style=flat&logo=go)](https://go.dev/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-326CE5?style=flat&logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Docker](https://img.shields.io/badge/Docker-24.x+-2496ED?style=flat&logo=docker&logoColor=white)](https://www.docker.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 📋 项目简介

**CloudNative Go Journey** 是一个面向云原生初学者的实战教学项目，通过渐进式的版本迭代，从最基础的容器化部署到完整的云原生架构，带领学习者掌握云原生核心技术栈。

### 项目特点

- ✅ **渐进式学习** - 从简单到复杂，每个版本都能独立运行
- ✅ **实战导向** - 真实代码 + 真实部署，不是玩具项目
- ✅ **配套文档** - 详细的教程和最佳实践
- ✅ **中文友好** - 完整的中文文档和注释
- ✅ **Go 技术栈** - 云原生的标准语言
- ✅ **开源共建** - 欢迎社区贡献

## 🎯 当前版本：v0.2 - 编排升级版

### v0.2 学习目标

- ✅ 掌握 K8s 四种核心工作负载（Deployment/StatefulSet/DaemonSet/CronJob）
- ✅ 理解有状态应用部署（StatefulSet + Headless Service）
- ✅ 掌握持久化存储（PVC/PV/volumeClaimTemplates）
- ✅ 实现节点级服务（DaemonSet）
- ✅ 配置定时任务（CronJob）
- ✅ 管理配置和密钥（ConfigMap/Secret）

### v0.1 学习目标（已完成）

- ✅ 理解容器化的本质
- ✅ 掌握多阶段 Dockerfile 构建
- ✅ 理解 K8s Deployment 和 Service
- ✅ 配置健康检查和资源限制
- ✅ 本地 Minikube 部署和访问

### 技术栈

- **语言**: Go 1.23+
- **框架**: Gin
- **缓存**: Redis 7.4
- **监控**: Prometheus
- **容器**: Docker
- **编排**: Kubernetes (Minikube)

### 项目结构

```
cloudnative-go-journey/
├── src/                    # Go 源码
│   ├── main.go            # API 主入口
│   ├── cache/             # Redis 缓存模块
│   ├── config/            # 配置管理
│   ├── handler/           # HTTP 处理器
│   ├── middleware/        # 中间件
│   ├── metrics/           # Prometheus 指标
│   ├── log-collector/     # 日志采集器
│   └── cleanup-job/       # 清理任务
├── k8s/                   # K8s 配置
│   ├── v0.1/              # v0.1 配置
│   └── v0.2/              # v0.2 配置
│       ├── api/           # API 服务
│       ├── redis/         # Redis StatefulSet
│       ├── log-collector/ # DaemonSet
│       └── cleanup-job/   # CronJob
├── docs/                  # 文档
│   ├── v0.1/              # v0.1 文档
│   └── v0.2/              # v0.2 文档
├── blog/                  # 技术博客
│   ├── v0.1/              # v0.1 博客（3篇）
│   └── v0.2/              # v0.2 博客（5篇）
├── scripts/               # 自动化脚本
├── Dockerfile             # API 服务镜像
├── Dockerfile.log-collector  # 日志采集器镜像
├── Dockerfile.cleanup-job    # 清理任务镜像
├── go.mod                 # Go 依赖
└── README.md              # 本文件
```

## 🚀 快速开始

### 1. 环境准备

确保已安装：
- Go 1.23+
- Docker Desktop
- kubectl
- Minikube

详细安装指南：[docs/v0.1/SETUP-ENVIRONMENT.md](docs/v0.1/SETUP-ENVIRONMENT.md)

### 2. 快速部署 v0.2

```bash
# 克隆项目
git clone https://github.com/yourname/cloudnative-go-journey.git
cd cloudnative-go-journey

# 使用自动化脚本部署 v0.2
.\scripts\deploy-v0.2.ps1
```

**或手动部署：**

```bash
# 1. 切换到 Minikube Docker 环境
minikube docker-env | Invoke-Expression

# 2. 构建所有镜像
docker build -t cloudnative-go-api:v0.2 .
docker build -f Dockerfile.log-collector -t log-collector:v0.2 .
docker build -f Dockerfile.cleanup-job -t cleanup-job:v0.2 .

# 3. 部署 Redis (StatefulSet)
kubectl apply -f k8s/v0.2/redis/

# 4. 部署 API 服务 (Deployment)
kubectl apply -f k8s/v0.2/api/

# 5. 部署日志采集器 (DaemonSet)
kubectl apply -f k8s/v0.2/log-collector/

# 6. 部署清理任务 (CronJob)
kubectl apply -f k8s/v0.2/cleanup-job/

# 7. 查看所有服务
kubectl get all
```

详细部署指南：[k8s/v0.2/README.md](k8s/v0.2/README.md)

### 3. 测试和验证

```bash
# 获取 API Service 地址
minikube service api-service --url

# 或使用端口转发
kubectl port-forward service/api-service 8080:8080

# 测试 API 接口
curl http://localhost:8080/health
curl http://localhost:8080/api/v1/cache/test
curl http://localhost:8080/api/v1/config

# 查看 Redis 状态
kubectl exec -it redis-0 -- redis-cli ping

# 查看日志采集器
kubectl logs -l app=log-collector --tail=20

# 查看 CronJob
kubectl get cronjobs
```

详细步骤：
- [v0.1 部署指南](k8s/v0.1/README.md)
- [v0.2 部署指南](k8s/v0.2/README.md)

## 📚 API 接口

### v0.2 新增接口

```bash
# 缓存测试
GET /api/v1/cache/test       # 测试Redis连接并返回统计

# 配置信息
GET /api/v1/config           # 获取当前配置信息

# 数据操作
POST   /api/v1/data          # 创建数据（缓存到Redis）
GET    /api/v1/data/:key     # 获取数据
DELETE /api/v1/data/:key     # 删除数据
GET    /api/v1/data          # 列出所有键（pattern参数）

# 缓存统计
GET /api/v1/cache/stats      # 获取缓存命中率等统计
```

### v0.1 基础接口

```bash
# 健康检查
GET /health    # 存活探针（Liveness）
GET /ready     # 就绪探针（Readiness）

# 业务接口
GET /api/v1/hello?name=CloudNative    # 问候接口
GET /api/v1/info                      # 应用信息

# 监控接口
GET /metrics    # Prometheus 指标
```

## 🛠️ 开发指南

### 修改代码后重新部署

```bash
# 1. 修改代码
# 2. 重新构建镜像
docker build -t cloudnative-go-api:v0.1 .

# 3. 重新加载到 Minikube
minikube image load cloudnative-go-api:v0.1

# 4. 重启 Pod（触发拉取新镜像）
kubectl rollout restart deployment api-server

# 5. 查看状态
kubectl get pods -w
```

### 查看日志

```bash
# 查看所有 Pod 日志
kubectl logs -l app=api --tail=50 -f

# 查看特定 Pod 日志
kubectl logs <pod-name> -f
```

### 调试 Pod

```bash
# 进入 Pod
kubectl exec -it <pod-name> -- sh

# 端口转发
kubectl port-forward svc/api-service 8080:8080
```

## 📖 学习资源

### 文档目录

**v0.2 文档**
- [v0.2 学习目标](docs/v0.2/GOALS.md)
- [v0.2 架构设计](docs/v0.2/ARCHITECTURE.md)
- [v0.2 项目结构](docs/v0.2/PROJECT-STRUCTURE.md)
- [v0.2 部署指南](k8s/v0.2/README.md)

**v0.1 文档**
- [v0.1 学习目标](docs/v0.1/GOALS.md)
- [Kubernetes 基础知识](docs/v0.1/K8S-BASICS.md)
- [环境搭建指南](docs/v0.1/SETUP-ENVIRONMENT.md)
- [v0.1 部署指南](k8s/v0.1/README.md)

**技术博客**
- [v0.2 博客系列（5篇）](blog/v0.2/)
- [v0.1 博客系列（3篇）](blog/v0.1/)

### 推荐阅读

- [Docker 官方文档](https://docs.docker.com/)
- [Kubernetes 官方教程](https://kubernetes.io/zh-cn/docs/tutorials/)
- [Gin 框架文档](https://gin-gonic.com/docs/)
- [Prometheus 入门](https://prometheus.io/docs/introduction/overview/)

## 🗺️ 路线图

### ✅ v0.2 - 编排升级版（当前）
- StatefulSet（Redis 缓存服务）
- DaemonSet（日志采集器）
- CronJob（定时清理任务）
- ConfigMap 和 Secret
- 持久化存储（PVC/PV）

### ✅ v0.1 - 基础版（已完成）
- 容器化部署
- K8s 基础资源
- 健康检查和资源限制

### 🚧 v0.3 - 高级网络和监控（计划中）
- Ingress（统一入口）
- NetworkPolicy（网络隔离）
- Prometheus + Grafana（完整监控）
- HPA（水平自动扩缩容）

### 🔮 后续版本
- v0.3 - 弹性伸缩版（HPA）
- v0.4 - 服务治理版（Ingress + Istio）
- v0.5 - 配置管理版（Kustomize）
- v0.6 - 可观测性版（Prometheus + Grafana + Loki + Jaeger）
- v0.7 - CI/CD 版（GitHub Actions + ArgoCD）
- v1.0 - 完整版（微服务架构 + Istio 全栈）
- v1.5 - 边缘计算 AI 版（云边协同 + AI 推理）

详细规划：[cloudnative-go-journey-plan.md](cloudnative-go-journey-plan.md)

## 🤝 贡献指南

欢迎贡献！无论是：

- 🐛 报告 Bug
- 💡 提出新功能建议
- 📖 改进文档
- 🔧 提交代码

请查看 [CONTRIBUTING.md](CONTRIBUTING.md)

## 📜 开源协议

本项目采用 [MIT License](LICENSE)

## 💬 社区交流

- **GitHub Issues**: [提问和讨论](https://github.com/yourname/cloudnative-go-journey/issues)
- **GitHub Discussions**: [社区交流](https://github.com/yourname/cloudnative-go-journey/discussions)

## 🎉 致谢

感谢所有为云原生社区做出贡献的开发者！

---

**⭐ 如果这个项目对你有帮助，请给个 Star！**

Made with ❤️ by CloudNative Community
