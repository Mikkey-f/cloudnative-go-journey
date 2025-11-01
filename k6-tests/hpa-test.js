/**
 * k6 HPA 负载测试脚本
 * 
 * 用途：验证 Kubernetes HPA 自动扩缩容功能
 * 测试目标：cloudnative-api v0.3
 * 
 * 运行方式：
 * k6 run k6-tests/hpa-test.js
 * 
 * 或者指定环境变量：
 * BASE_URL=http://localhost:30080 k6 run k6-tests/hpa-test.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Trend } from 'k6/metrics';

// ============= 配置 =============

// 获取环境变量或使用默认值
const BASE_URL = __ENV.BASE_URL || 'http://localhost:30080';

// ============= 自定义指标 =============

const cpuRequests = new Counter('cpu_requests');
const memoryRequests = new Counter('memory_requests');
const mixedRequests = new Counter('mixed_requests');

const cpuDuration = new Trend('cpu_duration');
const memoryDuration = new Trend('memory_duration');

// ============= 测试选项 =============

export let options = {
  // 测试阶段
  stages: [
    // 阶段 1: 预热（30 秒）
    { duration: '30s', target: 5 },
    
    // 阶段 2: 缓慢增压（1 分钟）
    { duration: '1m', target: 20 },
    
    // 阶段 3: 激增负载（2 分钟）- 触发扩容
    { duration: '2m', target: 100 },
    
    // 阶段 4: 保持高负载（3 分钟）- 观察扩容效果
    { duration: '3m', target: 100 },
    
    // 阶段 5: 缓慢降压（2 分钟）
    { duration: '2m', target: 20 },
    
    // 阶段 6: 完全冷却（1 分钟）- 观察缩容
    { duration: '1m', target: 5 },
  ],
  
  // 性能阈值
  thresholds: {
    'http_req_duration': ['p(95)<2000'],  // 95% 请求在 2 秒内完成
    'http_req_failed': ['rate<0.1'],      // 错误率低于 10%
  },
};

// ============= 测试场景 =============

export default function () {
  // 根据虚拟用户 ID 选择不同的负载类型
  const userId = __VU % 3;
  
  if (userId === 0) {
    // CPU 密集型负载
    testCPUWorkload();
  } else if (userId === 1) {
    // 内存密集型负载
    testMemoryWorkload();
  } else {
    // 混合负载
    testMixedWorkload();
  }
  
  // 随机等待 1-3 秒
  sleep(Math.random() * 2 + 1);
}

// ============= 辅助函数 =============

/**
 * CPU 密集型测试
 */
function testCPUWorkload() {
  const intensity = Math.floor(Math.random() * 30) + 20;  // 20-50
  const url = `${BASE_URL}/api/v1/workload/cpu?iterations=${intensity * 1000000}`;
  
  const res = http.get(url);
  
  const success = check(res, {
    'CPU test: status is 200': (r) => r.status === 200,
    'CPU test: has result': (r) => r.json('result') !== undefined,
    'CPU test: completed': (r) => r.json('message') === 'CPU intensive task completed',
  });
  
  if (success) {
    cpuRequests.add(1);
    cpuDuration.add(res.timings.duration);
  }
}

/**
 * 内存密集型测试
 */
function testMemoryWorkload() {
  const sizeMB = Math.floor(Math.random() * 40) + 30;  // 30-70 MB
  const duration = Math.floor(Math.random() * 2) + 2;  // 2-4 秒
  const url = `${BASE_URL}/api/v1/workload/memory?size=${sizeMB}&duration=${duration}`;
  
  const res = http.get(url);
  
  const success = check(res, {
    'Memory test: status is 200': (r) => r.status === 200,
    'Memory test: allocated': (r) => r.json('allocated_mb') !== undefined,
    'Memory test: completed': (r) => r.json('message') === 'Memory intensive task completed',
  });
  
  if (success) {
    memoryRequests.add(1);
    memoryDuration.add(res.timings.duration);
  }
}

/**
 * 混合负载测试
 */
function testMixedWorkload() {
  const intensity = Math.floor(Math.random() * 30) + 20;  // 20-50
  const url = `${BASE_URL}/api/v1/workload?type=mixed&intensity=${intensity}`;
  
  const res = http.get(url);
  
  const success = check(res, {
    'Mixed test: status is 200': (r) => r.status === 200,
    'Mixed test: has result': (r) => r.json('result') !== undefined,
    'Mixed test: type is mixed': (r) => r.json('workload_type') === 'mixed',
  });
  
  if (success) {
    mixedRequests.add(1);
  }
}

// ============= 生命周期钩子 =============

/**
 * 初始化阶段（测试开始前执行一次）
 */
export function setup() {
  console.log('🚀 Starting HPA Load Test...');
  console.log(`📍 Target: ${BASE_URL}`);
  
  // 健康检查
  const healthRes = http.get(`${BASE_URL}/health`);
  if (healthRes.status !== 200) {
    throw new Error('❌ Health check failed! Is the service running?');
  }
  
  console.log('✅ Health check passed');
  console.log('⏰ Test duration: ~9.5 minutes');
  console.log('');
  console.log('📊 Monitoring tips:');
  console.log('  Watch HPA:   kubectl get hpa cloudnative-api-hpa -w');
  console.log('  Watch Pods:  kubectl get pods -l app=cloudnative-api -w');
  console.log('  Watch CPU:   kubectl top pods -l app=cloudnative-api');
  console.log('');
  
  return { startTime: new Date() };
}

/**
 * 清理阶段（测试结束后执行一次）
 */
export function teardown(data) {
  const endTime = new Date();
  const duration = (endTime - data.startTime) / 1000;
  
  console.log('');
  console.log('🏁 Test completed!');
  console.log(`⏱️  Total duration: ${duration.toFixed(1)}s`);
  console.log('');
  console.log('📝 Next steps:');
  console.log('  1. Check final HPA status: kubectl describe hpa cloudnative-api-hpa');
  console.log('  2. Check Pod count: kubectl get pods -l app=cloudnative-api');
  console.log('  3. Wait for scale-down (5-10 minutes)');
}

