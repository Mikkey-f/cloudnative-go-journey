# v0.3 完整部署指南

> 从零开始部署 v0.3 弹性伸缩版的完整步骤

---

## 📋 前置检查

### 环境要求

```powershell
# 1. 检查 Kubernetes 集群
kubectl version --client
kubectl cluster-info

# 2. 检查节点状态
kubectl get nodes

# 3. 检查 v0.2 是否部署
kubectl get deployment cloudnative-api
kubectl get statefulset redis

# 4. 确认当前目录
pwd
# 应该在: cloudnative-go-journey-plan 根目录
```

### 预期输出

```
✅ kubectl version: v1.28+
✅ 集群状态: running
✅ 节点状态: Ready
✅ v0.2 服务运行正常
```

---

## 🚀 Phase 1: 环境准备

### 步骤 1.1：检查 Metrics Server 状态

```powershell
# 检查是否已安装
kubectl get deployment metrics-server -n kube-system
```

**如果返回 "NotFound"，继续下一步；如果已存在，跳到步骤 1.4**

---

### 步骤 1.2：安装 Metrics Server

```powershell
# 1. 下载并应用 Metrics Server 配置
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# 等待几秒，让资源创建完成
Start-Sleep -Seconds 5

# 2. 修补配置（本地环境必须）
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  }
]'
```

---

### 步骤 1.3：等待 Metrics Server 就绪

```powershell
# 1. 等待 Deployment 可用（最多5分钟）
kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system

# 2. 检查 Pod 状态
kubectl get pods -n kube-system | Select-String "metrics-server"

# 3. 检查日志（如果有问题）
kubectl logs -n kube-system deployment/metrics-server --tail=20
```

**预期输出**：
```
deployment.apps/metrics-server condition met

NAME                             READY   STATUS    RESTARTS   AGE
metrics-server-xxxxxxxxxx-xxxxx  1/1     Running   0          2m
```

---

### 步骤 1.4：验证 Metrics Server

```powershell
# 1. 检查 APIService 状态
kubectl get apiservice v1beta1.metrics.k8s.io

# 2. 等待 1-2 分钟让数据采集
Write-Host "等待 Metrics Server 采集数据（需要30-60秒）..." -ForegroundColor Yellow
Start-Sleep -Seconds 60

# 3. 测试 kubectl top（核心验证）
kubectl top nodes

# 4. 查看 Pod 资源使用
kubectl top pods --all-namespaces

# 5. 查看原始 Metrics API
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" | ConvertFrom-Json | ConvertTo-Json -Depth 5
```

**预期输出**：
```powershell
# kubectl get apiservice
NAME                      SERVICE                      AVAILABLE   AGE
v1beta1.metrics.k8s.io    kube-system/metrics-server   True        3m

# kubectl top nodes
NAME             CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
docker-desktop   150m         1%     2000Mi          25%

# kubectl top pods
NAMESPACE     NAME                              CPU(cores)   MEMORY(bytes)
default       cloudnative-api-xxxxxxxxx-xxxxx   1m           45Mi
default       redis-0                           2m           15Mi
```

**✅ Phase 1 完成标志**：`kubectl top nodes` 和 `kubectl top pods` 都能正常输出数据

---

## 💻 Phase 2: 代码开发

### 步骤 2.1：创建负载测试接口

```powershell
# 创建新的 handler 文件
New-Item -ItemType File -Force -Path "src/handler/workload.go"
```

编辑 `src/handler/workload.go`，添加以下内容：

