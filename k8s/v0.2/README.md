# CloudNative Go Journey v0.2 部署指南

> 编排升级版 - 多工作负载类型实战

---

## 📋 架构概览

```
┌────────────────────────────────────────────────┐
│            Minikube 集群                        │
│                                                │
│  ┌─────────────┐        ┌──────────────┐       │
│  │ API Pods    │───────▶│ Redis Pod    │       │
│  │ (Deployment)│        │(StatefulSet) │       │
│  └─────────────┘        └──────────────┘       │
│        ↑                        ↑              │
│        │                        │              │
│   NodePort:30080         PVC (持久化)          │
│                                                │
│  ┌──────────────────────────────────┐          │
│  │ Log Collector (DaemonSet)        │          │
│  │ 每个节点一个 Pod                 │          │
│  └──────────────────────────────────┘          │
│                                                │
│  ┌──────────────────────────────────┐          │
│  │ Cleanup Job (CronJob)            │          │
│  │ 每小时执行一次                    │          │
│  └──────────────────────────────────┘          │
└────────────────────────────────────────────────┘
```

---

## 🚀 快速开始

### 前置要求

- ✅ Minikube 已安装并运行
- ✅ kubectl 已配置
- ✅ Docker 已安装

### 1. 构建镜像

```bash
# 切换到 Minikube 的 Docker 环境
minikube docker-env | Invoke-Expression

# 构建 API 服务镜像
docker build -t cloudnative-go-api:v0.2 .

# 构建日志采集器镜像
docker build -f Dockerfile.log-collector -t log-collector:v0.2 .

# 构建清理任务镜像
docker build -f Dockerfile.cleanup-job -t cleanup-job:v0.2 .

# 验证镜像
docker images | Select-String "v0.2"
```

### 2. 部署到 Kubernetes

```bash
# 部署顺序很重要！

# 1. 先部署 Redis（其他服务依赖它）
kubectl apply -f k8s/v0.2/redis/

# 等待 Redis 就绪
kubectl wait --for=condition=ready pod -l app=redis --timeout=60s

# 2. 部署 API 服务
kubectl apply -f k8s/v0.2/api/

# 等待 API 就绪
kubectl wait --for=condition=ready pod -l app=api --timeout=60s

# 3. 部署日志采集器（DaemonSet）
kubectl apply -f k8s/v0.2/log-collector/

# 4. 部署清理任务（CronJob）
kubectl apply -f k8s/v0.2/cleanup-job/
```

### 3. 验证部署

```bash
# 查看所有资源
kubectl get all

# 查看 Pods
kubectl get pods -o wide

# 查看 StatefulSet
kubectl get statefulset

# 查看 DaemonSet
kubectl get daemonset

# 查看 CronJob
kubectl get cronjob

# 查看 PVC（持久化卷声明）
kubectl get pvc
```

---

## 🧪 功能测试

### 1. 测试 API 服务

```bash
# 获取 Minikube IP
$MINIKUBE_IP = minikube ip

# 测试健康检查
curl http://${MINIKUBE_IP}:30080/health

# 测试 Redis 连接
curl http://${MINIKUBE_IP}:30080/api/v1/cache/test

# 查看配置
curl http://${MINIKUBE_IP}:30080/api/v1/config

# 创建数据
curl -X POST http://${MINIKUBE_IP}:30080/api/v1/data `
  -H "Content-Type: application/json" `
  -d '{"key":"test:user:1","value":"John Doe","ttl":3600}'

# 获取数据
curl http://${MINIKUBE_IP}:30080/api/v1/data/test:user:1

# 查看缓存统计
curl http://${MINIKUBE_IP}:30080/api/v1/cache/stats
```

### 2. 验证 Redis 持久化

```bash
# 连接到 Redis Pod
kubectl exec -it redis-0 -- redis-cli

# 在 Redis 中操作
127.0.0.1:6379> SET mykey "Hello v0.2"
127.0.0.1:6379> GET mykey
127.0.0.1:6379> exit

# 删除 Redis Pod
kubectl delete pod redis-0

# 等待 Pod 重建
kubectl wait --for=condition=ready pod redis-0 --timeout=60s

# 再次连接，验证数据还在
kubectl exec -it redis-0 -- redis-cli GET mykey
# 应该输出: "Hello v0.2"
```

