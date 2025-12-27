import http from 'k6/http';
import { check, group, sleep } from 'k6';

export const options = {
  vus: Number(__ENV.VUS || 10),
  duration: String(__ENV.DURATION || '1m'),
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<800', 'p(99)<1500'],
  },
};

const API_URL = (__ENV.API_URL || 'http://localhost:8091').replace(/\/+$/, '');
const EMAIL = __ENV.DEMO_EMAIL || 'customer@practicesoftwaretesting.com';
const PASSWORD = __ENV.DEMO_PASSWORD || 'welcome01';
const AUTH = String(__ENV.AUTH || 'true').toLowerCase() === 'true';

function u(path) {
  return `${API_URL}${path}`;
}

export function setup() {
  if (!AUTH) return { token: null };

  const payload = JSON.stringify({ email: EMAIL, password: PASSWORD });
  const params = { headers: { 'Content-Type': 'application/json' }, tags: { name: 'POST /users/login' } };
  const res = http.post(u('/users/login'), payload, params);
  const ok = check(res, { 'login 200': (r) => r.status === 200 });
  if (!ok) return { token: null };
  const body = res.json();
  return { token: body && body.access_token ? body.access_token : null };
}

export default function (data) {
  let productId = null;

  group('catalog', () => {
    const res = http.get(u('/products?page=1'), { tags: { name: 'GET /products' } });
    check(res, { 'products 200': (r) => r.status === 200 });
    if (res.status === 200) {
      const body = res.json();
      const items = body && body.data ? body.data : [];
      if (items.length > 0) {
        const idx = (__VU - 1) % items.length;
        const pick = items[idx];
        if (pick && pick.id) productId = String(pick.id);
      }
    }
  });

  group('lists', () => {
    const b = http.get(u('/brands'), { tags: { name: 'GET /brands' } });
    check(b, { 'brands 200': (r) => r.status === 200 });

    const c = http.get(u('/categories'), { tags: { name: 'GET /categories' } });
    check(c, { 'categories 200': (r) => r.status === 200 });
  });

  if (productId) {
    group('product-detail', () => {
      const res = http.get(u(`/products/${productId}`), { tags: { name: 'GET /products/:id' } });
      check(res, { 'product 200': (r) => r.status === 200 });
    });

    group('product-related', () => {
      const res = http.get(u(`/products/${productId}/related`), { tags: { name: 'GET /products/:id/related' } });
      check(res, { 'related 200': (r) => r.status === 200 });
    });
  }

  if (AUTH && data && data.token) {
    group('auth', () => {
      const res = http.get(u('/users/me'), {
        headers: { Authorization: `Bearer ${data.token}` },
        tags: { name: 'GET /users/me' },
      });
      check(res, { 'me 200': (r) => r.status === 200 });
    });
  }

  sleep(1);
}