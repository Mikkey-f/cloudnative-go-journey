# k6 性能测试套件

> 为 cloudnative-go-journey 项目编写的完整性能测试套件

## 📋 目录

- [快速开始](#快速开始)
- [测试脚本说明](#测试脚本说明)
- [运行测试](#运行测试)
- [测试类型对比](#测试类型对比)
- [性能指标解读](#性能指标解读)
- [最佳实践](#最佳实践)

---

## 🚀 快速开始

### 1. 安装 k6

**Windows:**
```powershell
# 使用 Chocolatey
choco install k6

# 或使用 winget
winget install k6 --source winget
```

**macOS:**
```bash
brew install k6
```

**Linux:**
```bash
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6
```

### 2. 启动被测试的 API 服务

```bash
# 本地启动（开发环境）
cd ../src
go run main.go

# 或者 K8s 环境
kubectl port-forward svc/api-service 8080:80
```

### 3. 运行第一个测试

```bash
cd k6-tests
k6 run 01-simple-test.js
```

---

## 📂 测试脚本说明

| 脚本名称 | 测试类型 | 用途 | 持续时间 | 推荐场景 |
|---------|---------|------|---------|---------|
| `01-simple-test.js` | 基础测试 | 入门学习，验证基本功能 | 10 秒 | 开发阶段 |
| `02-with-checks.js` | 功能测试 | 带断言验证，确保接口正确性 | 20 秒 | CI/CD 流水线 |
| `03-virtual-users.js` | 负载测试 | 模拟并发用户，测试基本性能 | 30 秒 | 功能完成后 |
| `04-real-world-scenario.js` | 场景测试 | 模拟真实用户行为 | 2.5 分钟 | 上线前验证 |
| `05-post-requests.js` | 写入测试 | 测试 POST/DELETE 等写操作 | 30 秒 | 数据接口测试 |
| `06-stress-test.js` | 压力测试 | 找到系统性能极限 | 11 分钟 | 容量规划 |
| `07-spike-test.js` | 峰值测试 | 测试突发流量下的表现 | 3 分钟 | 秒杀/热点准备 |
| `08-soak-test.js` | 浸泡测试 | 发现内存泄漏等长期问题 | 2+ 小时 | 上线前必测 |

---

## ▶️ 运行测试

### 基础运行

```bash
# 运行指定脚本
k6 run 01-simple-test.js

# 指定自定义参数
k6 run --vus 10 --duration 30s 03-virtual-users.js

# 指定环境变量
k6 run --env BASE_URL=http://production.example.com 04-real-world-scenario.js
```

### 高级运行

```bash
# 输出结果到文件
k6 run --out json=results.json 06-stress-test.js

# 静默模式（只显示摘要）
k6 run --quiet 01-simple-test.js

# 使用配置文件
k6 run --config config.json 04-real-world-scenario.js

# 分布式测试（需要 k6 Cloud）
k6 cloud 06-stress-test.js
```

### 在 K8s 中运行

```bash
# 端口转发到本地
kubectl port-forward svc/api-service 8080:80

# 在另一个终端运行测试
k6 run --env BASE_URL=http://localhost:8080 04-real-world-scenario.js
```

### 结合 Grafana 可视化

```bash
# 输出到 InfluxDB
k6 run --out influxdb=http://localhost:8086/k6 06-stress-test.js

# 在 Grafana 中查看实时结果
# Dashboard: https://grafana.com/grafana/dashboards/2587
```

---

## 📊 测试类型对比

### 1. 负载测试 (Load Test)
**目标:** 验证系统在预期负载下的性能  
**场景:** 日常运营，预估有 100 个并发用户

```javascript
stages: [
  { duration: '5m', target: 100 },   // 逐渐升到 100 VU
  { duration: '10m', target: 100 },  // 维持 100 VU
  { duration: '5m', target: 0 },     // 降到 0
]
```

### 2. 压力测试 (Stress Test)
**目标:** 找到系统的性能极限  
**场景:** 不断增加负载，直到系统崩溃

```javascript
stages: [
  { duration: '2m', target: 100 },
  { duration: '2m', target: 200 },
  { duration: '2m', target: 300 },  // 持续增加
]
```

### 3. 峰值测试 (Spike Test)
**目标:** 测试系统对突发流量的处理能力  
**场景:** 秒杀活动，流量突然暴涨

```javascript
stages: [
  { duration: '10s', target: 10 },
  { duration: '10s', target: 500 },  // 💥 突然暴涨
  { duration: '10s', target: 10 },
]
```

### 4. 浸泡测试 (Soak Test)
**目标:** 发现内存泄漏、资源耗尽等长期问题  
**场景:** 系统需要 7×24 小时运行

```javascript
stages: [
  { duration: '5m', target: 50 },
  { duration: '24h', target: 50 },  // 🕐 长时间运行
]
```

---

## 📈 性能指标解读

### 核心指标

| 指标名称 | 含义 | 好坏标准 |
|---------|------|---------|
| `http_req_duration` | HTTP 请求响应时间 | P95 < 500ms ✅ |
| `http_req_failed` | 请求失败率 | < 1% ✅ |
| `http_reqs` | 总请求数 | 越多越好（QPS） |
| `vus` | 虚拟用户数 | 并发量 |
| `checks` | 断言通过率 | > 95% ✅ |
| `iteration_duration` | 迭代耗时 | 包含 sleep 时间 |

### 响应时间分位值

```
avg=45ms     平均响应时间
min=32ms     最快的请求
med=43ms     中位数（50%）
max=520ms    最慢的请求
p(90)=56ms   90% 的请求在 56ms 内完成
p(95)=67ms   95% 的请求在 67ms 内完成 ← 最重要！
p(99)=120ms  99% 的请求在 120ms 内完成
```

### 示例输出解读

```
✅ 状态码是 200................: 100.00% ✓ 150   ✗ 0  
   ↑ 断言名称                    ↑ 通过率  ↑成功  ↑失败

http_req_duration..............: avg=45.67ms p(95)=67ms
   ↑ 指标名称                    ↑ 平均值    ↑ 95分位值

http_reqs......................: 150     5/s
   ↑ 总请求数                    ↑ 数量  ↑ QPS
```

---

## 🎯 最佳实践

### 1. 从小到大，循序渐进

```bash
# ❌ 错误：直接跑压力测试
k6 run 06-stress-test.js

# ✅ 正确：先跑基础测试
k6 run 01-simple-test.js      # 验证功能
k6 run 03-virtual-users.js    # 测试基本性能
k6 run 06-stress-test.js      # 最后压力测试
```

### 2. 设置合理的阈值

```javascript
thresholds: {
  // ✅ 好：根据 SLA 设置
  'http_req_duration': ['p(95)<500', 'p(99)<1000'],
  
  // ❌ 差：过于严格或宽松
  'http_req_duration': ['avg<10'],  // 太严格，很难达到
  'http_req_duration': ['p(99)<10000'],  // 太宽松，没有意义
}
```

### 3. 模拟真实场景

```javascript
// ✅ 好：模拟真实用户行为
export default function () {
  http.get('/api/products');        // 浏览商品
  sleep(2);                          // 思考 2 秒
  http.get('/api/products/123');    // 查看详情
  sleep(5);                          // 思考 5 秒
  http.post('/api/cart', payload);  // 加入购物车
}

// ❌ 差：不停发请求，无间隔
export default function () {
  http.get('/api/products');
  http.get('/api/products');
  http.get('/api/products');
}
```

### 4. 监控系统资源

性能测试时，同时监控：

```bash
# 监控 Pod 资源
kubectl top pods -l app=api

# 监控节点资源
kubectl top nodes

# 实时查看日志
kubectl logs -f api-server-xxx

# 查看指标
curl http://localhost:8080/metrics
```

### 5. 分析失败原因

```bash
# 查看详细输出
k6 run --verbose 06-stress-test.js

# 输出 JSON 格式便于分析
k6 run --out json=results.json 06-stress-test.js
```

---

## 🔧 配置文件示例

创建 `config.json`:

```json
{
  "vus": 10,
  "duration": "30s",
  "thresholds": {
    "http_req_duration": ["p(95)<500"],
    "http_req_failed": ["rate<0.01"]
  },
  "env": {
    "BASE_URL": "http://localhost:8080"
  }
}
```

使用配置文件:

```bash
k6 run --config config.json 04-real-world-scenario.js
```

---

## 📝 CI/CD 集成示例

### GitHub Actions

```yaml
name: Performance Test

on:
  push:
    branches: [ main ]

jobs:
  k6-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup k6
        run: |
          curl https://github.com/grafana/k6/releases/download/v0.48.0/k6-v0.48.0-linux-amd64.tar.gz -L | tar xvz
          sudo mv k6-v0.48.0-linux-amd64/k6 /usr/local/bin/
      
      - name: Run k6 test
        run: |
          k6 run k6-tests/02-with-checks.js
      
      - name: Upload results
        uses: actions/upload-artifact@v3
        with:
          name: k6-results
          path: summary.json
```

---

## 🐛 故障排查

### 问题 1: Connection refused

```bash
# 原因：API 服务未启动
# 解决：
cd ../src
go run main.go
```

### 问题 2: 请求全部失败

```bash
# 检查 URL 是否正确
k6 run --env BASE_URL=http://localhost:8080 04-real-world-scenario.js
```

### 问题 3: 性能差

```bash
# 检查系统资源
kubectl top pods
kubectl describe pod api-server-xxx

# 查看日志
kubectl logs api-server-xxx
```

---

## 📚 参考资源

- [k6 官方文档](https://grafana.com/docs/k6/latest/)
- [k6 测试类型指南](https://grafana.com/docs/k6/latest/testing-guides/test-types/)
- [Grafana k6 Dashboard](https://grafana.com/grafana/dashboards/2587)

---

## 🤝 贡献

欢迎贡献更多测试场景！请提交 PR。

## 📄 许可

MIT License