```go
package handler

import (
	"fmt"
	"math"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

// WorkloadHandler 综合负载接口
func WorkloadHandler(c *gin.Context) {
	workloadType := c.DefaultQuery("type", "cpu")
	intensity := getIntParam(c, "intensity", 50)

	startTime := time.Now()
	var result interface{}

	switch workloadType {
	case "cpu":
		result = cpuWorkload(intensity)
	case "memory":
		result = memoryWorkload(intensity)
	case "mixed":
		cpuResult := cpuWorkload(intensity / 2)
		memResult := memoryWorkload(intensity / 2)
		result = gin.H{
			"cpu":    cpuResult,
			"memory": memResult,
		}
	default:
		c.JSON(400, gin.H{"error": "Invalid workload type"})
		return
	}

	duration := time.Since(startTime)

	c.JSON(200, gin.H{
		"workload_type": workloadType,
		"intensity":     intensity,
		"duration_ms":   duration.Milliseconds(),
		"result":        result,
		"message":       "Workload completed successfully",
	})
}

// CPUIntensiveHandler CPU 密集型接口
func CPUIntensiveHandler(c *gin.Context) {
	iterations := getIntParam(c, "iterations", 10000000)

	startTime := time.Now()
	result := cpuWorkload(iterations / 1000000)
	duration := time.Since(startTime)

	c.JSON(200, gin.H{
		"result":       result,
		"iterations":   iterations,
		"duration_ms":  duration.Milliseconds(),
		"message":      "CPU intensive task completed",
	})
}

// MemoryIntensiveHandler 内存密集型接口
func MemoryIntensiveHandler(c *gin.Context) {
	sizeMB := getIntParam(c, "size", 50)
	durationSec := getIntParam(c, "duration", 3)

	startTime := time.Now()
	
	// 分配内存
	data := make([]byte, sizeMB*1024*1024)
	
	// 填充数据（防止编译器优化）
	for i := range data {
		data[i] = byte(i % 256)
	}

	// 持有内存一段时间
	time.Sleep(time.Duration(durationSec) * time.Second)
	
	elapsed := time.Since(startTime)

	c.JSON(200, gin.H{
		"allocated_mb":  sizeMB,
		"duration_sec":  durationSec,
		"actual_ms":     elapsed.Milliseconds(),
		"data_sample":   fmt.Sprintf("%v", data[:10]),
		"message":       "Memory intensive task completed",
	})
}

// cpuWorkload 执行 CPU 密集型计算
func cpuWorkload(intensity int) float64 {
	result := 0.0
	iterations := intensity * 1000000

	for i := 0; i < iterations; i++ {
		result += math.Sqrt(float64(i))
		result += math.Sin(float64(i))
		result += math.Cos(float64(i))
	}

	return result
}

// memoryWorkload 执行内存密集型操作
func memoryWorkload(sizeMB int) int {
	data := make([][]byte, sizeMB)
	
	for i := 0; i < sizeMB; i++ {
		data[i] = make([]byte, 1024*1024)
		for j := range data[i] {
			data[i][j] = byte(j % 256)
		}
	}

	return sizeMB
}

// getIntParam 获取整数参数
func getIntParam(c *gin.Context, key string, defaultValue int) int {
	valueStr := c.DefaultQuery(key, strconv.Itoa(defaultValue))
	value, err := strconv.Atoi(valueStr)
	if err != nil {
		return defaultValue
	}
	return value
}
```

---

### 步骤 2.2：注册新路由

编辑 `src/main.go`，在路由注册部分添加：

```go
// 工作负载测试接口（v0.3 新增）
r.GET("/api/workload", handler.WorkloadHandler)
r.GET("/api/workload/cpu", handler.CPUIntensiveHandler)
r.GET("/api/workload/memory", handler.MemoryIntensiveHandler)
```

---

### 步骤 2.3：构建和测试

```powershell
# 1. 本地运行测试
cd src
go run main.go

# 2. 在另一个终端测试接口
# CPU 测试
curl http://localhost:8080/api/workload/cpu?iterations=5000000

# 内存测试
curl http://localhost:8080/api/workload/memory?size=50&duration=3

# 综合测试
curl "http://localhost:8080/api/workload?type=mixed&intensity=30"

# 3. 停止本地服务（Ctrl+C）
```

**预期输出**：所有接口都能正常返回 JSON 响应

---

### 步骤 2.4：构建 Docker 镜像

```powershell
# 回到项目根目录
cd ..

# 构建镜像
docker build -t cloudnative-api:v0.3 -f Dockerfile .

# 验证镜像
docker images | Select-String "cloudnative-api"

# 可选：测试镜像
docker run -d -p 8080:8080 --name test-api cloudnative-api:v0.3
Start-Sleep -Seconds 3
curl http://localhost:8080/health
docker stop test-api
docker rm test-api
```

