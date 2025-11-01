// ============================================
// k6 性能测试脚本 - POST 请求测试
// 测试目标: 测试数据写入性能
// ============================================

import http from 'k6/http';
import { sleep, check } from 'k6';
import { randomString } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export const options = {
  vus: 5,
  duration: '30s',
  
  thresholds: {
    'http_req_duration{method:POST}': ['p(95)<800'],  // POST 请求慢一些
    'http_req_duration{method:GET}': ['p(95)<500'],   // GET 请求快一些
    'http_req_failed': ['rate<0.05'],
  },
};

export default function () {
  // 生成随机数据
  const key = `test-${__VU}-${randomString(8)}`;
  const payload = JSON.stringify({
    key: key,
    value: `Test data from VU-${__VU} at ${Date.now()}`,
    metadata: {
      vu: __VU,
      iteration: __ITER,
      timestamp: new Date().toISOString(),
    },
  });
  
  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
    tags: { method: 'POST' },  // 用于指标分组
  };
  
  // 1️⃣ POST: 创建数据
  const createResponse = http.post(`${BASE_URL}/api/v1/data`, payload, params);
  
  const createCheck = check(createResponse, {
    '✅ POST 创建成功': (r) => r.status === 200 || r.status === 201,
    '✅ POST 响应时间 < 800ms': (r) => r.timings.duration < 800,
  });
  
  if (!createCheck) {
    console.log(`❌ 创建失败: ${createResponse.status} ${createResponse.body}`);
  }
  
  sleep(1);
  
  // 2️⃣ GET: 读取刚创建的数据
  const getParams = {
    tags: { method: 'GET' },
  };
  
  const getResponse = http.get(`${BASE_URL}/api/v1/data/${key}`, getParams);
  
  check(getResponse, {
    '✅ GET 读取成功': (r) => r.status === 200,
    '✅ GET 数据匹配': (r) => {
      try {
        const data = r.json();
        return data.key === key;
      } catch (e) {
        return false;
      }
    },
  });
  
  sleep(1);
  
  // 3️⃣ DELETE: 删除数据（清理）
  if (Math.random() > 0.5) {
    const deleteResponse = http.del(`${BASE_URL}/api/v1/data/${key}`);
    check(deleteResponse, {
      '✅ DELETE 删除成功': (r) => r.status === 200 || r.status === 204,
    });
  }
  
  sleep(2);
}


