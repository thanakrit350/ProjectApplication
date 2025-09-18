// API base. ถ้า backend กับเว็บอยู่โดเมนเดียว ให้เว้นว่าง
export const BASE_URL = '';
export const API_PREFIX = ''; // ถ้ามี prefix เช่น '/api' ค่อยใส่

async function request(path, options = {}) {
  const res = await fetch(`${BASE_URL}${API_PREFIX}${path}`, {
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
    ...options
  });
  if (!res.ok) {
    const t = await res.text().catch(() => '');
    throw new Error(`${res.status} ${res.statusText}${t ? ' | ' + t : ''}`);
  }
  if (res.status === 204) return null;
  const ct = res.headers.get('content-type') || '';
  return ct.includes('application/json') ? res.json() : res.text();
}

// ---------- Restaurant Types ----------
export const RestaurantTypeApi = {
  list: () => request('/restaurant-types'),
  create: (payload) => request('/restaurant-types', { method: 'POST', body: JSON.stringify(payload) }),
  update: (id, payload) => request(`/restaurant-types/${id}`, { method: 'PUT', body: JSON.stringify(payload) }),
  remove: (id) => request(`/restaurant-types/${id}`, { method: 'DELETE' }),
  search: (q) => request(`/restaurant-types/search?q=${encodeURIComponent(q)}`),
};

// ---------- Restaurants (อ่าน/ลบที่หน้า List ใช้ชุดนี้พอ) ----------
export const RestaurantApi = {
  list: () => request('/restaurants'),
  get:  (id) => request(`/restaurants/${id}`),
  remove: (id) => request(`/restaurants/${id}`, { method: 'DELETE' }),
};
