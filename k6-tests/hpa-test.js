/**
 * k6 HPA 负载测试脚本 - 轻量级版本
 * 
 * 用途：验证 Kubernetes HPA 自动扩缩容功能
 * 测试目标：cloudnative-api v0.3
 * 
 * 运行方式：
 * k6 run k6-tests/hpa-test-light.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Trend } from 'k6/metrics';

// ============= 配置 =============

// 获取环境变量或使用默认值
const BASE_URL = __ENV.BASE_URL || 'http://127.0.0.1:53163';

// 请求超时设置（秒）
const TIMEOUT = '30s';

// ============= 自定义指标 =============

const cpuRequests = new Counter('cpu_requests');
const memoryRequests = new Counter('memory_requests');

const cpuDuration = new Trend('cpu_duration');
const memoryDuration = new Trend('memory_duration');

// ============= 测试选项 =============

export let options = {
  // 测试阶段（更温和的增长曲线）
  stages: [
    // 阶段 1: 预热（30 秒）
    { duration: '30s', target: 3 },
    
    // 阶段 2: 缓慢增压（1 分钟）
    { duration: '1m', target: 10 },
    
    // 阶段 3: 激增负载（2 分钟）- 触发扩容
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
    'http_req_duration': ['p(95)<5000'],  // 95% 请求在 5 秒内完成（放宽）
    'http_req_failed': ['rate<0.2'],      // 错误率低于 20%（放宽）
  },
};

// ============= 测试场景 =============

export default function () {
  // 随机选择负载类型
  const testType = Math.random();
  
  if (testType < 0.5) {
    // 50% - CPU 密集型负载（降低强度）
    testCPUWorkload();
  } else {
    // 50% - 内存密集型负载（降低强度）
    testMemoryWorkload();
  }
  
  // 随机等待 2-4 秒（增加间隔，降低并发压力）
  sleep(Math.random() * 2 + 2);
}

// ============= 辅助函数 =============

/**
 * CPU 密集型测试（降低迭代次数）
 */
function testCPUWorkload() {
  // 降低迭代次数：10-20 百万次（原来是 20-50 百万次）
  const intensity = Math.floor(Math.random() * 10) + 10;
  const url = `${BASE_URL}/api/v1/workload/cpu?iterations=${intensity * 1000000}`;
  
  const params = {
    timeout: TIMEOUT,
  };
  
  const res = http.get(url, params);
  
  const success = check(res, {
    'CPU test: status is 200': (r) => r.status === 200,
    'CPU test: has body': (r) => r.body && r.body.length > 0,
  });
  
  if (success && res.body) {
    try {
      const body = JSON.parse(res.body);
      if (body.result !== undefined) {
        cpuRequests.add(1);
        cpuDuration.add(res.timings.duration);
      }
    } catch (e) {
      console.log(`CPU test JSON parse error: ${e.message}`);
    }
  }
}

/**
 * 内存密集型测试（降低分配大小）
 */
function testMemoryWorkload() {
  // 降低内存分配：20-40 MB（原来是 30-70 MB）
  const sizeMB = Math.floor(Math.random() * 20) + 20;
  // 缩短持续时间：1-2 秒（原来是 2-4 秒）
  const duration = Math.floor(Math.random() * 1) + 1;
  const url = `${BASE_URL}/api/v1/workload/memory?size=${sizeMB}&duration=${duration}`;
  
  const params = {
    timeout: TIMEOUT,
  };
  
  const res = http.get(url, params);
  
  const success = check(res, {
    'Memory test: status is 200': (r) => r.status === 200,
    'Memory test: has body': (r) => r.body && r.body.length > 0,
  });
  
  if (success && res.body) {
    try {
      const body = JSON.parse(res.body);
      if (body.allocated_mb !== undefined) {
        memoryRequests.add(1);
        memoryDuration.add(res.timings.duration);
      }
    } catch (e) {
      console.log(`Memory test JSON parse error: ${e.message}`);
    }
  }
}

// ============= 生命周期钩子 =============

/**
 * 初始化阶段（测试开始前执行一次）
 */
export function setup() {
  console.log('🚀 Starting HPA Load Test (Light Version)...');
  console.log(`📍 Target: ${BASE_URL}`);
  
  // 健康检查
  const healthRes = http.get(`${BASE_URL}/health`, { timeout: '10s' });
  if (healthRes.status !== 200) {
    throw new Error('❌ Health check failed! Is the service running?');
  }
  
  console.log('✅ Health check passed');
  console.log('⏰ Test duration: ~9.5 minutes');
  console.log('💡 This is a LIGHT version with reduced load');
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
