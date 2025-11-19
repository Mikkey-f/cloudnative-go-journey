# v0.5 Docker 镜像构建指南

> v0.5 版本聚焦配置管理功能，仅包含后端服务

## 📦 镜像列表

| 镜像 | Dockerfile | 用途 | 端口 |
|------|-----------|------|------|
| `api:v0.5.0` | `Dockerfile` | 后端 API（配置管理） | 8080 |

## 🏗️ 构建命令

### 后端镜像

```powershell
# 在项目根目录执行
docker build -f docker\v0.5\Dockerfile -t api:v0.5.0 .

# 或者使用默认 Dockerfile
cd docker\v0.5
docker build -t api:v0.5.0 ../..

# 验证镜像
docker images | Select-String "api.*v0.5"

# 查看镜像层
docker history api:v0.5.0
```

## 🧪 本地测试

### 测试后端镜像

```powershell
# 启动容器（需要 Redis）
docker run -d --name api-v0.5-test `
  -p 8080:8080 `
  -e REDIS_HOST=host.docker.internal `
  -e REDIS_PORT=6379 `
  api:v0.5.0

# 查看日志
docker logs api-v0.5-test

# 测试健康检查
Invoke-RestMethod -Uri "http://localhost:8080/health"

# 测试配置 API
Invoke-RestMethod -Uri "http://localhost:8080/api/v1/config"

# 清理
docker stop api-v0.5-test
docker rm api-v0.5-test
```


## 🚀 Minikube 构建

```powershell
# 切换到 Minikube Docker 环境
minikube docker-env --shell powershell | Invoke-Expression

# 构建后端镜像
docker build -f docker\v0.5\Dockerfile -t api:v0.5.0 .

# 验证镜像在 Minikube 中
docker images | Select-String "api.*v0.5"
```

## 📊 镜像大小优化

### 后端镜像优化

- ✅ 多阶段构建（builder + runtime）
- ✅ 使用 Alpine 基础镜像（~5MB）
- ✅ 静态编译（CGO_ENABLED=0）
- ✅ 去除调试符号（-ldflags="-w -s"）
- ✅ 非 root 用户运行

**预计大小**: ~20-30MB

## 🔍 镜像检查

```powershell
# 查看镜像详情
docker inspect api:v0.5.0

# 查看镜像层
docker history api:v0.5.0

# 查看镜像大小
docker images | Select-String "v0.5"

# 扫描安全漏洞（如果安装了 trivy）
trivy image api:v0.5.0
```

## 🆚 与 v0.4 的区别

### 服务范围

| 版本 | 服务 | 说明 |
|------|------|------|
| v0.4 | 前端 + 后端 | 金丝雀发布演示需要前端 |
| v0.5 | 仅后端 | 聚焦配置管理 |

### 后端差异

| 特性 | v0.4 | v0.5 |
|------|------|------|
| 配置管理 | 环境变量 | Viper + ConfigMap |
| 配置热更新 | ❌ | ✅ |
| 配置 API | ❌ | ✅ |
| 配置目录 | ❌ | `/etc/config` |
| 健康检查 | ✅ | ✅ |

## 📝 注意事项

1. **构建路径**: 必须在项目根目录执行构建命令
2. **镜像标签**: 使用 `v0.5.0` 标签，保持版本清晰
3. **配置挂载**: 需要挂载 `/etc/config` 目录用于 ConfigMap
4. **健康检查**: 配置了健康检查（30s 间隔）
5. **非 root 用户**: 使用 `appuser` 运行（UID 1000）
6. **仅后端**: v0.5 聚焦配置管理，不包含前端服务

## 🔗 相关文档

- **部署命令**: `docs/v0.5/DEPLOYMENT-COMMANDS.md`
- **K8s 配置**: `k8s/v0.5/`
- **架构设计**: `docs/v0.5/DESIGN_v0.5.md`
