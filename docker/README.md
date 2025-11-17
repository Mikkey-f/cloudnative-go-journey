# Docker 镜像构建

> 项目的所有 Dockerfile 配置

## 📂 目录结构

```
docker/
├── v0.1/
│   └── Dockerfile                # v0.1 基础镜像
├── v0.4/
│   ├── Dockerfile.backend        # v0.4 后端镜像
│   ├── Dockerfile.frontend       # v0.4 前端镜像
│   └── nginx.conf                # Nginx 配置
└── README.md                     # 本文件
```

## 🚀 构建镜像

### v0.1 基础镜像

```bash
docker build -f docker/v0.1/Dockerfile -t api:v0.1 .
```

### v0.4 后端镜像

```bash
# 构建镜像（v1 和 v2 使用同一镜像，通过 API_VERSION 环境变量区分）
docker build -f docker/v0.4/Dockerfile.backend -t api:latest .
```

### v0.4 前端镜像

```bash
docker build -f docker/v0.4/Dockerfile.frontend -t frontend:latest .
```

## 🎯 一键构建所有镜像

```bash
#!/bin/bash

# 后端（v1 和 v2 使用同一镜像）
docker build -f docker/v0.4/Dockerfile.backend -t api:latest .

# 前端
docker build -f docker/v0.4/Dockerfile.frontend -t frontend:latest .

echo "✓ 所有镜像构建完成"
docker images | grep -E "api|frontend"
```

## 📋 镜像说明

### api:latest

- **用途**: API 后端服务（v1 和 v2 使用同一镜像）
- **基础镜像**: alpine:latest
- **大小**: ~20MB
- **入口**: `./api`
- **端口**: 8080
- **环境变量**:
  - `API_VERSION=v1` (v1 Deployment 使用)
  - `API_VERSION=v2` (v2 Deployment 使用)
  - `REDIS_HOST=redis-service`
  - `REDIS_PORT=6379`
- **优点**:
  - 单一镜像，易于管理
  - 通过环境变量区分版本
  - 符合 12-factor 应用原则

### frontend:latest

- **用途**: 前端服务
- **基础镜像**: nginx:alpine
- **大小**: ~40MB
- **入口**: nginx
- **端口**: 8080
- **特性**:
  - Gzip 压缩
  - 静态资源缓存
  - 健康检查端点

## 🧪 本地测试

### 后端镜像

```bash
# 运行 v1
docker run -p 8080:8080 -e API_VERSION=v1 api:latest

# 运行 v2
docker run -p 8080:8080 -e API_VERSION=v2 api:v2

# 测试
curl http://localhost:8080/health
curl http://localhost:8080/api/v1/version
```

### 前端镜像

```bash
# 运行
docker run -p 8080:8080 frontend:latest

# 访问
curl http://localhost:8080/
```

## 📊 镜像优化

### 多阶段构建

所有 Dockerfile 都使用多阶段构建：
- **构建阶段**: 编译应用
- **运行阶段**: 最小化镜像大小

### 大小对比

| 镜像 | 大小 | 优化 |
|------|------|------|
| api:latest | ~20MB | 多阶段构建 + 静态链接（v1 和 v2 共用） |
| frontend:latest | ~40MB | Nginx Alpine |
| **总计** | **~60MB** | 相比两个独立后端镜像节省 ~20MB |

## 🔐 安全最佳实践

### 后端镜像

- ✅ 非 root 用户运行
- ✅ 静态链接（无依赖）
- ✅ 最小化基础镜像
- ✅ 健康检查配置

### 前端镜像

- ✅ Nginx 官方镜像
- ✅ 隐藏文件保护
- ✅ 健康检查端点
- ✅ 静态资源缓存

## 🚢 推送到仓库

```bash
# 标记镜像
docker tag api:latest myregistry/api:latest
docker tag api:v2 myregistry/api:v2
docker tag frontend:latest myregistry/frontend:latest

# 推送
docker push myregistry/api:latest
docker push myregistry/api:v2
docker push myregistry/frontend:latest
```

## 📚 相关文档

- [Dockerfile 最佳实践](https://docs.docker.com/develop/dev-best-practices/dockerfile_best-practices/)
- [Nginx 配置参考](https://nginx.org/en/docs/)
- [Go 静态链接](https://golang.org/cmd/cgo/)

---

**提示**: 所有 Dockerfile 都包含详细注释，便于理解和修改。
