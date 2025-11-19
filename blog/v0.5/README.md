# v0.5 - 配置管理与热更新

## 📚 博客列表

### 17. 《K8s 配置管理最佳实践》

**关键词**: ConfigMap, Secret, Kustomize, Validator, Fail-Safe

聚焦 v0.5 的配置管理重构，系统梳理从目录规划、优先级控制到验证与敏感信息治理的全链路。

**核心内容**:

- 四层配置优先级：默认值 → ConfigMap → 环境变量 → 热更新 @src/backend/config/config.go#36-110
- Kustomize base/overlay 结构与 ConfigMap patch 实践 @k8s/v0.5
- Fail-Fast（启动）与 Fail-Safe（运行期）验证策略 @src/backend/config/watcher.go#27-41
- 敏感信息隔离、配置 API 脱敏输出 @src/backend/handler/config.go
- Dev → Prod 配置变更 Runbook @docs/v0.5/DEPLOYMENT-COMMANDS.md

---

### 18. 《配置热更新：无需重启服务》

**关键词**: ConfigMap 热更新, kubelet, fsnotify, Viper, 差异化回调

拆解 ConfigMap 更新到应用动态加载的完整流程，覆盖 Kubernetes 层的符号链接机制和 Go 代码实现细节。

**核心内容**:

- kubelet watch ConfigMap 并原子切换 `..data` 链接 @k8s/v0.5
- Viper + fsnotify 的热更新回调流程 @src/backend/config/watcher.go
- 线程安全与差异比对：RWMutex、diff、notifyChange 机制 @src/backend/config/config.go
- Fail-Safe 策略：解析/验证失败保留旧配置 @src/backend/config/watcher.go#27-44
- 热更新验证命令与排查建议 @docs/v0.5/DEPLOYMENT-COMMANDS.md

---

## 🎯 学习目标

完成 v0.5 后，你将掌握：

1. **配置体系设计**
   - 如何在 Kubernetes 中构建多环境配置管理体系
   - 配置优先级、默认值、敏感信息的治理策略

2. **热更新原理**
   - kubelet 同步 ConfigMap 的底层机制（时间戳目录 + 符号链接）
   - Viper WatchConfig、fsnotify 事件处理与 Go 端线程安全模型

3. **运维实践**
   - Dev → Prod 配置变更 Runbook 与回滚预案
   - 热更新验证命令、常见错误及排查方法

---

## 📂 配套代码与资源

```text
blog/v0.5/
├── 17-k8s-config-management-best-practices.md
├── 18-config-hot-reload-without-restart.md
└── README.md

src/backend/config/
k8s/v0.5/
docs/v0.5/DEPLOYMENT-COMMANDS.md
```

---

## 🔄 技术演进

- **v0.4 → v0.5**：从“环境变量驱动 + 重启生效”升级为“ConfigMap 管理 + 热更新”。
- **目标**：提升配置治理能力、减少运维成本，让配置变更可验证、可回滚。
- **下一站**：v0.6 将聚焦可观测性，把配置系统与监控、日志、Tracing 体系打通。

---

> 配置管理是云原生架构的“中枢神经”。理解 v0.5 的设计与实现细节，就能在真实项目中掌控配置变更的风险与节奏。
