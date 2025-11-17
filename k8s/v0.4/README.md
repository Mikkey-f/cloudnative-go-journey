# v0.4 Kubernetes 配置文件

> v0.4 版本的所有 Kubernetes 配置文件

## 📂 目录结构

```
k8s/v0.4/
├── ingress/
│   ├── ingress.yaml       # Ingress 配置
│   └── README.md
├── istio/
│   ├── virtual-service.yaml      # VirtualService 配置
│   ├── destination-rule.yaml     # DestinationRule 配置
│   └── README.md
├── frontend/
│   ├── deployment.yaml    # 前端 Deployment
│   ├── service.yaml       # 前端 Service
│   └── README.md
├── api/
│   ├── deployment-v1.yaml # API v1 Deployment
│   ├── deployment-v2.yaml # API v2 Deployment
│   ├── service.yaml       # API Service
│   └── README.md
└── README.md              # 本文件
```

## 🚀 快速部署

### 方式 1: 一键部署所有组件

```bash
bash scripts/v0.4/deploy-all.sh
```

### 方式 2: 分步部署

```bash
# 1. 部署前端服务
kubectl apply -f k8s/v0.4/frontend/deployment.yaml
kubectl apply -f k8s/v0.4/frontend/service.yaml

# 2. 部署 API v1 和 v2
kubectl apply -f k8s/v0.4/api/deployment-v1.yaml
kubectl apply -f k8s/v0.4/api/deployment-v2.yaml
kubectl apply -f k8s/v0.4/api/service.yaml

# 3. 部署 Ingress
kubectl apply -f k8s/v0.4/ingress/ingress.yaml

# 4. 部署 Istio 配置
kubectl apply -f k8s/v0.4/istio/virtual-service.yaml
kubectl apply -f k8s/v0.4/istio/destination-rule.yaml
```

## 📋 配置文件说明

### Ingress 配置

**文件**: `ingress/ingress.yaml`

- 配置外部流量入口
- 基于路径的路由: `/api` → api-service, `/` → frontend-service
- 支持域名: `app.local`

### VirtualService 配置

**文件**: `istio/virtual-service.yaml`

- 定义流量路由规则
- 90% 流量到 v1，10% 流量到 v2
- 支持超时和重试

### DestinationRule 配置

**文件**: `istio/destination-rule.yaml`

- 定义子集 (v1 和 v2)
- 配置连接池
- 配置熔断检测

### 前端 Deployment

**文件**: `frontend/deployment.yaml`

- 1 个副本
- 使用 api:latest 镜像
- 健康检查配置

### API v1 Deployment

**文件**: `api/deployment-v1.yaml`

- 5 个副本（对称设计）
- 标签: version=v1
- API_VERSION=v1 环境变量
- 流量分配: 90%（由 VirtualService 控制）

### API v2 Deployment

**文件**: `api/deployment-v2.yaml`

- 5 个副本（对称设计）
- 标签: version=v2
- API_VERSION=v2 环境变量
- 流量分配: 10%（由 VirtualService 控制）

### API Service

**文件**: `api/service.yaml`

- 同时选择 v1 和 v2 Pod
- ClusterIP 类型
- 端口 8080

## 🔍 验证部署

### 检查 Pod 状态

```bash
# 查看所有 Pod
kubectl get pods

# 查看前端 Pod
kubectl get pods -l app=frontend

# 查看 API Pod
kubectl get pods -l app=api

# 查看 Pod 详情
kubectl describe pod <pod-name>
```

### 检查 Service

```bash
# 查看所有 Service
kubectl get svc

# 查看 Service 详情
kubectl describe svc frontend-service
kubectl describe svc api-service
```

### 检查 Ingress

```bash
# 查看 Ingress
kubectl get ingress

# 查看 Ingress 详情
kubectl describe ingress app-ingress
```

### 检查 Istio 配置

```bash
# 查看 VirtualService
kubectl get virtualservices

# 查看 DestinationRule
kubectl get destinationrules

# 查看详情
kubectl describe vs api-vs
kubectl describe dr api-dr
```

## 🧪 测试部署

### 配置本地 hosts

```bash
# 编辑 /etc/hosts (Linux/Mac) 或 C:\Windows\System32\drivers\etc\hosts (Windows)
127.0.0.1 app.local
```

### 测试前端

```bash
curl http://app.local/
```

### 测试 API

```bash
# 测试 hello 接口
curl http://app.local/api/v1/hello

# 测试版本接口
curl http://app.local/api/v1/version

# 多次测试，观察版本分配
for i in {1..10}; do curl http://app.local/api/v1/version; echo ""; done
```

### 验证流量分配

```bash
bash scripts/v0.4/traffic-verify.sh
```

## 🔧 常见操作

### 查看 Pod 日志

```bash
# 查看前端 Pod 日志
kubectl logs -l app=frontend

# 查看 API v1 Pod 日志
kubectl logs -l app=api,version=v1

# 实时查看日志
kubectl logs -f <pod-name>
```

### 进入 Pod 执行命令

```bash
kubectl exec -it <pod-name> -- /bin/sh
```

### 删除部署

```bash
# 删除所有 v0.4 资源
kubectl delete -f k8s/v0.4/

# 或分别删除
kubectl delete deployment frontend
kubectl delete deployment api-v1
kubectl delete deployment api-v2
kubectl delete svc frontend-service
kubectl delete svc api-service
kubectl delete ingress app-ingress
kubectl delete vs api-vs
kubectl delete dr api-dr
```

### 更新部署

```bash
# 修改副本数
kubectl scale deployment api-v1 --replicas=5

# 更新镜像
kubectl set image deployment/api-v1 api=api:v1.1

# 重启 Pod
kubectl rollout restart deployment/api-v1
```

## 📊 架构图

```
┌─────────────────────────────────────────┐
│           外部用户                      │
└────────────────┬────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│    Ingress (app-ingress)                │
│  ├─ /api → api-service                  │
│  └─ /    → frontend-service             │
└────────────────┬────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│         K8s Service                     │
│  ├─ frontend-service                    │
│  └─ api-service                         │
└────────────────┬────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│      Istio VirtualService + DR          │
│  ├─ 90% → api-v1 (9 个 Pod)            │
│  └─ 10% → api-v2 (1 个 Pod)            │
└────────────────┬────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│           实际 Pod                      │
│  ├─ frontend-1                          │
│  ├─ api-v1-1 ~ api-v1-9                │
│  └─ api-v2-1                            │
└─────────────────────────────────────────┘
```

## 📚 相关文档

- [DEPLOYMENT-GUIDE.md](../../docs/v0.4/DEPLOYMENT-GUIDE.md) - 完整部署指南
- [TROUBLESHOOTING.md](../../docs/v0.4/TROUBLESHOOTING.md) - 故障排查
- [scripts/v0.4/README.md](../../scripts/v0.4/README.md) - 脚本说明

---

**提示**: 所有配置文件都包含详细的注释，便于理解和修改。
