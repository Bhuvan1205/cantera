import React, { useState, useEffect } from 'react';
import { getVendorDashboard, listTrials, getTrialAnalytics } from '../../api/foodpulse';
import { Alert, LoadingSpinner } from '../../components/common/Feedback';

export default function Analytics() {
  const [data, setData] = useState(null);
  const [trials, setTrials] = useState([]);
  const [selectedTrialId, setSelectedTrialId] = useState('');
  const [trialAnalytics, setTrialAnalytics] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchOverview = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const [dashRes, trialsRes] = await Promise.all([
        getVendorDashboard(),
        listTrials(),
      ]);
      setData(dashRes);
      setTrials(trialsRes);
      if (trialsRes.length > 0) {
        setSelectedTrialId(trialsRes[0].id);
        const analyticsData = await getTrialAnalytics(trialsRes[0].id).catch(() => null);
        setTrialAnalytics(analyticsData);
      }
    } catch (err) {
      setError(err.message || 'Failed to load analytics data');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchOverview();
  }, []);

  const handleTrialChange = async (trialId) => {
    setSelectedTrialId(trialId);
    if (!trialId) return;
    try {
      const res = await getTrialAnalytics(trialId);
      setTrialAnalytics(res);
    } catch (err) {
      setTrialAnalytics(null);
    }
  };

  if (isLoading) return <LoadingSpinner label="Loading FoodPulse Analytics..." />;

  return (
    <div className="p-lg md:p-xl space-y-xl max-w-7xl mx-auto">
      <div>
        <h1 className="text-display-sm font-bold text-on-surface">Demand & Performance Analytics</h1>
        <p className="text-body-md text-on-surface-variant">Deep dive into popularity rankings, voting velocity, and trial performance trends.</p>
      </div>

      {error && <Alert type="error" message={error} />}

      {/* Trial Performance Section */}
      <div className="bg-surface-container-lowest rounded-2xl border border-outline-variant/30 p-lg shadow-sm space-y-md">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-md">
          <h2 className="text-title-lg font-bold text-on-surface flex items-center gap-xs">
            <span className="material-symbols-outlined text-indigo-600">bar_chart</span>
            Trial Performance Deep-Dive
          </h2>

          <select
            value={selectedTrialId}
            onChange={(e) => handleTrialChange(e.target.value)}
            className="px-md py-xs rounded-xl border border-outline/30 bg-surface font-medium text-body-sm"
          >
            {trials.map((t) => (
              <option key={t.id} value={t.id}>{t.suggestion_name} ({t.status})</option>
            ))}
            {trials.length === 0 && <option value="">No trials available</option>}
          </select>
        </div>

        {trialAnalytics ? (
          <div className="space-y-lg">
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-md">
              <div className="p-md bg-surface rounded-xl border border-outline-variant/20">
                <div className="text-body-xs font-medium text-on-surface-variant">Total Volume</div>
                <div className="text-display-xs font-bold text-on-surface">{trialAnalytics.total_orders} orders</div>
              </div>
              <div className="p-md bg-surface rounded-xl border border-outline-variant/20">
                <div className="text-body-xs font-medium text-on-surface-variant">Total Revenue</div>
                <div className="text-display-xs font-bold text-on-surface">₹{trialAnalytics.total_revenue}</div>
              </div>
              <div className="p-md bg-surface rounded-xl border border-outline-variant/20">
                <div className="text-body-xs font-medium text-on-surface-variant">Avg Daily Orders</div>
                <div className="text-display-xs font-bold text-on-surface">{trialAnalytics.avg_daily_orders}</div>
              </div>
              <div className="p-md bg-surface rounded-xl border border-outline-variant/20">
                <div className="text-body-xs font-medium text-on-surface-variant">Target Achievement</div>
                <div className="text-display-xs font-bold text-primary">{trialAnalytics.performance_vs_prediction_pct}%</div>
              </div>
            </div>

            {/* Daily Breakdown Table */}
            <div className="overflow-x-auto">
              <h3 className="text-body-md font-bold text-on-surface mb-sm">Daily Performance History</h3>
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="border-b border-outline-variant/30 text-body-sm text-on-surface-variant">
                    <th className="py-xs px-sm">Date</th>
                    <th className="py-xs px-sm">Orders</th>
                    <th className="py-xs px-sm">Revenue</th>
                    <th className="py-xs px-sm">Rating</th>
                    <th className="py-xs px-sm">Repeats</th>
                    <th className="py-xs px-sm">Cancellations</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-outline-variant/10 text-body-sm">
                  {trialAnalytics.daily_breakdown.map((m) => (
                    <tr key={m.id}>
                      <td className="py-xs px-sm font-medium">{m.date}</td>
                      <td className="py-xs px-sm">{m.orders}</td>
                      <td className="py-xs px-sm">₹{m.revenue}</td>
                      <td className="py-xs px-sm">{m.avg_rating} ⭐</td>
                      <td className="py-xs px-sm">{m.repeat_purchases}</td>
                      <td className="py-xs px-sm">{m.cancellations} ({(m.cancellation_rate * 100).toFixed(1)}%)</td>
                    </tr>
                  ))}
                  {trialAnalytics.daily_breakdown.length === 0 && (
                    <tr><td colSpan="6" className="py-md text-center italic text-on-surface-variant">No daily metrics recorded yet for this trial.</td></tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        ) : (
          <p className="text-on-surface-variant italic text-body-sm">Select a trial to view performance breakdown.</p>
        )}
      </div>

      {/* Top Requested Ranking */}
      <div className="bg-surface-container-lowest rounded-2xl border border-outline-variant/30 p-lg shadow-sm space-y-md">
        <h2 className="text-title-lg font-bold text-on-surface flex items-center gap-xs">
          <span className="material-symbols-outlined text-amber-500">leaderboard</span>
          Global Popularity Score Rankings
        </h2>

        <div className="space-y-xs">
          {data?.top_requested?.map((item) => (
            <div key={item.suggestion_id} className="flex items-center justify-between p-sm bg-surface rounded-xl border border-outline-variant/20">
              <div className="flex items-center gap-md">
                <span className="w-8 h-8 rounded-full bg-primary/10 text-primary font-bold flex items-center justify-center text-body-sm">
                  #{item.rank}
                </span>
                <div>
                  <div className="font-bold text-body-md text-on-surface">{item.name}</div>
                  <div className="text-body-xs uppercase font-semibold text-on-surface-variant">{item.category}</div>
                </div>
              </div>

              <div className="flex items-center gap-lg">
                <div className="text-right">
                  <div className="font-bold text-body-md text-primary">{(item.popularity_score * 100).toFixed(1)} pts</div>
                  <div className="text-body-xs text-on-surface-variant">{item.vote_count} votes</div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
