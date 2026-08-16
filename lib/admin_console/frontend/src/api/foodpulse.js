import apiClient from './client';

export async function getVendorDashboard() {
  const response = await apiClient.get('/foodpulse/vendor/dashboard');
  return response.data;
}

export async function approveSuggestion(suggestionId, notes = '') {
  const response = await apiClient.post(`/foodpulse/suggestions/${suggestionId}/approve`, { notes });
  return response.data;
}

export async function rejectSuggestion(suggestionId, reason = '') {
  const response = await apiClient.post(`/foodpulse/suggestions/${suggestionId}/reject`, { reason });
  return response.data;
}

export async function listTrials() {
  const response = await apiClient.get('/foodpulse/trial');
  return response.data;
}

export async function startTrial(suggestionId, trialDurationDays = 7, predictedDailyOrders = 10, notes = '') {
  const response = await apiClient.post('/foodpulse/trial/start', {
    suggestion_id: suggestionId,
    trial_duration_days: trialDurationDays,
    predicted_daily_orders: predictedDailyOrders,
    notes,
  });
  return response.data;
}

export async function endTrial(trialId, notes = '') {
  const response = await apiClient.post(`/foodpulse/trial/end/${trialId}`, { notes });
  return response.data;
}

export async function recordTrialMetrics(trialId, metricData) {
  const response = await apiClient.post(`/foodpulse/trial/${trialId}/metrics`, metricData);
  return response.data;
}

export async function getTrialAnalytics(trialId) {
  const response = await apiClient.get(`/foodpulse/analytics/${trialId}`);
  return response.data;
}

export async function getRecommendation(trialId) {
  const response = await apiClient.get(`/foodpulse/recommendation/${trialId}`);
  return response.data;
}

export async function createPoll(question, section, options) {
  const response = await apiClient.post('/foodpulse/polls', { question, section, options });
  return response.data;
}

export async function closePoll(pollId) {
  const response = await apiClient.post(`/foodpulse/polls/${pollId}/close`);
  return response.data;
}

export async function getActivePoll() {
  const response = await apiClient.get('/foodpulse/polls/active');
  return response.data;
}

