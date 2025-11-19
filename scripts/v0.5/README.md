# v0.5 脚本使用指南

## 📜 脚本清单

| 脚本 | 用途 | 使用方法 |
|------|------|---------|
| `deploy-env.sh` | 部署指定环境 | `./deploy-env.sh [dev\|staging\|prod]` |
| `config-test.sh` | 测试配置 API | `./config-test.sh [port]` |
| `hot-reload-test.sh` | 测试配置热更新 | `./hot-reload-test.sh [env]` |

## 🚀 使用示例

### 1. 部署环境

```bash
# 部署 dev 环境
./deploy-env.sh dev

# 部署 staging 环境
./deploy-env.sh staging

# 部署 prod 环境
./deploy-env.sh prod
```

### 2. 测试配置 API

```bash
# 本地测试（默认端口 8080）
./config-test.sh

# 指定端口
./config-test.sh 9000
```

### 3. 测试配置热更新

```bash
# 测试 dev 环境热更新
./hot-reload-test.sh dev

# 测试 staging 环境热更新
./hot-reload-test.sh staging
```

## ⚠️ 注意事项

1. 脚本需要可执行权限：`chmod +x *.sh`
2. 需要安装 `kubectl`、`jq`
3. 热更新测试最多等待 120 秒（K8s ConfigMap 同步时间）
4. Windows 用户请使用 Git Bash 或 WSL 运行脚本
