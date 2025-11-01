// ============================================
// k6 性能测试脚本 - 真实场景模拟
// 测试目标: 模拟真实用户混合操作
// ============================================

import http from 'k6/http';
import { sleep, check, group } from 'k6';

// 配置
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export const options = {
  // 阶段式负载测试（Staged Load Test）
  stages: [
    { duration: '30s', target: 5 },   // 30秒内逐渐增加到 5 个 VU
    { duration: '1m', target: 10 },   // 1分钟内增加到 10 个 VU
    { duration: '30s', target: 20 },  // 30秒内增加到 20 个 VU（压力测试）
    { duration: '30s', target: 0 },   // 30秒内降到 0（冷却）
  ],
  
  // 性能阈值（SLA）
  thresholds: {
    'http_req_duration': ['p(95)<500', 'p(99)<1000'],  // 95%<500ms, 99%<1s
    'http_req_failed': ['rate<0.01'],                  // 失败率<1%
    'checks': ['rate>0.95'],                            // 检查通过率>95%
    
    // 分组阈值
    'group_duration{group:::健康检查}': ['p(95)<200'],
    'group_duration{group:::业务接口}': ['p(95)<500'],
  },
};

export default function () {
  // 场景 1: 健康检查（10% 的流量）
  group('健康检查', function () {
    const healthResponse = http.get(`${BASE_URL}/health`);
    check(healthResponse, {
      '✅ 健康检查成功': (r) => r.status === 200,
      '✅ 健康检查响应快': (r) => r.timings.duration < 200,
    });
  });
  
  sleep(0.5);
  
  // 场景 2: 查询应用信息（20% 的流量）
  group('业务接口', function () {
    const infoResponse = http.get(`${BASE_URL}/api/v1/info`);
    check(infoResponse, {
      '✅ Info 接口成功': (r) => r.status === 200,
      '✅ Info 返回版本号': (r) => r.json('version') !== undefined,
      '✅ Info 返回应用名': (r) => r.json('app') === 'cloudnative-go-journey',
    });
    
    sleep(1);
    
    // 场景 3: 问候接口（50% 的流量）
    const helloResponse = http.get(`${BASE_URL}/api/v1/hello?name=User-${__VU}`);
    check(helloResponse, {
      '✅ Hello 接口成功': (r) => r.status === 200,
      '✅ Hello 返回 message': (r) => r.json('message') !== undefined,
      '✅ Hello 包含用户名': (r) => r.json('message').includes(`User-${__VU}`),
    });
    
    sleep(1);
    
    // 场景 4: 缓存测试（20% 的流量）
    if (Math.random() > 0.8) {
      const cacheResponse = http.get(`${BASE_URL}/api/v1/cache/test`);
      check(cacheResponse, {
        '✅ 缓存接口响应': (r) => r.status === 200 || r.status === 503,
      });
    }
  });
  
  // 模拟用户思考时间
  sleep(Math.random() * 3 + 1);
}

// 📊 测试完成后的汇总报告
export function handleSummary(data) {
  return {
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
    'summary.json': JSON.stringify(data),
  };
}

function textSummary(data, options) {
  // 简化版，实际可以用 k6 内置的 textSummary
  return '';
}


