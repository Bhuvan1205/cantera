import apiClient from './client';

export async function login(email, password) {
  const response = await apiClient.post('/api/auth/login', { email, password });
  return response.data;
}

export async function ping() {
  const response = await apiClient.get('/api/ping');
  return response.data;
}

export async function getHealth() {
  const response = await apiClient.get('/health');
  return response.data;
}
