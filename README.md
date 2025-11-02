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

## 🎯 当前版本：v0.3 - 弹性伸缩版

### v0.3 学习目标

- ✅ 掌握 Kubernetes HPA（自动弹性伸缩）
- ✅ 安装和配置 Metrics Server
- ✅ 理解资源管理（Requests/Limits）
- ✅ 使用 k6 进行专业性能测试
- ✅ 分析和优化性能指标（P50/P95/P99）
- ✅ 诊断和解决生产问题（OOM、CrashLoopBackOff）
- ✅ 达到生产级别性能标准（100% 成功率，P95 < 1s）

### v0.2 学习目标（已完成）

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
- **监控**: Prometheus + Metrics Server
- **弹性伸缩**: HPA (autoscaling/v2)
- **性能测试**: k6 v0.48.0
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
│   │   └── workload.go    # 负载测试接口（v0.3）
│   ├── middleware/        # 中间件
│   ├── metrics/           # Prometheus 指标
│   ├── log-collector/     # 日志采集器
│   └── cleanup-job/       # 清理任务
├── k8s/                   # K8s 配置
│   ├── v0.1/              # v0.1 配置
│   ├── v0.2/              # v0.2 配置
│   │   ├── api/           # API 服务
│   │   ├── redis/         # Redis StatefulSet
│   │   ├── log-collector/ # DaemonSet
│   │   └── cleanup-job/   # CronJob
│   └── v0.3/              # v0.3 配置
│       └── api/           # API 服务 + HPA
├── k6-tests/              # k6 压测脚本（v0.3）
│   └── hpa-test.js        # HPA 负载测试
├── docs/                  # 文档
│   ├── v0.1/              # v0.1 文档
│   ├── v0.2/              # v0.2 文档
│   └── v0.3/              # v0.3 文档
├── blog/                  # 技术博客
│   ├── v0.1/              # v0.1 博客（3篇）
│   ├── v0.2/              # v0.2 博客（5篇）
│   └── v0.3/              # v0.3 博客（3篇）
├── scripts/               # 自动化脚本
│   ├── deploy-v0.2.ps1    # v0.2 部署
│   └── deploy-v0.3.ps1    # v0.3 部署
├── Dockerfile             # API 服务镜像
├── Dockerfile.log-collector  # 日志采集器镜像
├── Dockerfile.cleanup-job    # 清理任务镜像
├── go.mod                 # Go 依赖
├── CHANGELOG.md           # 更新日志
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

### 2. 快速部署 v0.3

```bash
# 克隆项目
git clone https://github.com/yourname/cloudnative-go-journey.git
cd cloudnative-go-journey

# 使用自动化脚本部署 v0.3（推荐）
.\scripts\deploy-v0.3.ps1
```

**或手动部署：**

```bash
# 1. 安装 Metrics Server（如果未安装）
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# 2. 切换到 Minikube Docker 环境
minikube docker-env | Invoke-Expression

# 3. 构建镜像
docker build -t cloudnative-api:v0.3 .

# 4. 部署服务（包括 HPA）
kubectl apply -f k8s/v0.3/api/deployment.yaml
kubectl apply -f k8s/v0.3/api/service.yaml
kubectl apply -f k8s/v0.3/api/hpa.yaml

# 5. 部署 Redis（如需要）
kubectl apply -f k8s/v0.2/redis/

# 5. 部署日志采集器 (DaemonSet)
kubectl apply -f k8s/v0.2/log-collector/

# 6. 部署清理任务 (CronJob)
kubectl apply -f k8s/v0.2/cleanup-job/

# 7. 查看所有服务
kubectl get all
```

详细部署指南：[k8s/v0.3/README.md](k8s/v0.3/README.md)

### 3. 测试和验证

```bash
# 获取 API Service 地址
minikube service cloudnative-api-service --url

# 测试基本接口
curl http://localhost:8080/health
curl http://localhost:8080/api/v1/hello

# 测试负载接口（v0.3 新增）
curl "http://localhost:8080/api/v1/workload/cpu?iterations=10000000"
curl "http://localhost:8080/api/v1/workload/memory?size=50&duration=3"

# 查看 HPA 状态
kubectl get hpa cloudnative-api-hpa
kubectl describe hpa cloudnative-api-hpa

# 查看 Pod 资源使用
kubectl top pods -l app=cloudnative-api

# 运行 k6 压测（需要先安装 k6）
k6 run k6-tests/hpa-test.js
```