**✅ Phase 2 完成标志**：镜像构建成功，接口能正常工作

---

## ⚙️ Phase 3: K8s 配置

### 步骤 3.1：创建 v0.3 配置目录

```powershell
# 创建目录结构
New-Item -ItemType Directory -Force -Path "k8s/v0.3"
New-Item -ItemType Directory -Force -Path "k8s/v0.3/api"

# 复制 v0.2 配置作为基础
Copy-Item "k8s/v0.2/api/deployment.yaml" -Destination "k8s/v0.3/api/deployment.yaml"
Copy-Item "k8s/v0.2/api/service.yaml" -Destination "k8s/v0.3/api/service.yaml"
Copy-Item "k8s/v0.2/api/configmap.yaml" -Destination "k8s/v0.3/api/configmap.yaml"
```

---

### 步骤 3.2：更新 Deployment 配置

编辑 `k8s/v0.3/api/deployment.yaml`：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudnative-api
  labels:
    app: cloudnative-api
    version: v0.3
spec:
  replicas: 2  # 初始副本数（HPA 会管理）
  selector:
    matchLabels:
      app: cloudnative-api
  template:
    metadata:
      labels:
        app: cloudnative-api
        version: v0.3
    spec:
      containers:
      - name: api
        image: cloudnative-api:v0.3
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
          name: http
        
        # 关键：优化资源配置
        resources:
          requests:
            memory: "128Mi"  # 提高基准（v0.2: 64Mi）
            cpu: "100m"      # HPA 基准
          limits:
            memory: "256Mi"  # 2x 突发
            cpu: "300m"      # 3x 突发（v0.2: 500m）
        
        # 健康检查
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 3
        
        # 环境变量
        env:
        - name: REDIS_HOST
          value: "redis-service:6379"
        - name: APP_ENV
          value: "production"
        - name: LOG_LEVEL
          value: "info"
```

---

### 步骤 3.3：创建 HPA 配置

创建 `k8s/v0.3/api/hpa.yaml`：

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: cloudnative-api-hpa
  labels:
    app: cloudnative-api
spec:
  # 扩缩目标
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: cloudnative-api
  
  # 副本数范围
  minReplicas: 2   # 最小2个（高可用）
  maxReplicas: 10  # 最大10个（控制成本）
  
  # 扩缩指标
  metrics:
  # 主要指标：CPU 使用率
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70  # 目标 70%
  
  # 次要指标：内存使用率（可选，先注释）
  # - type: Resource
  #   resource:
  #     name: memory
  #     target:
  #       type: Utilization
  #       averageUtilization: 80
  
  # 扩缩行为控制
  behavior:
    # 缩容行为
    scaleDown:
      stabilizationWindowSeconds: 300  # 5分钟稳定期
      policies:
      - type: Pods
        value: 1            # 每次最多缩容1个
        periodSeconds: 60
      - type: Percent
        value: 10           # 或10%
        periodSeconds: 60
      selectPolicy: Min     # 选择更保守的
    
    # 扩容行为
    scaleUp:
      stabilizationWindowSeconds: 0    # 立即扩容
      policies:
      - type: Pods
        value: 2            # 每次最多增加2个
        periodSeconds: 60
      - type: Percent
        value: 100          # 或翻倍
        periodSeconds: 15
      selectPolicy: Max     # 选择更激进的
```

---

### 步骤 3.4：创建部署脚本

创建 `scripts/deploy-v0.3.ps1`：

