// ============================================
// k6 性能测试脚本 - 峰值测试（Spike Test）
// 测试目标: 模拟突发流量，测试系统的弹性恢复能力
// 场景: 模拟秒杀、热点事件等突发流量
// ============================================

import http from 'k6/http';
import { sleep, check } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export const options = {
  // 峰值测试：短时间内流量暴涨
  stages: [
    { duration: '30s', target: 10 },    // 正常流量
    { duration: '10s', target: 200 },   // 💥 10秒内暴涨到 200 VU（秒杀场景）
    { duration: '1m', target: 200 },    // 维持高峰 1 分钟
    { duration: '10s', target: 10 },    // 快速恢复到正常
    { duration: '1m', target: 10 },     // 验证系统是否恢复正常
    { duration: '10s', target: 0 },     // 结束
  ],
  
  thresholds: {
    // 峰值期间允许性能下降，但不能崩溃
    'http_req_duration': ['p(99)<3000'],  // 99% 请求在 3 秒内
    'http_req_failed': ['rate<0.05'],     // 失败率低于 5%
    'checks': ['rate>0.9'],               // 90% 通过率
  },
};

export default function () {
  const response = http.get(`${BASE_URL}/api/v1/hello?name=Spike-${__VU}`);
  
  check(response, {
    '✅ 状态码是 200 或 503': (r) => r.status === 200 || r.status === 503,
    '✅ 响应时间 < 3s': (r) => r.timings.duration < 3000,
  });
  
  // 峰值测试不等待
  sleep(0.1);
}

export function handleSummary(data) {
  console.log('\n========================================');
  console.log('⚡ 峰值测试总结报告');
  console.log('========================================');
  console.log('✅ 系统在突发流量下的表现:');
  console.log(`   - 峰值并发: 200 VU`);
  console.log(`   - P99 响应时间: ${data.metrics.http_req_duration.values['p(99)'].toFixed(2)}ms`);
  console.log(`   - 失败率: ${((data.metrics.http_req_failed.values.rate || 0) * 100).toFixed(2)}%`);
  console.log('========================================\n');
  
  return {
    'stdout': '',
    'spike-test-report.json': JSON.stringify(data, null, 2),
  };
}