详细步骤：
- [v0.1 部署指南](k8s/v0.1/README.md)
- [v0.2 部署指南](k8s/v0.2/README.md)
- [v0.3 部署指南](k8s/v0.3/README.md)

## 📚 API 接口

### v0.3 新增接口（负载测试）

```bash
# CPU 密集型负载
GET /api/v1/workload/cpu?iterations=10000000    # CPU 密集型任务

# 内存密集型负载
GET /api/v1/workload/memory?size=50&duration=3  # 内存密集型任务

# 混合负载
GET /api/v1/workload?type=mixed&intensity=50    # 混合负载任务
```

### v0.2 接口

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

**v0.3 文档（当前）**
- [v0.3 总览](docs/v0.3/README.md)
- [v0.3 学习目标](docs/v0.3/GOALS.md)
- [v0.3 架构设计](docs/v0.3/ARCHITECTURE.md)
- [v0.3 项目结构](docs/v0.3/PROJECT-STRUCTURE.md)
- [v0.3 部署指南](docs/v0.3/DEPLOYMENT-GUIDE.md)
- [v0.3 知识评估](docs/v0.3/ASSESSMENT.md)
- [v0.3 部署配置](k8s/v0.3/README.md)

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
- [v0.3 博客系列（3篇）](blog/v0.3/) - 弹性伸缩与性能测试
- [v0.2 博客系列（5篇）](blog/v0.2/) - 工作负载与配置管理
- [v0.1 博客系列（3篇）](blog/v0.1/) - 容器化与基础部署

### 推荐阅读

- [Kubernetes HPA 官方文档](https://kubernetes.io/zh-cn/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Metrics Server 官方仓库](https://github.com/kubernetes-sigs/metrics-server)
- [k6 性能测试文档](https://k6.io/docs/)
- [Docker 官方文档](https://docs.docker.com/)
- [Kubernetes 官方教程](https://kubernetes.io/zh-cn/docs/tutorials/)
- [Gin 框架文档](https://gin-gonic.com/docs/)
- [Prometheus 入门](https://prometheus.io/docs/introduction/overview/)

## 🗺️ 路线图

### ✅ v0.3 - 弹性伸缩版（当前）
- HorizontalPodAutoscaler（自动扩缩容）
- Metrics Server（资源指标收集）
- 负载测试接口（CPU/内存密集型）
- k6 专业性能测试
- 性能优化（资源配置、探针调优）
- 生产级别性能标准（100% 成功率）

### ✅ v0.2 - 编排升级版（已完成）
- StatefulSet（Redis 缓存服务）
- DaemonSet（日志采集器）
- CronJob（定时清理任务）
- ConfigMap 和 Secret
- 持久化存储（PVC/PV）

### ✅ v0.1 - 基础版（已完成）
- 容器化部署
- K8s 基础资源
- 健康检查和资源限制

### 🚧 v0.4 - 服务治理版（计划中）
- Ingress Controller（统一入口）
- Istio 服务网格基础
- 金丝雀发布

### 🔮 后续版本
- v0.5 - 可观测性版（Prometheus + Grafana + Loki）
- v0.6 - 配置管理版（Kustomize 多环境）
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

## 🏆 v0.3 性能成果

### 压测结果（生产级别）
- **总请求数**: 3186
- **成功率**: 100% ⭐⭐⭐⭐⭐
- **失败率**: 0% ⭐⭐⭐⭐⭐
- **P50 响应时间**: 48.86ms
- **P95 响应时间**: 983ms ⭐⭐⭐⭐⭐
- **P99 响应时间**: ~1.1s

### HPA 表现
- **扩容延迟**: ~45 秒 ⭐⭐⭐⭐⭐
- **缩容延迟**: ~6 分钟（含稳定窗口）
- **Pod 重启次数**: 0 ⭐⭐⭐⭐⭐
- **OOMKilled 次数**: 0 ⭐⭐⭐⭐⭐

**结论**: ✅ 达到生产级别性能标准，超越行业标准！

详见: [v0.3 压测报告](blog/v0.3/11-load-testing-hpa-validation.md)

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
