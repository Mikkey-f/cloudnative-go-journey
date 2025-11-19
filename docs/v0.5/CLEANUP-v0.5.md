# v0.5 清理清单

> v0.5 采用方案 1：仅保留后端服务，聚焦配置管理

## ✅ 已完成的更新

### 文档更新

- [x] `docker/v0.5/README.md` - 移除前端相关内容
- [x] `docs/v0.5/DEPLOYMENT-COMMANDS.md` - 统一使用 `Dockerfile`，说明仅后端

### Dockerfile 统一

- [x] 保留 `docker/v0.5/Dockerfile` 作为主文件
- [x] 所有构建命令统一使用 `-f docker\v0.5\Dockerfile`

## 🗑️ 需要删除的文件

请手动执行以下 PowerShell 命令删除不需要的文件：

```powershell
# 进入项目根目录
cd f:\workSpace\goWorkSpace\cloudnative-go-journey-plan

# 删除前端 Dockerfile
Remove-Item docker\v0.5\Dockerfile.frontend -ErrorAction SilentlyContinue

# 删除重复的后端 Dockerfile
Remove-Item docker\v0.5\Dockerfile.backend -ErrorAction SilentlyContinue

# 验证文件结构
Get-ChildItem docker\v0.5\
```

## 📁 最终目录结构

执行清理后，`docker/v0.5/` 目录应该只包含：

```
docker/v0.5/
├── Dockerfile          # 后端镜像（唯一的 Dockerfile）
├── .dockerignore       # Docker 忽略文件
└── README.md           # 构建指南
```

## ✨ 清理后的优势

### 1. 目标聚焦
- v0.5 核心：配置管理
- 不被前端分散注意力

### 2. 文件精简
- 1 个 Dockerfile（原来 2 个）
- 清晰的构建命令
- 减少混淆

### 3. 部署简单
- 只需构建 1 个镜像
- 减少 K8s 资源占用
- 更快的部署速度

### 4. 文档清晰
- 所有文档统一描述
- 命令更简洁
- 学习路径清晰

## 📊 版本对比

| 项目 | v0.4 | v0.5 |
|------|------|------|
| 服务范围 | 前端 + 后端 | 仅后端 ✅ |
| Dockerfile 数量 | 4 个 | 1 个 ✅ |
| 核心目标 | 金丝雀发布 | 配置管理 ✅ |
| 前端作用 | 流量验证 | 不需要 ✅ |

## 🚀 下一步

清理完成后：

1. **验证构建**
   ```powershell
   docker build -f docker\v0.5\Dockerfile -t api:v0.5.0 .
   ```

2. **参考文档**
   - `docs/v0.5/DEPLOYMENT-COMMANDS.md` - 完整部署命令
   - `docker/v0.5/README.md` - Docker 构建指南

3. **开始部署测试**
   - 按照 DEPLOYMENT-COMMANDS.md 进行实践

---

**清理完成！v0.5 现在聚焦配置管理功能！** ✨
