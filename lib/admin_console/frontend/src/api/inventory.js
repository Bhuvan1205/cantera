import apiClient from './client';

export async function listInventory() {
  const response = await apiClient.get('/api/inventory/');
  return response.data;
}

export async function getMenuItem(menuId) {
  const response = await apiClient.get(`/api/inventory/${encodeURIComponent(menuId)}`);
  return response.data;
}

export async function createMenuItem(data) {
  const response = await apiClient.post('/api/inventory/', data);
  return response.data;
}

export async function updateMenuItem(menuId, data) {
  const response = await apiClient.patch(`/api/inventory/${encodeURIComponent(menuId)}`, data);
  return response.data;
}
