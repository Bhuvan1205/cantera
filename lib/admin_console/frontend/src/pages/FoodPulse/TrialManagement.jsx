import React, { useState, useEffect } from 'react';
import { listTrials, endTrial, recordTrialMetrics, getTrialAnalytics, getRecommendation } from '../../api/foodpulse';
import { Alert, LoadingSpinner } from '../../components/common/Feedback';

export default function TrialManagement() {
  const [trials, setTrials] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  // Selected trial detail modal
  const [selectedTrial, setSelectedTrial] = useState(null);
  const [analytics, setAnalytics] = useState(null);
  const [recommendation, setRecommendation] = useState(null);
  const [detailLoading, setDetailLoading] = useState(false);

  // Record daily metric form state
  const [metricDate, setMetricDate] = useState(new Date().toISOString().split('T')[0]);
  const [orders, setOrders] = useState(12);
  const [revenue, setRevenue] = useState(600);
  const [rating, setRating] = useState(4.2);
  const [repeatPurchases, setRepeatPurchases] = useState(4);
  const [cancellations, setCancellations] = useState(0);

  const fetchTrials = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const res = await listTrials();
      setTrials(res);
    } catch (err) {
      setError(err.message || 'Failed to fetch trial items');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchTrials();
  }, []);

  const openTrialDetails = async (trial) => {
    setSelectedTrial(trial);
    setDetailLoading(true);
    try {
      const [analyticsData, recData] = await Promise.all([
        getTrialAnalytics(trial.id).catch(() => null),
        getRecommendation(trial.id).catch(() => null),
      ]);
      setAnalytics(analyticsData);
      setRecommendation(recData);
    } catch (err) {
      console.error(err);
    } finally {
      setDetailLoading(false);
    }
  };

  const handleRecordMetric = async (e) => {
    e.preventDefault();
    if (!selectedTrial) return;
    try {
      await recordTrialMetrics(selectedTrial.id, {
        date: metricDate,
        orders: Number(orders),
        revenue: Number(revenue),
        avg_rating: Number(rating),
        repeat_purchases: Number(repeatPurchases),
        cancellations: Number(cancellations),
      });
      alert('Daily metrics recorded successfully!');
      openTrialDetails(selectedTrial);
    } catch (err) {
      alert('Error recording metric: ' + (err.response?.data?.detail || err.message));
    }
  };

  const handleEndTrial = async (trialId) => {
    if (!window.confirm('Are you sure you want to conclude this trial?')) return;
    try {
      await endTrial(trialId, 'Trial completed by admin');
      fetchTrials();
      if (selectedTrial?.id === trialId) {
        setSelectedTrial(null);
      }
    } catch (err) {
      alert('Error ending trial: ' + (err.response?.data?.detail || err.message));
    }
  };

  if (isLoading) return <LoadingSpinner label="Loading Trial Management..." />;

  return (
    <div className="p-lg md:p-xl space-y-xl max-w-7xl mx-auto">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-display-sm font-bold text-on-surface">Trial Management</h1>
          <p className="text-body-md text-on-surface-variant">Monitor active trial food items, record daily sales performance, and view AI recommendations.</p>
        </div>
        <button
          onClick={fetchTrials}
          className="px-md py-sm bg-surface-container-high hover:bg-surface-container-highest rounded-xl text-body-sm font-medium transition-all flex items-center gap-xs"
        >
          <span className="material-symbols-outlined text-[18px]">refresh</span>
          Refresh
        </button>
      </div>

      {error && <Alert type="error" message={error} />}

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-lg">
        {trials.map((trial) => (
          <div key={trial.id} className="bg-surface-container-lowest p-lg rounded-2xl border border-outline-variant/30 shadow-sm space-y-md">
            <div className="flex justify-between items-start">
              <div>
                <h3 className="font-bold text-title-md text-on-surface">{trial.suggestion_name}</h3>
                <span className="text-body-xs uppercase font-semibold text-on-surface-variant">{trial.category}</span>
              </div>
              <span className={`px-xs py-[2px] rounded text-[11px] font-bold uppercase ${
                trial.status === 'active' ? 'bg-amber-500/10 text-amber-600' : 'bg-blue-500/10 text-blue-600'
              }`}>
                {trial.status}
              </span>
            </div>

            <div className="space-y-xs text-body-sm text-on-surface-variant border-t border-b border-outline-variant/20 py-sm">
              <div className="flex justify-between">
                <span>Trial Duration:</span>
                <span className="font-medium text-on-surface">{trial.trial_duration_days} Days</span>
              </div>
              <div className="flex justify-between">
                <span>Predicted Target:</span>
                <span className="font-medium text-on-surface">{trial.predicted_daily_orders} orders/day</span>
              </div>
            </div>

            <div className="flex gap-xs">
              <button
                onClick={() => openTrialDetails(trial)}
                className="flex-1 py-xs bg-primary text-on-primary rounded-xl text-body-sm font-medium hover:bg-primary/90 transition-all"
              >
                Analytics & AI Rec
              </button>
              {trial.status === 'active' && (
                <button
                  onClick={() => handleEndTrial(trial.id)}
                  className="px-md py-xs bg-error/10 hover:bg-error/20 text-error rounded-xl text-body-sm font-medium transition-all"
                >
                  End Trial
                </button>
              )}
            </div>
          </div>
        ))}
        {trials.length === 0 && (
          <div className="col-span-full p-xl text-center bg-surface-container-lowest rounded-2xl border border-outline-variant/20 text-on-surface-variant italic">
            No trial items created yet. You can launch trials from approved suggestions in the FoodPulse Dashboard.
          </div>
        )}
      </div>

      {/* Trial Detail & Analytics Modal */}
      {selectedTrial && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-md overflow-y-auto">
          <div className="bg-surface-container-lowest max-w-2xl w-full rounded-2xl p-xl shadow-2xl space-y-lg max-h-[90vh] overflow-y-auto">
            <div className="flex justify-between items-start">
              <div>
                <h2 className="text-title-lg font-bold">{selectedTrial.suggestion_name}</h2>
                <p className="text-body-sm text-on-surface-variant">Trial ID: {selectedTrial.id}</p>
              </div>
              <button onClick={() => setSelectedTrial(null)} className="p-xs hover:bg-surface-variant/20 rounded-full">
                <span className="material-symbols-outlined">close</span>
              </button>
            </div>

            {detailLoading ? (
              <LoadingSpinner label="Computing analytics & recommendation..." />
            ) : (
              <div className="space-y-lg">
                {/* AI Recommendation Banner */}
                {recommendation && (
                  <div className="p-md rounded-xl bg-purple-500/10 border border-purple-500/30 space-y-xs">
                    <div className="flex items-center gap-xs text-purple-700 font-bold">
                      <span className="material-symbols-outlined">auto_awesome</span>
                      <span>AI Recommendation: {recommendation.action.toUpperCase()}</span>
                      <span className="ml-auto text-body-xs bg-purple-200 text-purple-800 px-xs py-[2px] rounded">
                        Confidence: {(recommendation.confidence * 100).toFixed(0)}%
                      </span>
                    </div>
                    <p className="text-body-sm text-purple-900">{recommendation.reasoning}</p>
                  </div>
                )}

                {/* Analytics Summary */}
                {analytics && (
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-md">
                    <div className="p-sm bg-surface rounded-xl border border-outline-variant/20 text-center">
                      <div className="text-body-xs text-on-surface-variant font-medium">Total Orders</div>
                      <div className="text-title-lg font-bold">{analytics.total_orders}</div>
                    </div>
                    <div className="p-sm bg-surface rounded-xl border border-outline-variant/20 text-center">
                      <div className="text-body-xs text-on-surface-variant font-medium">Revenue</div>
                      <div className="text-title-lg font-bold">₹{analytics.total_revenue}</div>
                    </div>
                    <div className="p-sm bg-surface rounded-xl border border-outline-variant/20 text-center">
                      <div className="text-body-xs text-on-surface-variant font-medium">Avg Rating</div>
                      <div className="text-title-lg font-bold">{analytics.avg_rating} ⭐</div>
                    </div>
                    <div className="p-sm bg-surface rounded-xl border border-outline-variant/20 text-center">
                      <div className="text-body-xs text-on-surface-variant font-medium">% Target Achieved</div>
                      <div className="text-title-lg font-bold text-primary">{analytics.performance_vs_prediction_pct}%</div>
                    </div>
                  </div>
                )}

                {/* Record Daily Metric Form */}
                <div className="border-t border-outline-variant/20 pt-md space-y-md">
                  <h4 className="font-bold text-body-md text-on-surface flex items-center gap-xs">
                    <span className="material-symbols-outlined text-primary text-[20px]">add_chart</span>
                    Record Daily Performance Metric
                  </h4>

                  <form onSubmit={handleRecordMetric} className="grid grid-cols-2 sm:grid-cols-3 gap-md">
                    <div>
                      <label className="block text-body-xs font-medium text-on-surface-variant">Date</label>
                      <input
                        type="date"
                        value={metricDate}
                        onChange={(e) => setMetricDate(e.target.value)}
                        className="w-full px-sm py-xs rounded-lg border border-outline/30 text-body-sm"
                        required
                      />
                    </div>
                    <div>
                      <label className="block text-body-xs font-medium text-on-surface-variant">Daily Orders</label>
                      <input
                        type="number"
                        min="0"
                        value={orders}
                        onChange={(e) => setOrders(e.target.value)}
                        className="w-full px-sm py-xs rounded-lg border border-outline/30 text-body-sm"
                        required
                      />
                    </div>
                    <div>
                      <label className="block text-body-xs font-medium text-on-surface-variant">Revenue (₹)</label>
                      <input
                        type="number"
                        min="0"
                        value={revenue}
                        onChange={(e) => setRevenue(e.target.value)}
                        className="w-full px-sm py-xs rounded-lg border border-outline/30 text-body-sm"
                        required
                      />
                    </div>
                    <div>
                      <label className="block text-body-xs font-medium text-on-surface-variant">Avg Rating (1-5)</label>
                      <input
                        type="number"
                        step="0.1"
                        min="1"
                        max="5"
                        value={rating}
                        onChange={(e) => setRating(e.target.value)}
                        className="w-full px-sm py-xs rounded-lg border border-outline/30 text-body-sm"
                        required
                      />
                    </div>
                    <div>
                      <label className="block text-body-xs font-medium text-on-surface-variant">Repeat Purchases</label>
                      <input
                        type="number"
                        min="0"
                        value={repeatPurchases}
                        onChange={(e) => setRepeatPurchases(e.target.value)}
                        className="w-full px-sm py-xs rounded-lg border border-outline/30 text-body-sm"
                      />
                    </div>
                    <div>
                      <label className="block text-body-xs font-medium text-on-surface-variant">Cancellations</label>
                      <input
                        type="number"
                        min="0"
                        value={cancellations}
                        onChange={(e) => setCancellations(e.target.value)}
                        className="w-full px-sm py-xs rounded-lg border border-outline/30 text-body-sm"
                      />
                    </div>

                    <button
                      type="submit"
                      className="col-span-full py-xs bg-primary text-on-primary font-medium rounded-xl text-body-sm shadow"
                    >
                      Save Daily Metric
                    </button>
                  </form>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
