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

## 🎯 当前版本：v0.1 - 基础版

### v0.1 学习目标

- ✅ 理解容器化的本质
- ✅ 掌握多阶段 Dockerfile 构建
- ✅ 理解 K8s Deployment 和 Service
- ✅ 配置健康检查和资源限制
- ✅ 本地 Minikube 部署和访问

### 技术栈

- **语言**: Go 1.21+
- **框架**: Gin
- **监控**: Prometheus
- **容器**: Docker
- **编排**: Kubernetes (Minikube)

### 项目结构

```
cloudnative-go-journey/
├── src/                    # Go 源码
│   ├── main.go            # 主入口
│   ├── config/            # 配置管理
│   ├── handler/           # HTTP 处理器
│   ├── middleware/        # 中间件
│   └── metrics/           # Prometheus 指标
├── k8s/                   # K8s 配置
│   └── v0.1/
│       ├── deployment.yaml
│       ├── service.yaml
│       └── README.md      # 部署指南
├── docs/                  # 文档
│   └── v0.1/
│       ├── GOALS.md       # 学习目标
│       ├── K8S-BASICS.md  # K8s 基础知识
│       └── SETUP-ENVIRONMENT.md
├── scripts/               # 自动化脚本
├── Dockerfile             # 多阶段构建
├── go.mod                 # Go 依赖
└── README.md              # 本文件
```

## 🚀 快速开始

### 1. 环境准备

确保已安装：
- Go 1.21+
- Docker Desktop
- kubectl
- Minikube

详细安装指南：[docs/v0.1/SETUP-ENVIRONMENT.md](docs/v0.1/SETUP-ENVIRONMENT.md)

### 2. 本地运行

```bash
# 克隆项目
git clone https://github.com/yourname/cloudnative-go-journey.git
cd cloudnative-go-journey

# 下载依赖
go mod tidy

# 运行服务
go run src/main.go

# 测试接口
curl http://localhost:8080/health
curl http://localhost:8080/api/v1/hello
```

### 3. Docker 部署

```bash
# 构建镜像
docker build -t cloudnative-go-api:v0.1 .

# 运行容器
docker run -p 8080:8080 cloudnative-go-api:v0.1

# 测试
curl http://localhost:8080/health
```

### 4. Kubernetes 部署

```bash
# 启动 Minikube
minikube start

# 加载镜像
minikube image load cloudnative-go-api:v0.1

# 部署到 K8s
kubectl apply -f k8s/v0.1/

# 访问服务
minikube service api-service
```

详细步骤：[k8s/v0.1/README.md](k8s/v0.1/README.md)

## 📚 API 接口

### 健康检查

```bash
GET /health    # 存活探针（Liveness）
GET /ready     # 就绪探针（Readiness）
```

### 业务接口

```bash
GET /api/v1/hello?name=CloudNative    # 问候接口
GET /api/v1/info                      # 应用信息
```

### 监控接口

```bash
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

- [v0.1 学习目标](docs/v0.1/GOALS.md)
- [Kubernetes 基础知识](docs/v0.1/K8S-BASICS.md)
- [环境搭建指南](docs/v0.1/SETUP-ENVIRONMENT.md)
- [部署指南](k8s/v0.1/README.md)

### 推荐阅读

- [Docker 官方文档](https://docs.docker.com/)
- [Kubernetes 官方教程](https://kubernetes.io/zh-cn/docs/tutorials/)
- [Gin 框架文档](https://gin-gonic.com/docs/)
- [Prometheus 入门](https://prometheus.io/docs/introduction/overview/)

## 🗺️ 路线图

### ✅ v0.1 - 基础版（当前）
- 容器化部署
- K8s 基础资源
- 健康检查和资源限制

### 🚧 v0.2 - 编排升级版（计划中）
- StatefulSet（Redis）
- DaemonSet（日志采集）
- CronJob（定时任务）
- ConfigMap 和 Secret

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