```powershell
# v0.3 一键部署脚本

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  CloudNative Go Journey v0.3 部署" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. 检查 Metrics Server
Write-Host "[1/5] 检查 Metrics Server..." -ForegroundColor Yellow
$metricsServer = kubectl get deployment metrics-server -n kube-system 2>$null
if (!$metricsServer) {
    Write-Host "  ❌ Metrics Server 未安装，请先运行 Phase 1" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Metrics Server 已安装" -ForegroundColor Green

# 2. 构建镜像
Write-Host "[2/5] 构建 Docker 镜像..." -ForegroundColor Yellow
docker build -t cloudnative-api:v0.3 -f Dockerfile .
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ 镜像构建失败" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ 镜像构建成功" -ForegroundColor Green

# 3. 部署应用
Write-Host "[3/5] 部署应用..." -ForegroundColor Yellow
kubectl apply -f k8s/v0.3/api/configmap.yaml
kubectl apply -f k8s/v0.3/api/deployment.yaml
kubectl apply -f k8s/v0.3/api/service.yaml
Write-Host "  ✅ 应用部署完成" -ForegroundColor Green

# 4. 等待 Pod 就绪
Write-Host "[4/5] 等待 Pod 就绪..." -ForegroundColor Yellow
kubectl wait --for=condition=available --timeout=120s deployment/cloudnative-api
Write-Host "  ✅ Pod 已就绪" -ForegroundColor Green

# 5. 部署 HPA
Write-Host "[5/5] 部署 HPA..." -ForegroundColor Yellow
kubectl apply -f k8s/v0.3/api/hpa.yaml
Start-Sleep -Seconds 5
Write-Host "  ✅ HPA 部署完成" -ForegroundColor Green

# 显示状态
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  部署状态" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

kubectl get deployment cloudnative-api
Write-Host ""
kubectl get hpa cloudnative-api-hpa
Write-Host ""
kubectl get pods -l app=cloudnative-api

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  部署成功！" -ForegroundColor Green
Write-Host ""
Write-Host "  下一步：运行压测验证 HPA" -ForegroundColor Yellow
Write-Host "  k6 run k6-tests/05-hpa-validation.js" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
```

---

### 步骤 3.5：执行部署

```powershell
# 给脚本添加执行权限（如果需要）
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# 执行部署
./scripts/deploy-v0.3.ps1
```

**预期输出**：
```
✅ Metrics Server 已安装
✅ 镜像构建成功
✅ 应用部署完成
✅ Pod 已就绪
✅ HPA 部署完成

NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
cloudnative-api       2/2     2            2           1m

NAME                      REFERENCE                    TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
cloudnative-api-hpa       Deployment/cloudnative-api   5%/70%    2         10        2          30s
```

**✅ Phase 3 完成标志**：HPA 显示 `TARGETS` 为 `X%/70%`（不是 `<unknown>`）

---

## 🧪 Phase 4: 压测验证

### 步骤 4.1：准备监控终端

打开 4 个 PowerShell 终端：

**终端 1：观察 HPA**
```powershell
kubectl get hpa cloudnative-api-hpa -w
```

**终端 2：观察 Pod**
```powershell
kubectl get pods -l app=cloudnative-api -w
```

**终端 3：观察资源使用**
```powershell
while ($true) {
    Clear-Host
    Write-Host "=== HPA Status ===" -ForegroundColor Green
    kubectl get hpa
    Write-Host "`n=== Pod Resources ===" -ForegroundColor Green
    kubectl top pods -l app=cloudnative-api
    Write-Host "`n=== Pod List ===" -ForegroundColor Green
    kubectl get pods -l app=cloudnative-api
    Start-Sleep -Seconds 5
}
```

**终端 4：查看事件**
```powershell
kubectl get events --sort-by='.lastTimestamp' -w | Select-String "HorizontalPodAutoscaler"
```

---

### 步骤 4.2：创建压测脚本

创建 `k6-tests/05-hpa-validation.js`：

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// 自定义指标
const errorRate = new Rate('errors');

// 压测配置
export let options = {
    stages: [
        { duration: '30s', target: 5 },    // 预热
        { duration: '2m', target: 20 },    // 增压
        { duration: '3m', target: 50 },    // 峰值
        { duration: '2m', target: 20 },    // 降压
        { duration: '2m', target: 0 },     // 冷却
    ],
    thresholds: {
        'http_req_duration': ['p(95)<1000'],
        'errors': ['rate<0.1'],
    },
};

const BASE_URL = 'http://localhost:8080';

export default function() {
    // CPU 密集型请求
    let res = http.get(`${BASE_URL}/api/workload/cpu?iterations=8000000`);
    
    check(res, {
        'status is 200': (r) => r.status === 200,
        'response time < 2s': (r) => r.timings.duration < 2000,
    }) || errorRate.add(1);
    
    sleep(1);
}
```

