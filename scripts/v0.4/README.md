# v0.4 脚本集合

> v0.4 版本的所有辅助脚本

## 📋 脚本列表

### 环境准备

**setup-environment.sh** - 环境准备脚本
- 启用 Nginx Ingress Controller
- 安装 Istio
- 启用 Sidecar 自动注入

```bash
bash scripts/v0.4/setup-environment.sh
```

### 验证脚本

**verify-ingress.sh** - Ingress 验证
- 检查 Ingress 配置
- 验证路由规则
- 检查后端服务

```bash
bash scripts/v0.4/verify-ingress.sh
```

**verify-istio.sh** - Istio 验证
- 检查 Istio 安装
- 验证 Istiod 和 Envoy
- 检查自动注入
- 验证 VirtualService 和 DestinationRule

```bash
bash scripts/v0.4/verify-istio.sh
```

**traffic-verify.sh** - 流量验证
- 发送 100+ 个请求
- 统计 v1 和 v2 的流量分配
- 验证金丝雀发布效果

```bash
bash scripts/v0.4/traffic-verify.sh
```

## 🚀 执行顺序

1. **环境准备**
   ```bash
   bash scripts/v0.4/setup-environment.sh
   ```

2. **验证 Istio**
   ```bash
   bash scripts/v0.4/verify-istio.sh
   ```

3. **部署应用** (使用 k8s/v0.4 中的配置文件)

4. **验证 Ingress**
   ```bash
   bash scripts/v0.4/verify-ingress.sh
   ```

5. **验证流量分配**
   ```bash
   bash scripts/v0.4/traffic-verify.sh
   ```

## 📝 脚本特性

- ✅ 彩色输出，易于阅读
- ✅ 详细的错误提示
- ✅ 自动检查前置要求
- ✅ 完整的验证步骤
- ✅ 清晰的下一步指导

## 🔧 使用示例

### 完整部署流程

```bash
# 1. 环境准备
bash scripts/v0.4/setup-environment.sh

# 2. 验证 Istio
bash scripts/v0.4/verify-istio.sh

# 3. 部署应用
kubectl apply -f k8s/v0.4/ingress/ingress.yaml
kubectl apply -f k8s/v0.4/istio/virtual-service.yaml
kubectl apply -f k8s/v0.4/istio/destination-rule.yaml

# 4. 验证 Ingress
bash scripts/v0.4/verify-ingress.sh

# 5. 验证流量分配
bash scripts/v0.4/traffic-verify.sh
```

## 📊 脚本输出示例

### setup-environment.sh

```
==========================================
v0.4 环境准备 - Task 1
==========================================

[1/6] 检查前置要求...
✓ 前置要求检查通过

[2/6] 启用 Nginx Ingress Controller...
✓ Ingress 控制器已启用

...

==========================================
✓ 环境准备完成！
==========================================
```

### traffic-verify.sh

```
==========================================
v0.4 流量验证 - Task 8
==========================================

已完成: 100/100

========== 流量分配结果 ==========

v1 (稳定版本): 91 次 (91%)
v2 (新版本):   9 次 (9%)
错误响应:      0 次

========== 验证结果 ==========

✓ v1 比例验证通过 (91% 在 85%-95% 范围内)
✓ v2 比例验证通过 (9% 在 5%-15% 范围内)
✓ 错误率验证通过 (0% < 5%)

========== 验证通过！ ==========
```

## 🐛 故障排查

### 脚本执行失败

1. **检查权限**
   ```bash
   chmod +x scripts/v0.4/*.sh
   ```

2. **检查依赖**
   - 确保 kubectl 已安装
   - 确保 minikube 已安装
   - 确保 curl 已安装

3. **查看详细错误**
   ```bash
   bash -x scripts/v0.4/setup-environment.sh
   ```

### 验证失败

参考各脚本的错误提示，通常需要检查：
- Kubernetes 集群状态
- Ingress 配置
- Istio 安装
- 应用 Pod 状态

## 📚 相关文档

- [DEPLOYMENT-GUIDE.md](../docs/v0.4/DEPLOYMENT-GUIDE.md) - 完整部署指南
- [TROUBLESHOOTING.md](../docs/v0.4/TROUBLESHOOTING.md) - 故障排查
- [AUTOMATE_v0.4.md](../docs/v0.4/AUTOMATE_v0.4.md) - 执行计划

---

**提示**: 所有脚本都支持在任何目录运行，会自动定位项目根目录。
