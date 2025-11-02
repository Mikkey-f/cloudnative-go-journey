# 从零开始的云原生之旅（十一）：压测实战：验证弹性伸缩效果

> 用 k6 进行专业压测，看着 HPA 在真实负载下自动扩缩容，这才是云原生的魅力！

## 📖 文章目录

- [前言](#前言)
- [一、为什么要做压测？](#一为什么要做压测)
  - [1.1 手动测试的局限](#11-手动测试的局限)
  - [1.2 专业压测的价值](#12-专业压测的价值)
  - [1.3 压测的目标](#13-压测的目标)
- [二、选择压测工具：k6](#二选择压测工具k6)
  - [2.1 为什么选择 k6？](#21-为什么选择-k6)
  - [2.2 k6 安装](#22-k6-安装)
  - [2.3 k6 核心概念](#23-k6-核心概念)
- [三、编写 k6 压测脚本](#三编写-k6-压测脚本)
  - [3.1 脚本结构](#31-脚本结构)
  - [3.2 配置测试阶段](#32-配置测试阶段)
  - [3.3 实现测试场景](#33-实现测试场景)
  - [3.4 完整脚本](#34-完整脚本)
- [四、优化配置准备压测](#四优化配置准备压测)
  - [4.1 我踩的坑：256Mi 内存不够](#41-我踩的坑256mi-内存不够)
  - [4.2 优化资源配置](#42-优化资源配置)
  - [4.3 优化探针配置](#43-优化探针配置)
  - [4.4 为什么这样优化？](#44-为什么这样优化)
- [五、执行压测](#五执行压测)
  - [5.1 准备监控窗口](#51-准备监控窗口)
  - [5.2 启动压测](#52-启动压测)
  - [5.3 实时观察](#53-实时观察)
- [六、压测结果分析](#六压测结果分析)
  - [6.1 k6 指标解读](#61-k6-指标解读)
  - [6.2 性能评估](#62-性能评估)
  - [6.3 HPA 效果分析](#63-hpa-效果分析)
  - [6.4 与行业标准对比](#64-与行业标准对比)
- [七、问题诊断与优化](#七问题诊断与优化)
  - [7.1 CrashLoopBackOff 问题](#71-crashloopbackoff-问题)
  - [7.2 内存占用分析](#72-内存占用分析)
  - [7.3 优化历程](#73-优化历程)
- [八、最佳实践总结](#八最佳实践总结)
  - [8.1 资源配置建议](#81-资源配置建议)
  - [8.2 探针配置建议](#82-探针配置建议)
  - [8.3 HPA 配置建议](#83-hpa-配置建议)
  - [8.4 压测策略建议](#84-压测策略建议)
- [九、v0.3 完整总结](#九v03-完整总结)
  - [9.1 学习成果](#91-学习成果)
  - [9.2 核心配置](#92-核心配置)
  - [9.3 性能指标](#93-性能指标)
- [结语](#结语)

---

## 前言

在完成 HPA 配置后，我手动发送了一些请求，看到了 Pod 自动扩缩容。但我知道，**这还不够**：
- 手动测试无法模拟真实负载
- 无法持续观察长时间的扩缩容行为
- 缺少性能指标数据

所以，我需要进行**专业的压力测试**！

这篇文章记录我：
- ✅ 使用 k6 编写压测脚本
- ✅ 执行长达 9.5 分钟的负载测试
- ✅ 观察 HPA 在真实负载下的表现
- ✅ 分析性能指标和优化配置
- ✅ **详细记录踩过的坑和解决方案**

**压测结果**：
- ✅ **100% 请求成功率**
- ✅ **P95 响应时间 983ms**
- ✅ **零失败请求**
- ✅ **HPA 成功扩缩容**

---

## 一、为什么要做压测？

### 1.1 手动测试的局限

之前我是这样测试的：

```bash
# 手动发送几个请求
for i in {1..10}; do
  curl "$SERVICE_URL/api/v1/workload/cpu?iterations=20000000"
done
```

**问题**：
- ❌ 只能测试短时间的行为
- ❌ 无法模拟真实的并发场景
- ❌ 缺少性能指标（P50、P95、P99）
- ❌ 无法持续观察扩缩容过程
- ❌ 没有成功率、错误率等关键指标

### 1.2 专业压测的价值

使用 k6 等专业工具后：

```
✅ 模拟真实负载：30 并发用户，持续 9.5 分钟
✅ 自动收集指标：响应时间、成功率、吞吐量
✅ 完整的测试周期：预热 → 增压 → 高负载 → 降压 → 冷却
✅ 观察完整的扩缩容过程
✅ 发现潜在问题（OOM、探针超时等）
✅ 验证系统稳定性
```

### 1.3 压测的目标

我的压测目标：

1. **验证 HPA 是否正常工作**
   - CPU/内存超过阈值时自动扩容
   - 负载降低时自动缩容
   - 扩缩容过程平滑

2. **验证系统稳定性**
   - 高负载下 Pod 不崩溃
   - 探针不误杀 Pod
   - 无 OOMKilled 事件

3. **收集性能基线**
   - 响应时间分布（P50、P95、P99）
   - 吞吐量（RPS）
   - 错误率

4. **发现潜在问题**
   - 资源配置是否合理
   - 探针配置是否需要优化
   - HPA 策略是否需要调整

---

## 二、选择压测工具：k6

### 2.1 为什么选择 k6？

对比常见的压测工具：

| 工具 | 优点 | 缺点 | 适合场景 |
|------|------|------|---------|
| **k6** | 现代化、易用、详细的指标报告 | 相对较新 | ✅ 我的选择 |
| **JMeter** | 功能强大、图形界面 | 笨重、资源消耗大 | 传统企业 |
| **ab** | 简单、内置 | 功能简陋 | 快速测试 |
| **wrk** | 高性能 | 缺少图形界面 | 极限测试 |
| **Locust** | Python 编写、分布式 | 需要写 Python | 复杂场景 |

**k6 的优势**：
- ✅ 使用 JavaScript 编写（前端开发者友好）
- ✅ 丰富的内置指标（P50、P95、P99）
- ✅ 支持复杂的测试场景
- ✅ 美观的终端输出
- ✅ 支持自定义指标
- ✅ 开源且活跃

### 2.2 k6 安装

**Windows (Chocolatey)**：

```powershell
choco install k6
```

**macOS (Homebrew)**：

```bash
brew install k6
```

**Linux (Debian/Ubuntu)**：

```bash
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6
```

**验证安装**：

```bash
k6 version
# k6 v0.48.0
```

### 2.3 k6 核心概念

**VU (Virtual User)**: 虚拟用户
```
1 个 VU = 1 个并发用户
30 VU = 30 个并发用户同时发送请求
```

**迭代 (Iteration)**: 一次完整的测试场景执行
```
1 次迭代 = 执行一次 default 函数
包括：发送请求 + 检查响应 + sleep
```

**阶段 (Stage)**: 测试的不同阶段
```
Stage 1: 预热（VU 从 0 增加到 5）
Stage 2: 增压（VU 从 5 增加到 30）
Stage 3: 高负载（VU 保持 30）
Stage 4: 降压（VU 从 30 降到 5）
```

**指标 (Metrics)**: 性能数据
```
- http_req_duration: HTTP 请求耗时
- http_req_failed: 请求失败率
- http_reqs: 总请求数
- checks: 检查通过率
```

---

## 三、编写 k6 压测脚本

### 3.1 脚本结构

```javascript
// 1. 导入模块
import http from 'k6/http';
import { check, sleep } from 'k6';

// 2. 配置
export let options = {
  stages: [...],      // 测试阶段
  thresholds: {...},  // 性能阈值
};

// 3. 测试场景（每个 VU 重复执行）
export default function () {
  // 发送请求
  // 检查响应
  // 等待（模拟用户思考时间）
}

// 4. 生命周期钩子
export function setup() {
  // 测试前执行一次
}

export function teardown() {
  // 测试后执行一次
}
```

### 3.2 配置测试阶段

**我的测试计划（总时长 9.5 分钟）**：

```javascript
export let options = {
  stages: [
    // 阶段 1: 预热（30 秒）
    { duration: '30s', target: 3 },
    
    // 阶段 2: 缓慢增压（1 分钟）
    { duration: '1m', target: 10 },
    
    // 阶段 3: 激增负载（2 分钟）- 触发 HPA 扩容
    { duration: '2m', target: 30 },
    
    // 阶段 4: 保持高负载（3 分钟）- 观察扩容效果
    { duration: '3m', target: 30 },
    
    // 阶段 5: 缓慢降压（2 分钟）
    { duration: '2m', target: 10 },
    
    // 阶段 6: 完全冷却（1 分钟）- 观察缩容
    { duration: '1m', target: 3 },
  ],
  
  // 性能阈值
  thresholds: {
    'http_req_duration': ['p(95)<5000'],  // 95% 请求在 5 秒内
    'http_req_failed': ['rate<0.2'],      // 错误率低于 20%
  },
};
```

**阶段设计思路**：

```
VUs
 30 |          ▄▄▄▄▄▄▄▄▄▄▄▄▄▄     ← 阶段 3-4: 高负载，HPA 扩容
    |        ▄▄                ▄▄
 10 |      ▄▄                    ▄▄   ← 阶段 2,5: 中负载
    |    ▄▄                        ▄▄
  3 |▄▄▄▄                            ▄▄ ← 阶段 1,6: 预热/冷却
  0 |_____________________________________
      0   1   2   3   4   5   6   7   8   9  分钟
```

### 3.3 实现测试场景

**场景：50% CPU 负载 + 50% 内存负载**

```javascript
export default function () {
  // 随机选择负载类型
  const testType = Math.random();
  
  if (testType < 0.5) {
    // 50% - CPU 密集型负载
    testCPUWorkload();
  } else {
    // 50% - 内存密集型负载
    testMemoryWorkload();
  }
  
  // 随机等待 2-4 秒（模拟用户思考时间）
  sleep(Math.random() * 2 + 2);
}

// CPU 密集型测试
function testCPUWorkload() {
  const intensity = Math.floor(Math.random() * 10) + 10;  // 10-20 百万次
  const url = `${BASE_URL}/api/v1/workload/cpu?iterations=${intensity * 1000000}`;
  
  const res = http.get(url, { timeout: '30s' });
  
  check(res, {
    'CPU test: status is 200': (r) => r.status === 200,
    'CPU test: has body': (r) => r.body && r.body.length > 0,
  });
}

// 内存密集型测试
function testMemoryWorkload() {
  const sizeMB = Math.floor(Math.random() * 20) + 20;  // 20-40 MB
  const duration = Math.floor(Math.random() * 1) + 1;  // 1-2 秒
  const url = `${BASE_URL}/api/v1/workload/memory?size=${sizeMB}&duration=${duration}`;
  
  const res = http.get(url, { timeout: '30s' });
  
  check(res, {
    'Memory test: status is 200': (r) => r.status === 200,
    'Memory test: has body': (r) => r.body && r.body.length > 0,
  });
}
```

### 3.4 完整脚本

完整脚本见 `k6-tests/hpa-test.js`（已在项目中创建）。

**核心特性**：
- ✅ 混合负载（CPU + 内存）
- ✅ 随机参数（模拟真实场景）
- ✅ 超时处理（30 秒）
- ✅ 错误处理（JSON parse）
- ✅ 自定义指标（cpu_requests、memory_requests）
- ✅ 生命周期钩子（健康检查、总结）

---

## 四、优化配置准备压测

### 4.1 我踩的坑：256Mi 内存不够

**第一次压测，所有 Pod 都崩溃了！**

```bash
$ kubectl get pods
NAME                             READY   STATUS             RESTARTS
cloudnative-api-xxx              0/1     CrashLoopBackOff   4
cloudnative-api-yyy              0/1     CrashLoopBackOff   4
cloudnative-api-zzz              0/1     CrashLoopBackOff   4
```

**查看事件**：

```bash
$ kubectl describe pod cloudnative-api-xxx
Events:
  Warning  BackOff  restarting failed container api
```

**查看 HPA**：

```bash
$ kubectl get hpa
NAME                   TARGETS           REPLICAS
cloudnative-api-hpa    <unknown>/70%     3
```

**问题分析**：

1. k6 发送 30 并发请求
2. 50% 是内存请求，每个分配 20-40MB
3. 30 × 50% × 30MB = **450MB**
4. 加上 Go 运行时开销 ≈ **550MB**
5. **limits: 256Mi → 严重不足 → OOMKilled！**

### 4.2 优化资源配置

**调整前**：

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"  # ← 不够！
    cpu: "300m"
```

**调整后**：

```yaml
resources:
  requests:
    memory: "128Mi"  # 保持不变（HPA 基准）
    cpu: "100m"
  limits:
    memory: "512Mi"  # ← 翻倍！
    cpu: "500m"      # ← 提高到 5 倍
```

**为什么这样调整？**

| 配置 | 原值 | 新值 | 原因 |
|------|------|------|------|
| **memory limits** | 256Mi | 512Mi | 防止高负载时 OOM |
| **cpu limits** | 300m | 500m | 更大的突发空间 |
| **memory requests** | 128Mi | 128Mi | 保持不变（HPA 基准）|
| **cpu requests** | 100m | 100m | 保持不变（HPA 基准）|

**关键点**：
- requests 不变 → HPA 触发敏感度不变
- limits 提高 → 支持更高的突发负载

### 4.3 优化探针配置

**第二个坑：高负载下探针超时，Pod 被误杀**

```bash
Events:
  Warning  Unhealthy  Readiness probe failed: 
    Get "http://10.244.0.66:8080/ready": dial tcp: connect: connection refused
  Warning  BackOff    Back-off restarting failed container
```

**问题分析**：

```
应用处理 30 个并发请求 → CPU 100%
↓
就绪探针 3 秒超时
↓
应用忙于处理请求，无法响应探针
↓
连续失败 3 次 → Kubernetes 认为 Pod 不健康
↓
重启 Pod → 正在处理的请求丢失
↓
恶性循环：CrashLoopBackOff
```

**优化方案**：

```yaml
# 存活探针（避免误杀）
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 15      # 增加初始延迟
  periodSeconds: 15            # 降低检查频率
  timeoutSeconds: 10           # ⭐ 增加超时时间
  failureThreshold: 5          # ⭐ 允许更多失败

# 就绪探针（适应高负载）
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10            # 降低检查频率
  timeoutSeconds: 10           # ⭐ 增加超时时间
  failureThreshold: 6          # ⭐ 允许更多失败
```

### 4.4 为什么这样优化？

**对比表**：

| 探针 | 参数 | 优化前 | 优化后 | 效果 |
|------|------|--------|--------|------|
| **Readiness** | timeoutSeconds | 3s | 10s | 给应用 7 秒额外时间 |
| | failureThreshold | 3 | 6 | 允许失败 60 秒 |
| | periodSeconds | 5s | 10s | 降低检查频率 |
| **Liveness** | timeoutSeconds | 5s | 10s | 避免误杀 |
| | failureThreshold | 3 | 5 | 允许失败 75 秒 |

**效果**：
- ✅ Pod 不会因为短暂的高负载被误杀
- ✅ 压测期间 Pod 稳定运行
- ✅ **0 次重启**

---

## 五、执行压测

### 5.1 准备监控窗口

**强烈建议打开 4 个监控窗口**：

**终端 1 - Minikube Service 隧道**（Windows PowerShell）：
```powershell
minikube service cloudnative-api-service --url
# 输出: http://127.0.0.1:53163
# 保持运行，不要关闭
```

**终端 2 - HPA 监控**：
```bash
kubectl get hpa cloudnative-api-hpa -w
```

**终端 3 - Pod 监控**：
```bash
kubectl get pods -l app=cloudnative-api -w
```

**终端 4 - 资源监控**（PowerShell）：
```powershell
while ($true) {
    Clear-Host
    Write-Host "=== $(Get-Date -Format 'HH:mm:ss') ===" -ForegroundColor Cyan
    kubectl top pods -l app=cloudnative-api 2>$null
    kubectl get hpa cloudnative-api-hpa --no-headers 2>$null
    Start-Sleep -Seconds 5
}
```

### 5.2 启动压测

**在新的终端执行**：

```bash
# 进入项目目录
cd cloudnative-go-journey-plan

# 运行压测
k6 run k6-tests/hpa-test.js
```

**输出示例**：

```
         /\      Grafana   /‾‾/  
    /\  /  \     |\  __   /  /   
   /  \/    \    | |/ /  /   ‾‾\ 
  /          \   |   (  |  (‾)  |
 / __________ \  |_|\_\  \_____/ 

     execution: local
        script: k6-tests/hpa-test.js
        output: -

     scenarios: (100.00%) 1 scenario, 30 max VUs, 10m0s max duration
              * default: Up to 30 looping VUs for 9m30s over 6 stages

INFO[0000] 🚀 Starting HPA Load Test (Light Version)...
INFO[0000] 📍 Target: http://127.0.0.1:53163
INFO[0000] ✅ Health check passed
INFO[0000] ⏰ Test duration: ~9.5 minutes
INFO[0000] 💡 This is a LIGHT version with reduced load
```

### 5.3 实时观察

**观察终端 2 - HPA 变化**：

```
TIME    TARGETS         REPLICAS
00:00   5%/70%, 15%/80%    2        ← 初始状态
01:00   25%/70%, 30%/80%   2        ← 负载上升（预热）
02:00   55%/70%, 50%/80%   2        ← 接近阈值
03:00   85%/70%, 65%/80%   4        ← ⭐ 扩容：CPU 超标
04:00   75%/70%, 60%/80%   4        ← 负载分散
05:00   65%/70%, 55%/80%   4        ← 趋于稳定
06:00   45%/70%, 40%/80%   4        ← 负载下降（降压）
07:00   20%/70%, 25%/80%   4        ← 等待稳定窗口
...     (5 分钟稳定窗口)
12:00   15%/70%, 20%/80%   3        ← ⭐ 缩容：4 → 3
13:00   10%/70%, 18%/80%   2        ← ⭐ 缩容：3 → 2
```

**观察终端 3 - Pod 变化**：

```
TIME    NAME                               STATUS
03:00   cloudnative-api-xxx-aaa            Running  ← 原有
03:00   cloudnative-api-xxx-bbb            Running  ← 原有
03:01   cloudnative-api-xxx-ccc            Pending  ← ⭐ 新建
03:01   cloudnative-api-xxx-ddd            Pending  ← ⭐ 新建
03:02   cloudnative-api-xxx-ccc            Running  ← 就绪
03:02   cloudnative-api-xxx-ddd            Running  ← 就绪
...
12:00   cloudnative-api-xxx-ddd            Terminating  ← ⭐ 缩容
13:00   cloudnative-api-xxx-ccc            Terminating  ← ⭐ 缩容
```

**观察终端 4 - 资源使用**：

```
=== 02:00:00 ===
NAME                               CPU(cores)   MEMORY(bytes)
cloudnative-api-xxx-aaa            120m         145Mi
cloudnative-api-xxx-bbb            115m         140Mi

=== 03:00:00 ===  ← 高负载
cloudnative-api-xxx-aaa            185m         180Mi
cloudnative-api-xxx-bbb            180m         175Mi

=== 04:00:00 ===  ← 扩容后
cloudnative-api-xxx-aaa            95m          120Mi
cloudnative-api-xxx-bbb            92m          118Mi
cloudnative-api-xxx-ccc            88m          115Mi
cloudnative-api-xxx-ddd            90m          120Mi
```

---

## 六、压测结果分析

### 6.1 k6 指标解读

**测试完成后，k6 输出完整报告**：

```
 █ THRESHOLDS

    http_req_duration
    ✓ 'p(95)<5000' p(95)=983.18ms        ← ⭐ 优秀！

    http_req_failed
    ✓ 'rate<0.2' rate=0.00%              ← ⭐ 完美！


 █ TOTAL RESULTS

    checks_total.......: 6370    11.147425/s
    checks_succeeded...: 100.00% 6370 out of 6370  ← ⭐ 100% 通过
    checks_failed......: 0.00%   0 out of 6370

    ✓ CPU test: status is 200
    ✓ CPU test: has body
    ✓ Memory test: status is 200
    ✓ Memory test: has body

    CUSTOM
    cpu_duration...................: avg=15.434094  min=0.6725   med=14.8267   max=86.8117   p(90)=32.08456  p(95)=36.51136
    cpu_requests...................: 1619   2.833231/s
    memory_duration................: avg=961.947939 min=933.8644 med=960.23395 max=1107.1016 p(90)=983.36405 p(95)=992.5427
    memory_requests................: 1566   2.740482/s

    HTTP
    http_req_duration..............: avg=480.66ms   min=672.5µs  med=48.86ms   max=1.1s      p(90)=974.02ms  p(95)=983.18ms
      { expected_response:true }...: avg=480.66ms   min=672.5µs  med=48.86ms   max=1.1s      p(90)=974.02ms  p(95)=983.18ms
    http_req_failed................: 0.00%  0 out of 3186    ← ⭐ 零失败
    http_reqs......................: 3186   5.575462/s

    EXECUTION
    iteration_duration.............: avg=3.47s      min=2.01s    med=3.46s     max=4.98s     p(90)=4.55s     p(95)=4.77s
    iterations.....................: 3185   5.573712/s
    vus............................: 1      min=1         max=30
    vus_max........................: 30     min=30        max=30

    NETWORK
    data_received..................: 922 kB 1.6 kB/s
    data_sent......................: 354 kB 619 B/s

running (09m31.4s), 00/30 VUs, 3185 complete and 0 interrupted iterations
default ✓ [======================================] 00/30 VUs  9m30s
```

### 6.2 性能评估

**关键指标评分**：

| 指标 | 结果 | 行业标准 | 评分 |
|------|------|---------|------|
| **P95 响应时间** | 983ms | < 2000ms | ⭐⭐⭐⭐⭐ 优秀 |
| **P50 响应时间** | 48.86ms | < 500ms | ⭐⭐⭐⭐⭐ 优秀 |
| **请求成功率** | 100% | > 99% | ⭐⭐⭐⭐⭐ 完美 |
| **请求失败率** | 0% | < 1% | ⭐⭐⭐⭐⭐ 完美 |
| **检查通过率** | 100% | > 95% | ⭐⭐⭐⭐⭐ 完美 |

**响应时间分析**：

```
HTTP 请求耗时分布：
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
最小值:    672.5µs  ← CPU 请求（极快！）
P50:       48.86ms  ← 50% 的请求都很快
平均值:    480.66ms ← 被内存请求拉高
P90:       974.02ms
P95:       983.18ms ← 95% 在 1 秒内
最大值:    1.1s     ← 内存请求（可接受）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**关键发现**：
- ✅ 中位数只有 48.86ms → 大部分请求非常快
- ✅ 平均值 480ms vs 中位数 48ms → 少数内存请求拉高平均值（正常）
- ✅ P95 = 983ms < 1s → 95% 的请求在 1 秒内完成

**CPU vs 内存请求对比**：

| 类型 | 请求数 | 平均耗时 | P95 耗时 | 说明 |
|------|--------|---------|---------|------|
| **CPU** | 1619 | 15.43ms | 36.51ms | 非常快 ✅ |
| **内存** | 1566 | 961.95ms | 992.54ms | 符合预期（1-2秒持有）✅ |

### 6.3 HPA 效果分析

**扩容表现**：

```
T+0:00   负载开始上升
T+2:30   CPU 达到 85%/70%（超过阈值）
T+2:45   HPA 触发扩容：2 → 4
T+3:00   新 Pod 创建完成
T+3:15   新 Pod 接管流量
T+3:30   CPU 降至 65%/70%（低于阈值）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
扩容延迟: ~45 秒（优秀）
```

**缩容表现**：

```
T+6:00   负载下降，CPU 降至 45%/70%
T+6:00   进入稳定窗口（300 秒）
T+11:00  稳定窗口结束，开始缩容：4 → 3
T+12:00  继续缩容：3 → 2
T+12:30  回到 minReplicas
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
缩容延迟: ~6 分钟（符合设计）
```

**HPA 评分**：

| 维度 | 评分 | 说明 |
|------|------|------|
| **扩容速度** | ⭐⭐⭐⭐⭐ | 45 秒完成，响应及时 |
| **扩容准确性** | ⭐⭐⭐⭐⭐ | 从 2 扩到 4，符合计算公式 |
| **缩容平滑性** | ⭐⭐⭐⭐⭐ | 5 分钟稳定窗口，避免抖动 |
| **指标准确性** | ⭐⭐⭐⭐⭐ | TARGETS 实时显示，无 unknown |
| **整体稳定性** | ⭐⭐⭐⭐⭐ | 0 次 Pod 重启，0 次 OOM |

### 6.4 与行业标准对比

| 指标 | 行业标准 | 我的集群 | 评价 |
|------|---------|---------|------|
| **可用性** | 99.9% (SLA) | **100%** | ✅ 超越 |
| **P95 响应时间** | < 2s | **983ms** | ✅ 优秀 |
| **P99 响应时间** | < 5s | **~1.1s** | ✅ 优秀 |
| **错误率** | < 1% | **0%** | ✅ 完美 |
| **HPA 响应速度** | < 60s | **45s** | ✅ 优秀 |
| **资源利用率** | 60-80% | **65%** | ✅ 理想 |

**结论**：**达到生产级别的性能标准！**

---

## 七、问题诊断与优化

### 7.1 CrashLoopBackOff 问题

**完整的问题诊断过程**：

**Step 1: 发现问题**

```bash
$ kubectl get pods
NAME                             STATUS             RESTARTS
cloudnative-api-d99d4f9c-hj9x5   CrashLoopBackOff   4 (49s ago)
```

**Step 2: 查看事件**

```bash
$ kubectl describe pod cloudnative-api-d99d4f9c-hj9x5 | grep -A 20 Events
Events:
  Warning  Unhealthy  Readiness probe failed: connection refused
  Warning  BackOff    Back-off restarting failed container api
```

**Step 3: 查看日志**

```bash
$ kubectl logs cloudnative-api-d99d4f9c-hj9x5 --previous
2025/11/02 08:24:26 ✅ Redis connected successfully
2025/11/02 08:24:26 🚀 Server starting on port 8080...
2025/11/02 08:24:33 [GET] /api/v1/workload/cpu | Status: 200
...
```

**关键发现**：
- ✅ 应用启动成功
- ✅ 正常处理请求
- ❌ 但被探针误杀了

**Step 4: 分析原因**

```
应用处理大量请求 → CPU 100%
↓
就绪探针 3 秒超时 → 无法响应
↓
连续失败 3 次（15 秒）→ 被标记为 Unhealthy
↓
Kubernetes 重启 Pod
```

**Step 5: 解决方案**

调整探针配置（见 [4.3](#43-优化探针配置)）。

### 7.2 内存占用分析

**问题：为什么 CPU 负载也会导致内存占用高？**

**原因分析**：

k6 测试脚本的设计：

```javascript
export default function () {
  const testType = Math.random();
  
  if (testType < 0.5) {
    testCPUWorkload();      // 50% CPU 请求
  } else {
    testMemoryWorkload();   // 50% 内存请求 ← 这个分配内存！
  }
}
```

**内存占用计算**：

```
30 并发用户
× 50% 内存请求
× 平均 30MB 分配
= 450MB

加上：
+ Go 运行时: ~50MB
+ HTTP 缓冲区: ~30MB
+ Goroutine 栈: ~20MB
= 总计 ~550MB

如果 limits: 256Mi → OOM！
如果 limits: 512Mi → 正常
```

**验证**：

```bash
$ kubectl top pods -l app=cloudnative-api
NAME                               CPU(cores)   MEMORY(bytes)
cloudnative-api-xxx-aaa            185m         180Mi  ← 正常
cloudnative-api-xxx-bbb            180m         175Mi  ← 正常
```

### 7.3 优化历程

**第 1 次压测：失败**

```yaml
resources:
  limits:
    memory: "256Mi"  # 不够
    cpu: "300m"

readinessProbe:
  timeoutSeconds: 3      # 太短
  failureThreshold: 3    # 太少
```

**结果**：
- ❌ OOMKilled
- ❌ CrashLoopBackOff
- ❌ 压测中断

**第 2 次压测：成功**

```yaml
resources:
  limits:
    memory: "512Mi"  # ✅ 翻倍
    cpu: "500m"      # ✅ 提高

readinessProbe:
  timeoutSeconds: 10     # ✅ 增加
  failureThreshold: 6    # ✅ 增加
```

**结果**：
- ✅ 0 次 OOM
- ✅ 0 次重启
- ✅ 100% 成功率
- ✅ 压测顺利完成

---

## 八、最佳实践总结

### 8.1 资源配置建议

**基于压测结果的推荐配置**：

```yaml
# API 服务（中等负载）
resources:
  requests:
    cpu: "100m"      # HPA 基准，容易触发扩容
    memory: "128Mi"  # HPA 基准
  limits:
    cpu: "500m"      # 5 倍突发空间
    memory: "512Mi"  # 4 倍突发空间

# 如果是高并发场景，可以进一步提高：
resources:
  limits:
    cpu: "1000m"     # 1 核
    memory: "1Gi"    # 1G
```

**配置原则**：

1. **requests 保守**：确保 Pod 容易调度，HPA 容易触发
2. **limits 充足**：给突发负载足够的缓冲空间
3. **比例合理**：limits = requests × 4-5（CPU），× 4-8（内存）

### 8.2 探针配置建议

```yaml
# 启动探针（快速检测启动）
startupProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 0
  periodSeconds: 2       # 快速检测
  timeoutSeconds: 2
  failureThreshold: 15   # 最多等 30 秒

# 存活探针（避免误杀）
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 15
  periodSeconds: 15      # 降低频率
  timeoutSeconds: 10     # ⭐ 关键：高负载下需要更长时间
  failureThreshold: 5    # 允许失败 75 秒

# 就绪探针（适应负载变化）
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 10     # ⭐ 关键：高负载下需要更长时间
  failureThreshold: 6    # 允许失败 60 秒
```

**关键原则**：
- startupProbe 快（2 秒周期）
- livenessProbe 慢（15 秒周期）
- readinessProbe 中等（10 秒周期）
- **高负载场景增加 timeout 和 failureThreshold**

### 8.3 HPA 配置建议

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: your-api
  
  minReplicas: 2       # 高可用：至少 2 个
  maxReplicas: 10      # 根据流量峰值设置
  
  metrics:
  # ⭐ 始终配置双指标
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70      # 60-70% 是合理范围
  
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80      # 70-80%，留更多 buffer
  
  behavior:
    # ⭐ 快速扩容
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100                  # 可以翻倍
        periodSeconds: 15
      - type: Pods
        value: 2
        periodSeconds: 60
      selectPolicy: Max             # 选择更激进的策略
    
    # ⭐ 保守缩容
    scaleDown:
      stabilizationWindowSeconds: 300  # 5 分钟稳定期
      policies:
      - type: Pods
        value: 1                    # 每次只减 1 个
        periodSeconds: 60
      selectPolicy: Min             # 选择保守策略
```

### 8.4 压测策略建议

**压测脚本设计**：

1. **分阶段测试**
   - 预热（30s）→ 增压（1m）→ 高峰（3m）→ 降压（2m）→ 冷却（1m）
   
2. **混合负载**
   - CPU 密集型 + 内存密集型
   - 模拟真实业务场景
   
3. **随机参数**
   - 请求参数随机化
   - 模拟不同用户行为
   
4. **合理的并发**
   - 本地测试：20-30 VU
   - 生产验证：50-100 VU
   - 极限测试：200+ VU

**监控要点**：

- ✅ HPA 扩缩容过程
- ✅ Pod 状态变化
- ✅ 资源使用情况
- ✅ 错误率和响应时间
- ✅ 系统日志

---

## 九、v0.3 完整总结

### 9.1 学习成果

通过 v0.3 的开发和压测，我掌握了：

**1. 弹性伸缩理论**
- ✅ HPA 工作原理和计算公式
- ✅ Metrics Server 架构和作用
- ✅ 资源管理（requests/limits）
- ✅ Pod QoS 和资源保证

**2. HPA 实战配置**
- ✅ 编写 HPA YAML 配置
- ✅ 配置 CPU 和内存双指标
- ✅ 调优 behavior 策略
- ✅ 调试和排查 HPA 问题

**3. 性能测试技能**
- ✅ 使用 k6 编写压测脚本
- ✅ 设计多阶段测试场景
- ✅ 分析性能指标（P50、P95、P99）
- ✅ 验证系统稳定性

**4. 问题诊断能力**
- ✅ 诊断 OOMKilled 问题
- ✅ 解决探针超时问题
- ✅ 分析内存占用原因
- ✅ 迭代优化配置

### 9.2 核心配置

**Deployment 资源配置**：

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"      # 5 倍突发
    memory: "512Mi"  # 4 倍突发
```

**HPA 配置**：

```yaml
minReplicas: 2
maxReplicas: 10
metrics:
- CPU: 70%
- Memory: 80%
behavior:
- scaleUp: 立即响应（0s 稳定窗口）
- scaleDown: 保守缩容（300s 稳定窗口）
```

**探针配置**：

```yaml
readinessProbe:
  timeoutSeconds: 10      # 高负载适配
  failureThreshold: 6     # 避免误杀
livenessProbe:
  timeoutSeconds: 10
  failureThreshold: 5
```

### 9.3 性能指标

**压测结果**：

| 指标 | 数值 | 评价 |
|------|------|------|
| **总请求数** | 3186 | - |
| **成功率** | 100% | ⭐⭐⭐⭐⭐ |
| **失败率** | 0% | ⭐⭐⭐⭐⭐ |
| **P50 响应时间** | 48.86ms | ⭐⭐⭐⭐⭐ |
| **P95 响应时间** | 983ms | ⭐⭐⭐⭐⭐ |
| **P99 响应时间** | ~1.1s | ⭐⭐⭐⭐⭐ |
| **吞吐量** | 5.58 req/s | 符合预期 |
| **HPA 扩容延迟** | 45s | ⭐⭐⭐⭐⭐ |
| **Pod 重启次数** | 0 | ⭐⭐⭐⭐⭐ |

**HPA 行为**：

```
初始副本: 2
扩容到: 4（CPU 超过 70%）
扩容延迟: ~45 秒
缩容延迟: ~6 分钟（含 5 分钟稳定窗口）
最终副本: 2（回到 minReplicas）
```

---

## 结语

这篇文章标志着 **v0.3 弹性伸缩版**的圆满完成！

### 🎉 成就解锁

- ✅ 成功配置 HPA，实现自动扩缩容
- ✅ 使用 k6 进行专业的负载测试
- ✅ 达到 100% 请求成功率
- ✅ P95 响应时间 < 1 秒
- ✅ 0 次 Pod 崩溃，0 次 OOM
- ✅ 系统性能达到生产级别

### 💡 核心收获

1. **云原生的真正威力**
   - 自动应对流量变化
   - 无需人工干预
   - 提高系统可靠性

2. **资源管理的重要性**
   - requests 是 HPA 的基础
   - limits 保护系统稳定
   - 合理配置是成功的关键

3. **探针配置的艺术**
   - 高负载下需要放宽限制
   - timeout 和 failureThreshold 很重要
   - 避免误杀繁忙的 Pod

4. **性能测试的价值**
   - 发现生产前的问题
   - 验证配置是否合理
   - 建立性能基线

### 🚀 下一步

v0.3 完成后，我已经掌握了 Kubernetes 的核心能力：
- ✅ v0.1: 容器化和基础部署
- ✅ v0.2: 工作负载和配置管理
- ✅ v0.3: 弹性伸缩和性能优化

**后续方向**：
- 服务网格（Istio）
- 可观测性（Prometheus + Grafana）
- CI/CD 流水线
- 生产级别的高可用架构

**感谢你跟随我的云原生之旅！**

---

**系列文章**：
- 上一篇：[HPA 完全指南：从原理到实践](./10-hpa-complete-guide.md)
- v0.3 系列第一篇：[云原生的核心优势：自动弹性伸缩实战](./09-cloud-native-autoscaling-practice.md)

**项目代码**：[GitHub - cloudnative-go-journey](https://github.com/yourusername/cloudnative-go-journey)

