import apiClient from './client';

export async function listUsers() {
  const response = await apiClient.get('/api/users/');
  return response.data;
}

export async function getUser(uid) {
  const response = await apiClient.get(`/api/users/${encodeURIComponent(uid)}`);
  return response.data;
}
