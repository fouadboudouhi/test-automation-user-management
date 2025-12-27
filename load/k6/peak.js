import http from 'k6/http';
import { check, group, sleep } from 'k6';

export const options = {
  scenarios: {
    peak: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: String(__ENV.PEAK_RAMP_UP || '15s'), target: Number(__ENV.PEAK_VUS || 50) },
        { duration: String(__ENV.PEAK_HOLD || '60s'), target: Number(__ENV.PEAK_VUS || 50) },
        { duration: String(__ENV.PEAK_RAMP_DOWN || '30s'), target: 0 },
      ],
      gracefulRampDown: '30s',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.02'],
    http_req_duration: ['p(95)<1500', 'p(99)<3000'],
  },
};

const API_URL = (__ENV.API_URL || 'http://localhost:8091').replace(/\/+$/, '');
const EMAIL = __ENV.DEMO_EMAIL || 'customer@practicesoftwaretesting.com';
const PASSWORD = __ENV.DEMO_PASSWORD || 'welcome01';

function u(path) {
  return `${API_URL}${path}`;
}

let token = null;
let tokenExpMs = 0;

function login() {
  const payload = JSON.stringify({ email: EMAIL, password: PASSWORD });
  const res = http.post(u('/users/login'), payload, {
    headers: { 'Content-Type': 'application/json' },
    tags: { name: 'POST /users/login' },
  });
  const ok = check(res, { 'login 200': (r) => r.status === 200 });
  if (!ok) return;
  const body = res.json() || {};
  token = body.access_token || null;
  const expires = Number(body.expires_in || 120);
  tokenExpMs = Date.now() + expires * 1000;
}

function ensureToken() {
  if (!token || Date.now() > tokenExpMs - 5000) login();
}

function jitter(min = 0.1, max = 0.8) {
  sleep(min + Math.random() * (max - min));
}

export default function () {
  let productId = null;

  group('catalog', () => {
    const res = http.get(u('/products?page=1'), { tags: { name: 'GET /products' } });
    check(res, { 'products 200': (r) => r.status === 200 });
    if (res.status === 200) {
      const body = res.json() || {};
      const items = body.data || [];
      if (items.length > 0) {
        const idx = Math.floor(Math.random() * items.length);
        productId = items[idx] && items[idx].id ? String(items[idx].id) : null;
      }
    }
  });

  jitter();

  group('lists', () => {
    const b = http.get(u('/brands'), { tags: { name: 'GET /brands' } });
    check(b, { 'brands 200': (r) => r.status === 200 });

    const c = http.get(u('/categories'), { tags: { name: 'GET /categories' } });
    check(c, { 'categories 200': (r) => r.status === 200 });
  });

  if (productId) {
    jitter(0.05, 0.4);

    group('product-detail', () => {
      const res = http.get(u(`/products/${productId}`), { tags: { name: 'GET /products/:id' } });
      check(res, { 'product 200': (r) => r.status === 200 });
    });

    jitter(0.05, 0.4);

    group('product-related', () => {
      const res = http.get(u(`/products/${productId}/related`), { tags: { name: 'GET /products/:id/related' } });
      check(res, { 'related 200': (r) => r.status === 200 });
    });
  }

  jitter(0.05, 0.5);

  group('auth', () => {
    ensureToken();
    if (!token) return;

    const res = http.get(u('/users/me'), {
      headers: { Authorization: `Bearer ${token}` },
      tags: { name: 'GET /users/me' },
    });
    check(res, { 'me 200': (r) => r.status === 200 });
  });

  jitter(0.1, 0.9);
}