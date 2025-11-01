// ============================================
// k6 性能测试脚本 - 压力测试（Stress Test）
// 测试目标: 找到系统的性能极限和崩溃点
// ============================================

import http from 'k6/http';
import { sleep, check } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export const options = {
  // 压力测试的阶段设计
  stages: [
    { duration: '1m', target: 10 },   // 热身：1分钟升到 10 VU
    { duration: '2m', target: 50 },   // 加压：2分钟升到 50 VU
    { duration: '2m', target: 100 },  // 高压：2分钟升到 100 VU
    { duration: '2m', target: 200 },  // 极限：2分钟升到 200 VU 💥
    { duration: '2m', target: 300 },  // 崩溃点：2分钟升到 300 VU 🔥
    { duration: '2m', target: 0 },    // 冷却：2分钟降到 0
  ],
  
  // 压力测试的阈值（预期会失败）
  thresholds: {
    'http_req_duration': ['p(95)<1000', 'p(99)<2000'],
    'http_req_failed': ['rate<0.1'],  // 允许 10% 失败率（压力测试预期）
    'checks': ['rate>0.8'],            // 至少 80% 通过
  },
};

export default function () {
  const response = http.get(`${BASE_URL}/api/v1/hello?name=StressTest-${__VU}`);
  
  const passed = check(response, {
    '✅ 状态码是 200': (r) => r.status === 200,
    '✅ 响应时间 < 2s': (r) => r.timings.duration < 2000,
  });
  
  if (!passed) {
    console.log(`⚠️  VU-${__VU} 请求失败: ${response.status}, ${response.timings.duration}ms`);
  }
  
  // 压力测试下，不等待太久
  sleep(0.5);
}

// 自定义指标报告
export function handleSummary(data) {
  const maxVUs = Math.max(...data.metrics.vus.values.map(v => v.value));
  const totalRequests = data.metrics.http_reqs.values.count;
  const failedRequests = data.metrics.http_req_failed.values.passes || 0;
  const avgDuration = data.metrics.http_req_duration.values.avg;
  const p95Duration = data.metrics.http_req_duration.values['p(95)'];
  
  console.log('\n========================================');
  console.log('📊 压力测试总结报告');
  console.log('========================================');
  console.log(`🔥 最大并发用户数: ${maxVUs} VU`);
  console.log(`📈 总请求数: ${totalRequests}`);
  console.log(`❌ 失败请求数: ${failedRequests} (${((failedRequests/totalRequests)*100).toFixed(2)}%)`);
  console.log(`⏱️  平均响应时间: ${avgDuration.toFixed(2)}ms`);
  console.log(`⏱️  P95 响应时间: ${p95Duration.toFixed(2)}ms`);
  console.log('========================================\n');
  
  return {
    'stdout': '',
    'stress-test-report.json': JSON.stringify(data, null, 2),
  };
}

