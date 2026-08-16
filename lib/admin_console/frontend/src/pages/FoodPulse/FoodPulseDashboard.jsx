import React, { useState, useEffect } from 'react';
import { getVendorDashboard } from '../../api/foodpulse';
import { Alert, LoadingSpinner } from '../../components/common/Feedback';

const formatSection = (category) => {
  if (!category) return 'General';
  const lower = category.toLowerCase();
  if (lower === 'bakery') return 'Bakery';
  if (lower === 'mess') return 'Mess';
  if (lower === 'continental') return 'Continental';
  if (lower === 'beverages') return 'Beverages';
  return category.charAt(0).toUpperCase() + category.slice(1);
};

export default function FoodPulseDashboard() {
  const [data, setData] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchDashboard = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const res = await getVendorDashboard();
      setData(res);
    } catch (err) {
      setError(err.message || 'Failed to load FoodPulse dashboard');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchDashboard();
  }, []);

  if (isLoading) return <LoadingSpinner label="Loading FoodPulse Demand & Feedback..." />;

  // Combine suggestions without approval/rejection distinction
  const pendingList = data?.pending_suggestions || [];
  const approvedList = data?.approved_suggestions || [];
  const allSuggestions = [...pendingList, ...approvedList];
  const activePoll = data?.active_poll;

  // Calculate winning / most voted option for active poll
  let winningOption = null;
  if (activePoll && activePoll.options && activePoll.options.length > 0) {
    winningOption = activePoll.options.reduce((max, opt) => (opt.vote_count > (max?.vote_count || 0) ? opt : max), null);
  }

  return (
    <div className="p-lg md:p-xl space-y-xl max-w-7xl mx-auto">
      {/* Header Banner */}
      <div className="bg-gradient-to-r from-purple-700 via-indigo-700 to-blue-700 text-white rounded-2xl p-xl shadow-lg flex flex-col md:flex-row items-start md:items-center justify-between gap-lg relative overflow-hidden">
        <div className="z-10 space-y-xs">
          <div className="flex items-center gap-xs font-label-caps text-[11px] uppercase tracking-wider text-purple-200">
            <span className="material-symbols-outlined text-[18px]">poll</span>
            <span>Student Demand & Community Feedback</span>
          </div>
          <h1 className="font-display-lg text-3xl font-bold">FoodPulse Dashboard</h1>
          <p className="font-body-md text-purple-100 max-w-xl">
            Understand what food items students are suggesting and monitor real-time community poll results.
          </p>
        </div>

        <button
          onClick={fetchDashboard}
          className="z-10 px-md py-sm bg-white/10 hover:bg-white/20 backdrop-blur-md rounded-xl font-body-sm font-medium transition-all flex items-center gap-xs border border-white/20"
        >
          <span className="material-symbols-outlined text-[18px]">refresh</span>
          <span>Refresh Data</span>
        </button>
      </div>

      {error && <Alert type="error" message={error} />}

      {/* Summary KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-lg">
        <div className="bg-surface-container-lowest p-lg rounded-2xl border border-outline-variant/30 shadow-sm flex items-center gap-md">
          <div className="p-md rounded-xl bg-purple-500/10 text-purple-600">
            <span className="material-symbols-outlined text-[28px]">lightbulb</span>
          </div>
          <div>
            <div className="text-body-sm text-on-surface-variant font-medium">Total Student Food Suggestions</div>
            <div className="text-display-sm font-bold text-on-surface">{data?.total_suggestions || allSuggestions.length}</div>
          </div>
        </div>

        <div className="bg-surface-container-lowest p-lg rounded-2xl border border-outline-variant/30 shadow-sm flex items-center gap-md">
          <div className="p-md rounded-xl bg-amber-500/10 text-amber-600">
            <span className="material-symbols-outlined text-[28px]">bar_chart</span>
          </div>
          <div>
            <div className="text-body-sm text-on-surface-variant font-medium">Active Poll Participants</div>
            <div className="text-display-sm font-bold text-on-surface">{activePoll?.total_votes || 0}</div>
          </div>
        </div>
      </div>

      {/* SECTION A: STUDENT FOOD SUGGESTIONS */}
      <div className="space-y-lg">
        <div className="border-b border-outline-variant/20 pb-xs">
          <h2 className="text-title-xl font-bold text-on-surface flex items-center gap-xs">
            <span className="material-symbols-outlined text-purple-600">forum</span>
            A. Student Food Suggestions
          </h2>
          <p className="text-body-sm text-on-surface-variant">Food items suggested by students and their respective canteen sections.</p>
        </div>

        {/* Student Suggestions Table */}
        <div className="bg-surface-container-lowest rounded-2xl border border-outline-variant/30 p-lg shadow-sm space-y-md">
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-outline-variant/30 text-body-sm text-on-surface-variant">
                  <th className="py-sm px-md font-bold">Item Name</th>
                  <th className="py-sm px-md font-bold">Section</th>
                  <th className="py-sm px-md font-bold">Number of Requests</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-outline-variant/10 text-body-md">
                {allSuggestions.map((item) => (
                  <tr key={item.id} className="hover:bg-surface-container-low/40">
                    <td className="py-sm px-md font-medium text-on-surface">{item.name}</td>
                    <td className="py-sm px-md font-semibold text-on-surface-variant">{formatSection(item.category)}</td>
                    <td className="py-sm px-md font-semibold text-purple-600">
                      {item.request_count || 1} requests
                    </td>
                  </tr>
                ))}
                {allSuggestions.length === 0 && (
                  <tr>
                    <td colSpan="3" className="py-md text-center text-on-surface-variant italic">
                      No student food suggestions submitted yet.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {/* SECTION B: COMMUNITY POLLS */}
      <div className="space-y-lg pt-md">
        <div className="border-b border-outline-variant/20 pb-xs">
          <h2 className="text-title-xl font-bold text-on-surface flex items-center gap-xs">
            <span className="material-symbols-outlined text-indigo-600">poll</span>
            B. Community Polls
          </h2>
          <p className="text-body-sm text-on-surface-variant">Real-time student poll votes and preferences.</p>
        </div>

        <div className="bg-surface-container-lowest rounded-2xl border border-outline-variant/30 p-lg shadow-sm">
          {activePoll ? (
            <div className="space-y-md">
              <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-sm border-b border-outline-variant/20 pb-md">
                <div>
                  <div className="flex items-center gap-xs">
                    <span className="px-xs py-[2px] bg-purple-500/10 text-purple-600 rounded text-[11px] font-bold uppercase">
                      Section: {formatSection(activePoll.section)}
                    </span>
                    <span className="text-body-xs text-on-surface-variant font-medium">
                      Total Participants: <strong className="text-on-surface">{activePoll.total_votes}</strong>
                    </span>
                  </div>
                  <h3 className="text-title-lg font-bold text-on-surface mt-xs">{activePoll.question}</h3>
                </div>

                {winningOption && winningOption.vote_count > 0 && (
                  <div className="bg-emerald-500/10 border border-emerald-500/30 text-emerald-700 px-md py-xs rounded-xl flex items-center gap-xs text-body-sm font-semibold">
                    <span className="material-symbols-outlined text-[18px]">emoji_events</span>
                    <span>Most Voted: {winningOption.text} ({winningOption.vote_count} votes)</span>
                  </div>
                )}
              </div>

              {/* Poll Options breakdown */}
              <div className="space-y-xs pt-xs">
                {activePoll.options.map((opt) => {
                  const pct = activePoll.total_votes > 0 ? Math.round((opt.vote_count / activePoll.total_votes) * 100) : 0;
                  return (
                    <div key={opt.id} className="p-md bg-surface rounded-xl border border-outline-variant/20 space-y-xs">
                      <div className="flex justify-between items-center text-body-md font-semibold text-on-surface">
                        <span>{opt.text}</span>
                        <span className="text-primary font-bold">{opt.vote_count} votes ({pct}%)</span>
                      </div>
                      <div className="w-full bg-surface-container-high h-2.5 rounded-full overflow-hidden">
                        <div
                          className="bg-gradient-to-r from-purple-600 to-indigo-600 h-full rounded-full transition-all duration-500"
                          style={{ width: `${pct}%` }}
                        />
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          ) : (
            <p className="text-on-surface-variant text-body-sm italic text-center py-lg">
              No active poll right now. You can create a community poll from the Community Polls management page.
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