---

### 步骤 4.3：安装 k6（如果还没有）

```powershell
# Windows 使用 Chocolatey 安装
choco install k6

# 或使用 Scoop
scoop install k6

# 或从官网下载：https://k6.io/docs/get-started/installation/

# 验证安装
k6 version
```

---

### 步骤 4.4：运行压测

```powershell
# 在第 5 个终端运行压测
cd k6-tests
k6 run 05-hpa-validation.js
```

---

### 步骤 4.5：观察扩缩容过程

**预期观察到的变化：**

**阶段 1：预热（0-30秒）**
```
TARGETS: 10%/70%    REPLICAS: 2
- CPU 使用率缓慢上升
```

**阶段 2：增压（30秒-2.5分钟）**
```
TARGETS: 45%/70%    REPLICAS: 2
TARGETS: 85%/70%    REPLICAS: 2  ← 触发扩容条件
TARGETS: 85%/70%    REPLICAS: 3  ← 开始扩容
TARGETS: 70%/70%    REPLICAS: 4
```

**阶段 3：峰值（2.5-5.5分钟）**
```
TARGETS: 95%/70%    REPLICAS: 4
TARGETS: 95%/70%    REPLICAS: 6  ← 继续扩容
TARGETS: 75%/70%    REPLICAS: 7
TARGETS: 68%/70%    REPLICAS: 7  ← 稳定在目标附近
```

**阶段 4：降压（5.5-7.5分钟）**
```
TARGETS: 45%/70%    REPLICAS: 7  ← CPU下降，但还在稳定期
TARGETS: 40%/70%    REPLICAS: 7
```

**阶段 5：冷却（7.5-9.5分钟）**
```
TARGETS: 10%/70%    REPLICAS: 7  ← 等待稳定期（5分钟）
...（等待约5分钟）
TARGETS: 8%/70%     REPLICAS: 6  ← 开始缩容
TARGETS: 5%/70%     REPLICAS: 4
TARGETS: 3%/70%     REPLICAS: 2  ← 缩回最小副本
```

**✅ Phase 4 完成标志**：
- 能触发扩容（2 → 6-8 副本）
- 能触发缩容（回到 2 副本）
- 服务在整个过程保持可用

---

## 🔧 Phase 5: 优化调整

### 步骤 5.1：分析压测结果

```powershell
# 查看 HPA 历史事件
kubectl describe hpa cloudnative-api-hpa

# 查看 Deployment 滚动历史
kubectl rollout history deployment/cloudnative-api

# 导出 HPA 当前配置
kubectl get hpa cloudnative-api-hpa -o yaml > hpa-current.yaml
```

### 步骤 5.2：根据结果调整

**如果扩容太慢**：
```yaml
# 调整 behavior.scaleUp
policies:
- type: Percent
  value: 100      # 增大扩容幅度
  periodSeconds: 15  # 减小评估周期
```

**如果频繁抖动**：
```yaml
# 调整稳定窗口
scaleDown:
  stabilizationWindowSeconds: 600  # 增加到10分钟
```

**如果资源使用率不合适**：
```yaml
# 调整目标使用率或资源配置
metrics:
- type: Resource
  resource:
    name: cpu
    target:
      averageUtilization: 60  # 降低目标（更早扩容）
```

### 步骤 5.3：应用优化

```powershell
# 修改配置后重新应用
kubectl apply -f k8s/v0.3/api/hpa.yaml

# 观察效果
kubectl get hpa -w
```

**✅ Phase 5 完成标志**：扩缩容行为符合预期，性能指标达标

---

## 📝 Phase 6: 文档完善

### 步骤 6.1：记录配置参数

创建 `k8s/v0.3/README.md`，记录最终配置和经验。

### 步骤 6.2：编写博客

