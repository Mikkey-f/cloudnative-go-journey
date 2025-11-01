# v0.3 学习目标

> 详细的学习目标、技能要求和交付标准

---

## 🎯 总体目标

通过 v0.3 版本的学习和实践，掌握 Kubernetes 弹性伸缩的核心能力，能够设计和实施生产级别的自动扩缩方案。

---

## 📚 理论知识目标（40%）

### 1. HPA 核心原理 ⭐⭐⭐⭐⭐

**必须掌握：**

- [ ] **HPA 工作机制**
  - 理解 HPA 的控制循环（每 15 秒）
  - 理解 Metrics Server 的数据采集流程
  - 理解 HPA 如何查询 Metrics API
  - 理解 HPA 如何更新 Deployment 副本数

- [ ] **扩缩容计算公式**
  ```
  期望副本数 = ceil(当前副本数 × (当前指标值 / 目标指标值))
  ```
  - 能手动计算期望副本数
  - 理解 ceil（向上取整）的作用
  - 理解容忍度（±10%）的影响
  - 理解最小/最大副本数的限制

- [ ] **指标类型**
  - Resource Metrics（CPU/Memory）
  - Custom Metrics（自定义指标）
  - External Metrics（外部指标）
  - 知道何时使用哪种指标

**考核标准：**
- 能用自己的话解释 HPA 工作流程
- 能根据实际数据计算期望副本数
- 能画出 HPA 架构图

---

### 2. Metrics Server 架构 ⭐⭐⭐⭐

**必须掌握：**

- [ ] **数据流向**
  ```
  容器 → cAdvisor → kubelet → Metrics Server → Metrics API → HPA
  ```
  - 理解每个组件的职责
  - 知道数据采集间隔（15 秒）
  - 理解时间窗口（30 秒）
  - 理解数据延迟（15-30 秒）

- [ ] **API 聚合机制**
  - 理解 APIService 的作用
  - 知道如何访问 Metrics API
  - 理解 `/apis/metrics.k8s.io/v1beta1/` 端点

- [ ] **指标内容**
  - CPU：纳秒核心 → millicores 转换
  - Memory：工作集（Working Set）定义
  - 理解为什么是工作集而不是 RSS

**考核标准：**
- 能画出 Metrics Pipeline 数据流图
- 能解释 CPU 和内存指标的含义
- 能排查 Metrics Server 常见问题

---

### 3. 资源管理深入理解 ⭐⭐⭐⭐⭐

**必须掌握：**

- [ ] **requests 和 limits 的关系**
  - requests：调度保证，HPA 计算基准
  - limits：运行时限制
  - 理解为什么 HPA 只看 requests

- [ ] **QoS 等级**
  - Guaranteed：requests = limits
  - Burstable：requests < limits（最常用）
  - BestEffort：无配置
  - 理解驱逐优先级

- [ ] **资源设置最佳实践**
  - 如何根据实际使用设置 requests
  - 如何预留缓冲设置 limits
  - 突发比的合理范围（2-4x）

**考核标准：**
- 能为应用选择合适的 QoS 等级
- 能根据监控数据调整资源配置
- 理解资源配置对 HPA 的影响

---

### 4. 扩缩容行为控制 ⭐⭐⭐⭐

**必须掌握：**

- [ ] **扩容行为**
  - 默认：立即扩容
  - stabilizationWindowSeconds：扩容稳定窗口
  - 扩容策略：Percent/Pods
  - selectPolicy：如何选择策略

- [ ] **缩容行为**
  - 默认：5 分钟稳定期
  - 为什么缩容比扩容慢（防抖动）
  - 如何配置缩容速度
  - 如何防止频繁扩缩

- [ ] **冷却期（Cooldown）**
  - 扩容冷却：默认 3 分钟
  - 缩容冷却：默认 5 分钟
  - 如何配置（通过 behavior）

**考核标准：**
- 能配置合适的扩缩容行为
- 能解释为什么需要稳定窗口
- 能根据业务特点调整冷却期

---

## 💻 实践技能目标（50%）

### 1. 环境搭建 ⭐⭐⭐⭐⭐

**必须完成：**

- [ ] **安装 Metrics Server**
  - 使用 kubectl apply 安装
  - 配置 `--kubelet-insecure-tls`（本地环境）
  - 验证 Pod 运行正常
  - 验证 Metrics API 可用

