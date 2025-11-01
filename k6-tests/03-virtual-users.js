// ============================================
// k6 性能测试脚本 - 模拟多虚拟用户（VUs）
// 测试目标: 模拟 10 个并发用户访问 API
// ============================================

import http from 'k6/http';
import { sleep, check } from 'k6';

export const options = {
  // 虚拟用户（Virtual Users）
  vus: 10,  // 10 个并发用户
  
  // 持续时间
  duration: '30s',  // 持续 30 秒
  
  // 可选：设置阈值（SLA）
  thresholds: {
    // 95% 的请求必须在 500ms 内完成
    'http_req_duration': ['p(95)<500'],
    // 99% 的请求必须成功
    'http_req_failed': ['rate<0.01'],
    // 检查通过率必须 > 95%
    'checks': ['rate>0.95'],
  },
};

export default function () {
  // 每个 VU 都会并发执行这个函数 30 秒
  
  const response = http.get('http://localhost:8080/api/v1/hello?name=User-' + __VU);
  
  check(response, {
    '✅ 状态码是 200': (r) => r.status === 200,
    '✅ 响应时间 < 500ms': (r) => r.timings.duration < 500,
    '✅ 响应包含 message': (r) => r.json('message') !== undefined,
  });
  
  // 模拟用户思考时间（1-3秒随机）
  sleep(Math.random() * 2 + 1);
}