参考 `blog/v0.3/` 目录，编写以下博客：
1. HPA 原理和配置
2. 压测验证实战
3. 性能优化经验

**✅ Phase 6 完成标志**：文档完整，博客发布

---

## 🎓 验收测试

### 功能测试清单

- [ ] Metrics Server 正常工作
- [ ] kubectl top 显示数据
- [ ] HPA 显示当前指标
- [ ] 压测能触发扩容
- [ ] 扩容时间 < 2分钟
- [ ] 负载降低后能缩容
- [ ] 缩容稳定期约 5分钟
- [ ] 服务在扩缩过程中保持可用
- [ ] 所有接口正常工作

### 性能指标验证

```powershell
# 1. 记录扩容时间
# 从 TARGETS 超过 70% 到新 Pod Ready 的时间

# 2. 验证资源使用
kubectl top pods -l app=cloudnative-api

# 3. 检查请求成功率（从 k6 输出）
# checks.........................: > 99%
```

---

## 🐛 常见问题排查

### 问题 1：Metrics Server 无法启动

**症状**：
```
kubectl top nodes
Error: Metrics API not available
```

**排查**：
```powershell
# 1. 检查 Pod 状态
kubectl get pods -n kube-system | Select-String "metrics-server"

# 2. 查看日志
kubectl logs -n kube-system deployment/metrics-server

# 3. 常见错误和解决：
# - "unable to fetch metrics" → 添加 --kubelet-insecure-tls
# - "x509: certificate" → 检查证书配置
# - "connection refused" → 检查网络和防火墙
```

---

### 问题 2：HPA 显示 `<unknown>/70%`

**症状**：
```
TARGETS: <unknown>/70%
```

**原因**：
1. Metrics Server 未就绪
2. Pod 刚创建，还没有数据
3. Pod 未设置 resources.requests

**解决**：
```powershell
# 1. 等待 1-2 分钟
# 2. 检查 Pod 是否设置了 requests
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[0].resources.requests}'

# 3. 查看 HPA 事件
kubectl describe hpa cloudnative-api-hpa
```

---

### 问题 3：扩容不触发

**排查**：
```powershell
# 1. 检查当前使用率
kubectl get hpa

# 2. 手动查询 Metrics API
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/namespaces/default/pods" | ConvertFrom-Json

# 3. 检查是否在冷却期
kubectl describe hpa cloudnative-api-hpa | Select-String -Pattern "Condition\|Event"
```

---

### 问题 4：Pod 无法调度

**症状**：
```
Pod status: Pending
Reason: Insufficient cpu/memory
```

**解决**：
```powershell
# 1. 检查节点资源
kubectl describe nodes

# 2. 降低 requests
# 或增加节点资源
```

---

## 📊 成功部署检查表

### 环境检查
- [ ] Kubernetes 集群运行正常
- [ ] Metrics Server 已安装并运行
- [ ] kubectl top 命令正常工作
- [ ] v0.2 服务运行正常

### 代码和镜像
- [ ] 新接口代码已完成
- [ ] Docker 镜像构建成功
- [ ] 镜像标签正确（v0.3）
- [ ] 本地测试通过

### K8s 配置
- [ ] Deployment 配置正确
- [ ] Service 配置正确
- [ ] HPA 配置正确
- [ ] 资源 requests/limits 合理

### 功能验证
- [ ] 应用成功部署
- [ ] Pod 全部 Running
- [ ] HPA 显示正常指标
- [ ] 压测能触发扩缩容

### 性能指标
- [ ] 扩容响应时间 < 2分钟
- [ ] CPU 使用率在目标范围
- [ ] 请求成功率 > 99%
- [ ] P95 延迟 < 500ms（或符合预期）

---

## 🚀 下一步

完成 v0.3 后，你可以：

1. **深入学习** - VPA、KEDA、自定义指标
2. **优化调整** - 根据实际业务调整参数
3. **准备 v0.4** - Ingress 和服务治理
4. **分享经验** - 编写博客，帮助他人

---

**祝贺你完成 v0.3！你已经掌握了云原生弹性伸缩的核心能力！** 🎉