- [ ] **验证环境**
  - `kubectl top nodes` 正常工作
  - `kubectl top pods` 显示资源使用
  - `kubectl get apiservice` 显示可用

**考核标准：**
- 能独立安装 Metrics Server
- 能排查安装问题
- 环境验证通过

---

### 2. 代码开发 ⭐⭐⭐⭐

**必须完成：**

- [ ] **CPU 密集型接口**
  ```go
  // 数学计算、循环等
  func cpuIntensiveHandler(c *gin.Context) {
      // 实现 CPU 密集型操作
  }
  ```
  - 能触发 CPU 使用率上升
  - 计算量可配置（通过参数）
  - 添加 Prometheus 指标

- [ ] **内存密集型接口**
  ```go
  // 大量数据分配
  func memoryIntensiveHandler(c *gin.Context) {
      // 实现内存密集型操作
  }
  ```
  - 能触发内存使用上升
  - 内存分配可配置
  - 正确释放内存（避免泄漏）

- [ ] **工作负载模拟接口**
  ```go
  // 综合负载
  func workloadHandler(c *gin.Context) {
      // CPU + Memory + 延迟
  }
  ```
  - 模拟真实业务场景
  - 可配置负载类型和强度

**考核标准：**
- 接口能正常工作
- 能触发 HPA 扩容
- 代码质量良好

---

### 3. HPA 配置 ⭐⭐⭐⭐⭐

**必须完成：**

- [ ] **基础 HPA 配置**
  ```yaml
  apiVersion: autoscaling/v2
  kind: HorizontalPodAutoscaler
  metadata:
    name: cloudnative-api-hpa
  spec:
    scaleTargetRef:
      apiVersion: apps/v1
      kind: Deployment
      name: cloudnative-api
    minReplicas: 2
    maxReplicas: 10
    metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
  ```

- [ ] **高级 HPA 配置**
  - 配置多指标（CPU + Memory）
  - 配置 behavior（扩缩行为）
  - 优化副本数范围
  - 优化目标使用率

- [ ] **部署和验证**
  - 使用 kubectl apply 部署
  - 使用 kubectl describe 查看状态
  - 使用 kubectl get hpa -w 观察

**考核标准：**
- HPA 配置正确无误
- 能根据业务需求调整配置
- 能解释每个配置项的作用

---

### 4. 压测验证 ⭐⭐⭐⭐

**必须完成：**

- [ ] **k6 压测脚本**
  ```javascript
  // 逐步增加负载
  export let options = {
    stages: [
      { duration: '1m', target: 10 },
      { duration: '3m', target: 50 },
      { duration: '2m', target: 100 },
      { duration: '2m', target: 0 },
    ],
  };
  ```

- [ ] **压测执行**
  - 运行压测脚本
  - 观察 HPA 扩容过程
  - 观察 Pod 创建过程
  - 记录扩容时间

- [ ] **数据收集**
  - 记录扩缩容时间点
  - 记录副本数变化
  - 记录 CPU/内存使用率
  - 记录响应时间变化

**考核标准：**
- 压测能触发扩容
- 能正确解读压测结果
- 能分析性能瓶颈

---

### 5. 监控和调试 ⭐⭐⭐⭐

**必须掌握：**

- [ ] **查看 HPA 状态**
  ```bash
  kubectl get hpa
  kubectl describe hpa cloudnative-api-hpa
  kubectl get events --sort-by='.lastTimestamp'
  ```

- [ ] **查看资源使用**
  ```bash
  kubectl top pods
  kubectl top nodes
  ```

- [ ] **查看 Metrics API 原始数据**
  ```bash
  kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes
  kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods
  ```

- [ ] **问题排查**
  - HPA 显示 `<unknown>/70%`
  - Pod 无法调度（资源不足）
  - 扩容太慢或不扩容
  - 缩容不发生

**考核标准：**
- 能使用 kubectl 排查问题
- 能解读 HPA 事件日志
- 能根据症状定位原因

---

### 6. 性能优化 ⭐⭐⭐

**必须完成：**

- [ ] **资源配置优化**
  - 根据实际使用调整 requests
  - 根据峰值调整 limits
  - 平衡成本和性能

- [ ] **HPA 参数优化**
  - 调整目标使用率
  - 调整副本数范围
  - 调整扩缩速度

- [ ] **应用优化**
  - 优化启动时间
  - 优化健康检查
  - 减少资源占用

**考核标准：**
- 扩缩容响应及时
- 资源利用率合理
- 成本得到优化

