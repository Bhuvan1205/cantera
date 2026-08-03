import apiClient from './client';

export async function listOrders(params = {}) {
  const cleanParams = {};
  if (params.status && params.status !== 'all') {
    cleanParams.status = params.status;
  }
  if (params.limit) {
    cleanParams.limit = params.limit;
  }
  const response = await apiClient.get('/api/orders/', { params: cleanParams });
  return response.data;
}

export async function getOrder(orderId) {
  const response = await apiClient.get(`/api/orders/${encodeURIComponent(orderId)}`);
  return response.data;
}

export async function getOrderTokens(orderId) {
  const response = await apiClient.get(`/api/orders/${encodeURIComponent(orderId)}/tokens`);
  return response.data;
}

export async function createManualOrder(data) {
  const response = await apiClient.post('/api/orders/', data);
  return response.data;
}

export async function updateOrderStatus(orderId, status) {
  const response = await apiClient.patch(`/api/orders/${encodeURIComponent(orderId)}`, { status });
  return response.data;
}