### 3. 查看日志采集器

```bash
# 查看 DaemonSet Pod
kubectl get pods -l app=log-collector -o wide

# 查看日志
kubectl logs -l app=log-collector --tail=50

# 查看指标
kubectl port-forward <log-collector-pod-name> 8081:8080
# 访问 http://localhost:8081/metrics
```

### 4. 测试清理任务

```bash
# 查看 CronJob
kubectl get cronjob

# 手动触发一次清理任务
kubectl create job --from=cronjob/cleanup-job manual-cleanup-1

# 查看 Job 状态
kubectl get jobs

# 查看 Job 日志
kubectl logs job/manual-cleanup-1

# 清理手动创建的 Job
kubectl delete job manual-cleanup-1
```

---

## 📊 监控和调试

### 查看日志

```bash
# API 服务日志
kubectl logs -l app=api --tail=100 -f

# Redis 日志
kubectl logs redis-0 --tail=100 -f

# 日志采集器日志
kubectl logs -l app=log-collector --tail=50

# CronJob 最近执行的日志
kubectl logs -l app=cleanup-job --tail=50
```

### 查看资源使用

```bash
# 查看 Pod 资源使用
kubectl top pods

# 查看 Node 资源使用
kubectl top nodes

# 查看 PVC 使用情况
kubectl get pvc
kubectl describe pvc redis-data-redis-0
```

### 进入容器调试

```bash
# 进入 API Pod
kubectl exec -it <api-pod-name> -- sh

# 进入 Redis Pod
kubectl exec -it redis-0 -- sh

# 进入日志采集器 Pod
kubectl exec -it <log-collector-pod-name> -- sh
```

---

## 🔧 常见问题

### Redis Pod 启动失败

```bash
# 查看详细信息
kubectl describe pod redis-0

# 查看 PVC 状态
kubectl get pvc
kubectl describe pvc redis-data-redis-0

# 查看 StorageClass
kubectl get storageclass
```

### API 无法连接 Redis

```bash
# 检查 Service
kubectl get svc redis-service
kubectl describe svc redis-service

# 测试 DNS 解析
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup redis-service

# 检查网络连接
kubectl run -it --rm debug --image=busybox --restart=Never -- telnet redis-service 6379
```

### DaemonSet 没有在所有节点部署

```bash
# 查看节点
kubectl get nodes

# 查看节点污点
kubectl describe nodes | Select-String -Pattern "Taints"

# 查看 DaemonSet 详情
kubectl describe daemonset log-collector
```

### CronJob 没有执行

```bash
# 查看 CronJob 详情
kubectl describe cronjob cleanup-job

# 查看最近的 Jobs
kubectl get jobs

# 手动触发测试
kubectl create job --from=cronjob/cleanup-job test-run
kubectl logs job/test-run
```

---

## 🧹 清理资源

```bash
# 删除所有 v0.2 资源
kubectl delete -f k8s/v0.2/cleanup-job/
kubectl delete -f k8s/v0.2/log-collector/
kubectl delete -f k8s/v0.2/api/
kubectl delete -f k8s/v0.2/redis/

# 清理 PVC（数据会丢失！）
kubectl delete pvc --all

# 验证清理
kubectl get all
```

---

## 📚 学习要点

### 通过 v0.2 你学会了：

1. ✅ **StatefulSet** - 部署有状态应用（Redis）
2. ✅ **PV/PVC** - 数据持久化
3. ✅ **Headless Service** - 稳定的网络标识
4. ✅ **DaemonSet** - 每个节点部署
5. ✅ **CronJob** - 定时任务
6. ✅ **ConfigMap** - 配置管理
7. ✅ **多工作负载协同** - 完整的微服务架构

---

## 🎯 下一步

- 查看 Prometheus 指标
- 尝试扩缩容 API 服务
- 修改 CronJob 调度时间
- 添加更多业务功能

**恭喜完成 v0.2！** 🎉