---

## 🛠️ 工具使用目标（10%）

### 1. kubectl 高级用法 ⭐⭐⭐⭐

**必须掌握：**

- [ ] **kubectl top**
  - `kubectl top nodes`
  - `kubectl top pods`
  - `kubectl top pods --containers`

- [ ] **kubectl get --raw**
  - 查询 Metrics API
  - 查询 APIService
  - JSON 输出和解析

- [ ] **kubectl describe**
  - 查看详细状态
  - 分析事件日志
  - 排查问题

**考核标准：**
- 能熟练使用 kubectl 命令
- 能快速定位问题
- 能解读命令输出

---

### 2. k6 压测工具 ⭐⭐⭐

**必须掌握：**

- [ ] **基础用法**
  - 编写测试脚本
  - 配置负载阶段
  - 运行测试

- [ ] **高级功能**
  - 配置检查（checks）
  - 配置阈值（thresholds）
  - 多场景测试

- [ ] **结果分析**
  - 理解 HTTP 指标
  - 理解响应时间分布
  - 识别性能问题

**考核标准：**
- 能编写压测脚本
- 能分析测试结果
- 能优化测试场景

---

## 📋 交付标准

### 代码质量

- [ ] Go 代码符合规范
- [ ] 有适当的注释
- [ ] 错误处理完善
- [ ] 无明显性能问题

### K8s 配置

- [ ] YAML 格式正确
- [ ] 配置参数合理
- [ ] 符合最佳实践
- [ ] 有详细注释

### 功能完整性

- [ ] Metrics Server 正常工作
- [ ] HPA 能触发扩容
- [ ] HPA 能触发缩容
- [ ] 压测脚本可运行
- [ ] 所有接口正常工作

### 性能指标

- [ ] 扩容响应时间 < 2 分钟
- [ ] 缩容稳定期约 5 分钟
- [ ] CPU 使用率控制在目标范围
- [ ] 资源利用率合理

### 文档质量

- [ ] 部署文档完整
- [ ] 配置说明清晰
- [ ] 问题排查有效
- [ ] 博客内容充实

---

## 🎓 进阶目标（可选）

### 高级特性

- [ ] 配置基于内存的 HPA
- [ ] 配置自定义指标 HPA
- [ ] 使用 Prometheus Adapter
- [ ] 配置 VPA（垂直扩缩）
- [ ] 配置 KEDA（事件驱动）

### 生产实践

- [ ] 多环境配置（dev/prod）
- [ ] 告警配置
- [ ] 监控 Dashboard
- [ ] 成本分析
- [ ] 容量规划

---

## ✅ 自我检查清单

### 理论掌握

- [ ] 我能解释 HPA 的工作原理
- [ ] 我能计算期望副本数
- [ ] 我理解 Metrics Server 的架构
- [ ] 我理解资源配置对 HPA 的影响
- [ ] 我理解扩缩容的延迟原因

### 实践能力

- [ ] 我能独立安装 Metrics Server
- [ ] 我能编写负载测试接口
- [ ] 我能配置 HPA
- [ ] 我能进行压测验证
- [ ] 我能排查常见问题

### 工具使用

- [ ] 我能熟练使用 kubectl top
- [ ] 我能查看 HPA 状态
- [ ] 我能使用 k6 压测
- [ ] 我能分析测试结果

### 项目完成度

- [ ] 所有代码已完成
- [ ] 所有配置已完成
- [ ] 测试验证通过
- [ ] 文档已完善
- [ ] 博客已编写

---

## 📊 能力评估

完成 v0.3 后，你的能力等级：

| 维度 | 入门前 | v0.3 后 | 提升 |
|-----|--------|---------|------|
| K8s 基础 | 60% | 75% | +15% |
| 弹性伸缩 | 20% | 90% | +70% |
| 资源管理 | 40% | 85% | +45% |
| 性能优化 | 30% | 70% | +40% |
| 问题排查 | 40% | 70% | +30% |
| **总体** | **38%** | **78%** | **+40%** |

---

## 🎯 下一步学习

完成 v0.3 后，建议：

1. **巩固知识** - 重新部署一遍，加深理解
2. **尝试优化** - 调整参数，观察效果
3. **学习进阶** - VPA、KEDA、自定义指标
4. **准备 v0.4** - Ingress 和服务治理

---

**记住**：学习是一个渐进的过程，不要急于求成。每个目标都要真正掌握！💪

