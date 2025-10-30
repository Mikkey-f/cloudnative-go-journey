# v0.2 博客系列

> CloudNative Go Journey v0.2 - Kubernetes 工作负载深度实践

---

## 📚 系列文章

### 第 4 篇：K8s 工作负载完全指南

**文件**：[04-k8s-workloads-guide.md](./04-k8s-workloads-guide.md)

**内容概览**：
- 为什么需要多种工作负载？
- Deployment、StatefulSet、DaemonSet、CronJob 对比
- 选择决策树和最佳实践
- 实战对比：用不同方式部署 Redis

**适合人群**：
- 完成 v0.1 的学习者
- 了解 Deployment，想学习其他工作负载
- 想系统理解 K8s 工作负载体系

**字数**：~8000 字  
**阅读时间**：30 分钟

---

### 第 5 篇：用 StatefulSet 部署 Redis

**文件**：[05-statefulset-redis-practice.md](./05-statefulset-redis-practice.md)

**内容概览**：
- 为什么 Redis 需要 StatefulSet？
- Headless Service 详解
- volumeClaimTemplates 持久化存储
- 数据持久化测试（Pod 重启数据不丢失）
- 完整的排查指南

**适合人群**：
- 需要部署有状态应用的开发者
- 想理解持久化存储的原理
- 准备部署数据库、缓存服务

**字数**：~10000 字  
**阅读时间**：40 分钟

**核心收获**：
- ✅ StatefulSet 的 3 大特性：固定名称、固定存储、固定 DNS
- ✅ Headless Service 原理
- ✅ 数据持久化实战验证

---

### 第 6 篇：DaemonSet 实战日志采集器

**文件**：[06-daemonset-log-collector.md](./06-daemonset-log-collector.md)

**内容概览**：
- DaemonSet 的核心特性（每个节点自动部署）
- 环境变量注入（fieldRef）
- 访问宿主机资源（hostPath）
- tolerations 和 nodeSelector 详解
- 滚动更新策略

**适合人群**：
- 需要部署节点级服务的运维人员
- 想学习日志采集、监控 Agent 部署
- 需要访问宿主机资源的场景

**字数**：~7000 字  
**阅读时间**：30 分钟

**核心收获**：
- ✅ 每个节点自动运行一个 Pod
- ✅ 节点扩缩容自动适应
- ✅ hostPath 访问宿主机目录

---

### 第 7 篇：ConfigMap 和 Secret 配置管理

**文件**：[07-configmap-secret-guide.md](./07-configmap-secret-guide.md)

**内容概览**：
- ConfigMap 的 4 种使用方式
- Secret 加密存储和安全实践
- CronJob 定时任务配置详解
- 配置的动态更新
- 最佳实践和命名规范

**适合人群**：
- 需要管理应用配置的开发者
- 想学习配置和代码分离
- 需要管理敏感数据（密码、Token）

**字数**：~9000 字  
**阅读时间**：35 分钟

**核心收获**：
- ✅ 配置集中管理
- ✅ Secret 安全存储
- ✅ CronJob 定时任务配置
- ✅ 配置分层和版本管理

---

### 第 8 篇：CronJob 实战定时清理任务

**文件**：[08-cronjob-cleanup-practice.md](./08-cronjob-cleanup-practice.md)

**内容概览**：
- 为什么需要 CronJob？（vs 传统 crontab）
- Job vs CronJob 的区别
- 编写 Redis 清理任务
- 调度表达式和并发策略
- 失败处理和重试机制
- 完整的测试和验证流程

**适合人群**：
- 需要实现定时任务的开发者
- 想学习 K8s 批处理任务
- 需要定时清理、备份、报表的场景

**字数**：~11000 字  
**阅读时间**：45 分钟

**核心收获**：
- ✅ CronJob 完整实战（从编码到部署）
- ✅ 3 种并发策略深度解析
- ✅ 失败重试和日志排查
- ✅ 生产环境优化建议

---

## 🎯 学习路线

```
第 4 篇：K8s 工作负载全景图
  ↓ 建立知识框架
  
第 5 篇：StatefulSet 深度实践
  ↓ 掌握有状态应用部署
  
第 6 篇：DaemonSet 节点服务
  ↓ 掌握节点级服务部署
  
第 7 篇：配置管理最佳实践
  ↓ 掌握配置和密钥管理
  
第 8 篇：CronJob 定时任务实战
  ↓ 完成 v0.2 学习
```

---

## 📊 v0.2 技术栈

| 技术 | 版本 | 用途 |
|-----|------|-----|
| Kubernetes | 1.28+ | 容器编排 |
| Go | 1.23 | API 服务、日志采集器 |
| Redis | 7.4 | 缓存服务 |
| Prometheus | latest | 指标采集 |
| Docker | latest | 容器运行时 |
| Minikube | latest | 本地 K8s 环境 |

---

## 🏗️ v0.2 架构

