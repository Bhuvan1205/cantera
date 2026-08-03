import apiClient from './client';

export async function listDeposits(params = {}) {
  const cleanParams = {};
  if (params.status && params.status !== 'all') {
    cleanParams.status = params.status;
  }
  if (params.limit) {
    cleanParams.limit = params.limit;
  }
  const response = await apiClient.get('/api/wallet/deposits', { params: cleanParams });
  return response.data;
}

export async function listRefunds(params = {}) {
  const cleanParams = {};
  if (params.status && params.status !== 'all') {
    cleanParams.status = params.status;
  }
  if (params.limit) {
    cleanParams.limit = params.limit;
  }
  const response = await apiClient.get('/api/wallet/refunds', { params: cleanParams });
  return response.data;
}

export async function getRefund(refundId) {
  const response = await apiClient.get(`/api/wallet/refunds/${encodeURIComponent(refundId)}`);
  return response.data;
}

export async function updateRefundStatus(refundId, data) {
  const response = await apiClient.patch(`/api/wallet/refunds/${encodeURIComponent(refundId)}`, data);
  return response.data;
}

export async function getWalletInvestigation(uid) {
  const response = await apiClient.get(`/api/wallet/${encodeURIComponent(uid)}`);
  return response.data;
}
