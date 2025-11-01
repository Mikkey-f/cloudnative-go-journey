// ============================================
// k6 性能测试脚本 - 浸泡测试（Soak Test）
// 测试目标: 长时间运行，发现内存泄漏、资源耗尽等问题
// 场景: 模拟系统长时间运行（4小时、8小时、24小时）
// ============================================

import http from 'k6/http';
import { sleep, check } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export const options = {
  // 浸泡测试：长时间稳定负载
  stages: [
    { duration: '5m', target: 20 },   // 5分钟升到 20 VU
    { duration: '2h', target: 20 },   // 维持 20 VU 持续 2 小时 🕐
    { duration: '5m', target: 0 },    // 5分钟降到 0
  ],
  
  thresholds: {
    'http_req_duration': ['p(95)<500', 'p(99)<1000'],
    'http_req_failed': ['rate<0.01'],  // 长时间运行，要求稳定
    'checks': ['rate>0.99'],           // 99% 通过率
  },
};

export default function () {
  // 模拟真实用户的多种操作
  
  // 1. 健康检查
  const healthResponse = http.get(`${BASE_URL}/health`);
  check(healthResponse, {
    '✅ 健康检查正常': (r) => r.status === 200,
  });
  
  sleep(2);
  
  // 2. 查询接口
  const helloResponse = http.get(`${BASE_URL}/api/v1/hello?name=SoakTest-${__VU}`);
  check(helloResponse, {
    '✅ Hello 接口正常': (r) => r.status === 200,
  });
  
  sleep(3);
  
  // 3. 信息接口
  const infoResponse = http.get(`${BASE_URL}/api/v1/info`);
  check(infoResponse, {
    '✅ Info 接口正常': (r) => r.status === 200,
  });
  
  sleep(5);
  
  // 模拟真实用户的长间隔操作
  sleep(Math.random() * 10 + 10);  // 10-20 秒
}

export function handleSummary(data) {
  const duration = (Date.now() - data.state.testRunDurationMs) / 1000 / 60 / 60;
  
  console.log('\n========================================');
  console.log('🕐 浸泡测试总结报告');
  console.log('========================================');
  console.log(`⏱️  运行时长: ${duration.toFixed(2)} 小时`);
  console.log(`📊 总请求数: ${data.metrics.http_reqs.values.count}`);
  console.log(`📈 平均 QPS: ${(data.metrics.http_reqs.values.count / (duration * 3600)).toFixed(2)}`);
  console.log(`⏱️  P95 响应时间: ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms`);
  console.log(`❌ 失败率: ${((data.metrics.http_req_failed.values.rate || 0) * 100).toFixed(4)}%`);
  console.log('========================================');
  console.log('💡 建议同时监控:');
  console.log('   - 内存使用趋势（kubectl top pod）');
  console.log('   - CPU 使用趋势');
  console.log('   - 数据库连接数');
  console.log('   - Goroutine 数量');
  console.log('========================================\n');
  
  return {
    'stdout': '',
    'soak-test-report.json': JSON.stringify(data, null, 2),
  };
}