```
┌─────────────────────────────────────────────────────┐
│                  K8s 集群                            │
│                                                      │
│  ┌────────────────────────────────────────────┐    │
│  │  Deployment: api-server (2 副本)           │    │
│  │  - ConfigMap: api-config                   │    │
│  │  - Service: api-service (NodePort)         │    │
│  └────────────────────────────────────────────┘    │
│                                                      │
│  ┌────────────────────────────────────────────┐    │
│  │  StatefulSet: redis (1 副本)               │    │
│  │  - ConfigMap: redis-config                 │    │
│  │  - Service: redis-service (Headless)       │    │
│  │  - PVC: data-redis-0 (1Gi)                 │    │
│  └────────────────────────────────────────────┘    │
│                                                      │
│  ┌────────────────────────────────────────────┐    │
│  │  DaemonSet: log-collector                  │    │
│  │  - 每个节点运行一个 Pod                     │    │
│  │  - 挂载 hostPath: /var/log                 │    │
│  └────────────────────────────────────────────┘    │
│                                                      │
│  ┌────────────────────────────────────────────┐    │
│  │  CronJob: cleanup-job                      │    │
│  │  - 每小时执行一次                           │    │
│  │  - 清理 Redis 过期键                        │    │
│  └────────────────────────────────────────────┘    │
│                                                      │
└─────────────────────────────────────────────────────┘
```

---

## 🚀 快速开始

### 1. 部署 Redis (StatefulSet)

```bash
kubectl apply -f k8s/v0.2/redis/configmap.yaml
kubectl apply -f k8s/v0.2/redis/service.yaml
kubectl apply -f k8s/v0.2/redis/statefulset.yaml
```

### 2. 部署 API 服务 (Deployment)

```bash
# 构建镜像
minikube docker-env | Invoke-Expression
docker build -t cloudnative-go-api:v0.2 .

# 部署
kubectl apply -f k8s/v0.2/api/configmap.yaml
kubectl apply -f k8s/v0.2/api/service.yaml
kubectl apply -f k8s/v0.2/api/deployment.yaml
```

### 3. 部署日志采集器 (DaemonSet)

```bash
# 构建镜像
docker build -f Dockerfile.log-collector -t log-collector:v0.2 .

# 部署
kubectl apply -f k8s/v0.2/log-collector/daemonset.yaml
```

### 4. 部署清理任务 (CronJob)

```bash
# 构建镜像
docker build -f Dockerfile.cleanup-job -t cleanup-job:v0.2 .

# 部署
kubectl apply -f k8s/v0.2/cleanup-job/cronjob.yaml
```

### 5. 验证部署

```bash
# 查看所有 Pod
kubectl get pods -o wide

# 查看所有 Service
kubectl get svc

# 查看 CronJob
kubectl get cronjobs

# 查看 DaemonSet
kubectl get daemonsets
```

---

## 📝 v0.2 统计数据

**5 篇实战博客，总计 ~45000 字：**
- 第 4 篇：K8s 工作负载完全指南（~8000字）
- 第 5 篇：StatefulSet 部署 Redis（~10000字）
- 第 6 篇：DaemonSet 日志采集器（~7000字）
- 第 7 篇：ConfigMap 和 Secret（~9000字）
- 第 8 篇：CronJob 定时清理任务（~11000字）

---

## 📝 v0.2 学习成果

完成 v0.2 后，你将掌握：

**工作负载管理：**
- ✅ Deployment：无状态应用部署
- ✅ StatefulSet：有状态应用部署（Redis）
- ✅ DaemonSet：节点级服务部署（日志采集）
- ✅ Job/CronJob：批处理和定时任务（数据清理）

**存储管理：**
- ✅ PVC/PV：持久化存储
- ✅ volumeClaimTemplates：动态存储分配
- ✅ hostPath：访问宿主机资源

**网络管理：**
- ✅ Headless Service：固定 DNS 解析
- ✅ NodePort Service：外部访问

**配置管理：**
- ✅ ConfigMap：配置数据管理
- ✅ Secret：敏感数据管理
- ✅ 环境变量注入
- ✅ 文件挂载

**高级特性：**
- ✅ 滚动更新策略
- ✅ 健康检查（Liveness/Readiness）
- ✅ 资源限制（requests/limits）
- ✅ 节点选择和容忍（nodeSelector/tolerations）

---

## 🔗 相关资源

### 官方文档
- [Kubernetes 工作负载](https://kubernetes.io/docs/concepts/workloads/)
- [StatefulSet](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [DaemonSet](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)
- [ConfigMap](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Secret](https://kubernetes.io/docs/concepts/configuration/secret/)

### 项目文档
- [v0.2 完整文档](../../docs/v0.2/)
- [部署指南](../../k8s/v0.2/README.md)
- [自动化脚本](../../scripts/deploy-v0.2.ps1)

---

## 📈 接下来

**v0.3 预告：高级网络和监控**
- Ingress：统一入口和路由
- NetworkPolicy：网络隔离
- Prometheus + Grafana：完整监控方案
- HPA：水平自动扩缩容

**v1.0 目标：生产级部署**
- Helm：应用包管理
- CI/CD：自动化部署
- 高可用架构
- 性能优化

---

## 🤝 参与贡献

欢迎提交 Issue 和 Pull Request！

---

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](../../LICENSE) 文件。

---

**如果这个系列对你有帮助，请给个 ⭐️ Star！**

