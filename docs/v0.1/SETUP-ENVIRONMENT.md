# v0.1 环境搭建指南

> Windows 10/11 环境下的快速安装指南

## 📋 环境检查

**先运行环境检查脚本**：

```powershell
# PowerShell（推荐）
.\scripts\check-environment.ps1

# 或使用 Git Bash
bash scripts/check-environment.sh
```

根据检查结果，安装缺失的工具。

---

## 🛠️ 工具安装

### 1. Go 1.21+ ✅ 必须

**方法 A：官方安装包（推荐）**
1. 访问：https://go.dev/dl/
2. 下载 Windows 安装包（.msi）
3. 双击安装
4. 验证：
   ```powershell
   go version
   # 输出: go version go1.21.x windows/amd64
   ```

**方法 B：使用 Chocolatey**
```powershell
choco install golang
```

**配置（可选）**：
```powershell
# 设置 GOPROXY（国内加速）
go env -w GOPROXY=https://goproxy.cn,direct

# 启用 Go Modules
go env -w GO111MODULE=on
```

---

### 2. Docker Desktop ✅ 必须

**安装步骤**：
1. 访问：https://www.docker.com/products/docker-desktop
2. 下载 Windows 版本
3. 双击安装
4. 重启电脑
5. 启动 Docker Desktop
6. 验证：
   ```powershell
   docker --version
   # 输出: Docker version 24.x.x

   docker ps
   # 能正常显示表格说明 daemon 运行正常
   ```

**常见问题**：
- ❌ WSL 2 未安装：根据提示安装 WSL 2
- ❌ Hyper-V 未启用：在"Windows 功能"中启用

**推荐配置**：
- Settings → Resources → 分配至少 4GB 内存、2 个 CPU

---

### 3. kubectl ✅ 必须

**方法 A：通过 Docker Desktop（最简单）**
- Docker Desktop 已包含 kubectl
- Settings → Kubernetes → Enable Kubernetes ✓

**方法 B：独立安装**
```powershell
# 使用 Chocolatey
choco install kubernetes-cli

# 或手动下载
# https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/
```

**验证**：
```powershell
kubectl version --client
```

---

### 4. Minikube ✅ 必须

**安装步骤**：

**方法 A：官方安装包**
1. 下载：https://minikube.sigs.k8s.io/docs/start/
2. 选择 Windows → x86-64 → .exe installer
3. 双击安装

**方法 B：使用 Chocolatey**
```powershell
choco install minikube
```

**验证**：
```powershell
minikube version
# 输出: minikube version: v1.32.0
```

---

### 5. Git ✅ 必须

```powershell
# 使用 Chocolatey
choco install git

# 或下载官方安装包
# https://git-scm.com/download/win
```

**验证**：
```powershell
git --version
```

---

### 6. k9s（可选但强烈推荐）⭐

k9s 是一个终端 UI，让 K8s 操作变得非常简单！

**安装**：
```powershell
# 使用 Chocolatey
choco install k9s

# 或使用 Scoop
scoop install k9s
```

**使用**：
```bash
k9s  # 在 K8s 集群启动后运行
```

**操作提示**：
- `:pod` - 查看 Pods
- `:deploy` - 查看 Deployments
- `:svc` - 查看 Services
- `l` - 查看日志
- `d` - 删除资源
- `?` - 帮助

---

## 🚀 启动 Minikube 集群

安装完成后，启动本地 K8s 集群：

```powershell
# 启动集群（首次启动会下载 ISO，需要几分钟）
minikube start

# 参数选项（可选）
minikube start `
  --cpus=2 `
  --memory=4096 `
  --driver=docker  # 使用 Docker 驱动
```

**等待输出**：
```
😄  Microsoft Windows 10 上的 minikube v1.32.0
✨  自动选择 docker 驱动
👍  Starting control plane node minikube in cluster minikube
🚜  Pulling base image ...
🔥  Creating docker container (CPUs=2, Memory=4096MB) ...
🐳  正在 Docker 24.0.7 中准备 Kubernetes v1.28.3...
🔗  Configuring bridge CNI (Container Networking Interface) ...
🔎  Verifying Kubernetes components...
🌟  Enabled addons: storage-provisioner, default-storageclass
🏄  Done! kubectl is now configured to use "minikube" cluster
```

**验证集群**：
```powershell
# 查看集群状态
minikube status

# 查看节点
kubectl get nodes

# 输出应该是：
# NAME       STATUS   ROLES           AGE   VERSION
# minikube   Ready    control-plane   1m    v1.28.3
```

---

## 🎯 启用必要插件

```powershell
# 启用 metrics-server（用于查看资源使用情况）
minikube addons enable metrics-server

# 验证（需要等待 1-2 分钟）
kubectl top nodes
```

---

## 📝 常见问题排查

### Q1: Minikube 启动失败

```powershell
# 删除旧集群重新开始
minikube delete
minikube start
```

### Q2: kubectl 连接不上集群

```powershell
# 重新配置 kubectl
minikube update-context

# 查看当前 context
kubectl config current-context
# 应该输出: minikube
```

### Q3: Docker Desktop 启动慢/卡顿

- 检查 WSL 2 是否正常
- 减少资源分配（Settings → Resources）
- 清理 Docker 镜像：`docker system prune -a`

### Q4: 网络问题导致下载慢

```powershell
# 使用国内镜像源启动 Minikube
minikube start --image-mirror-country=cn
```

---

## ✅ 环境检查清单

安装完成后，确保以下命令都能正常运行：

```powershell
# Go
go version

# Docker
docker --version
docker ps

# kubectl
kubectl version --client

# Minikube
minikube version
minikube status

# Git
git --version

# k9s（可选）
k9s version
```

---

## 🎉 恭喜！环境准备完毕

现在你可以开始 v0.1 的开发了！

**下一步**：
1. ✅ 阅读 `docs/v0.1/K8S-BASICS.md`（5分钟了解 K8s 核心概念）
2. ✅ 开始编写代码 → 跟随教程继续

---

## 📚 参考资源

- Docker Desktop 文档：https://docs.docker.com/desktop/windows/
- Minikube 文档：https://minikube.sigs.k8s.io/docs/
- kubectl 文档：https://kubernetes.io/docs/reference/kubectl/
- k9s 文档：https://k9scli.io/

---

**有问题？** 查看 `docs/v0.1/TROUBLESHOOTING.md` 或提 Issue
