# v0.5 - K8s 配置管理

> 基于 Viper + ConfigMap + Kustomize 的企业级配置管理

## 📁 目录结构

```
k8s/v0.5/
├── base/                          # 基础配置（通用模板）
│   ├── kustomization.yaml         # 基础 Kustomize 配置
│   ├── deployment.yaml            # Deployment 模板
│   ├── service.yaml               # Service 模板
│   └── configmap.yaml             # ConfigMap 模板
└── overlays/                      # 环境特定覆盖配置
    ├── dev/
    │   ├── kustomization.yaml     # Dev 环境主配置
    │   ├── config.yaml            # 应用配置文件内容
    │   └── deployment-patch.yaml  # Deployment 补丁（副本数、资源配额）
    ├── staging/
    │   ├── kustomization.yaml
    │   ├── config.yaml
    │   └── deployment-patch.yaml
    └── prod/
        ├── kustomization.yaml
        ├── config.yaml
        └── deployment-patch.yaml
```

## 🎯 配置说明

### Base（基础配置）
- 定义所有环境通用的资源模板
- 包含通用标签、命名空间等
- **不要直接修改 base，而是通过 overlay 覆盖**

### Overlays（环境覆盖）

每个环境包含 3 个文件：

**1. kustomization.yaml**（主配置）
- **namePrefix**：环境前缀（dev-、staging-、prod-）
- **labels**：环境标签（env: dev/staging/prod）
- **configMapGenerator**：从 config.yaml 生成 ConfigMap
- **patches**：引用 deployment-patch.yaml

**2. config.yaml**（应用配置）
- 应用程序的配置内容（日志级别、连接池等）
- 会被注入到 ConfigMap 中

**3. deployment-patch.yaml**（Deployment 覆盖）
- **replicas**：副本数（dev: 1, staging: 2, prod: 3）
- **resources**：CPU/内存配额

## 🚀 快速部署

### Dev 环境
```bash
kubectl apply -k overlays/dev
```

### Staging 环境
```bash
kubectl apply -k overlays/staging
```

### Prod 环境
```bash
kubectl apply -k overlays/prod
```

## 🔍 验证部署

```bash
# 查看 Pod
kubectl get pods -l app=api

# 查看 ConfigMap
kubectl get configmap

# 查看配置内容
kubectl describe configmap dev-api-config
```

## 🔥 配置热更新测试

```bash
# 1. 修改 ConfigMap
kubectl edit configmap dev-api-config

# 2. 等待自动同步（最多 120 秒）

# 3. 验证配置已更新
kubectl exec <pod-name> -- curl localhost:8080/api/v1/config
```

## 📊 环境差异

| 配置项 | Dev | Staging | Prod |
|--------|-----|---------|------|
| 副本数 | 1 | 2 | 3 |
| 日志级别 | debug | info | warn |
| CPU | 50m | 100m | 200m |
| Memory | 64Mi | 128Mi | 256Mi |
| 配置 API | ✅ | ✅ | ❌ |

## 📚 更多信息

详见 `docs/v0.5/` 目录下的完整文档。
