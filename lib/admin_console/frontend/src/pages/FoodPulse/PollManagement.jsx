import React, { useState, useEffect } from 'react';
import { getVendorDashboard, createPoll, closePoll } from '../../api/foodpulse';
import { BarChart3, Plus, CheckCircle2, AlertCircle, XCircle, Vote } from 'lucide-react';

const SECTIONS = ['Bakery', 'Mess', 'Continental', 'Beverages'];

export default function PollManagement() {
  const [activePoll, setActivePoll] = useState(null);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [msg, setMsg] = useState({ type: '', text: '' });

  // Form state
  const [question, setQuestion] = useState('Which item would you like to see added to the canteen?');
  const [section, setSection] = useState('Beverages');
  const [options, setOptions] = useState(['Lassi', 'Cold Coffee', 'Buttermilk']);

  const loadPoll = async () => {
    try {
      setLoading(true);
      const dash = await getVendorDashboard();
      setActivePoll(dash.active_poll || null);
    } catch (err) {
      console.error('Failed to load active poll:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadPoll();
  }, []);

  const handleAddOption = () => {
    if (options.length < 6) {
      setOptions([...options, '']);
    }
  };

  const handleRemoveOption = (idx) => {
    if (options.length > 2) {
      setOptions(options.filter((_, i) => i !== idx));
    }
  };

  const handleOptionChange = (idx, val) => {
    const next = [...options];
    next[idx] = val;
    setOptions(next);
  };

  const handleCreatePoll = async (e) => {
    e.preventDefault();
    const validOpts = options.map((o) => o.trim()).filter(Boolean);

    if (validOpts.length < 2) {
      setMsg({ type: 'error', text: 'Please enter at least 2 valid poll options.' });
      return;
    }

    try {
      setSubmitting(true);
      setMsg({ type: '', text: '' });
      const newPoll = await createPoll(question.trim(), section, validOpts);
      setActivePoll(newPoll);
      setMsg({ type: 'success', text: 'New community poll created successfully!' });
    } catch (err) {
      setMsg({
        type: 'error',
        text: err.response?.data?.detail || 'Failed to create community poll.',
      });
    } finally {
      setSubmitting(false);
    }
  };

  const handleClosePoll = async () => {
    if (!activePoll) return;
    try {
      setSubmitting(true);
      await closePoll(activePoll.id);
      setActivePoll(null);
      setMsg({ type: 'success', text: 'Poll closed successfully.' });
    } catch (err) {
      setMsg({ type: 'error', text: 'Failed to close poll.' });
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="space-y-6 max-w-5xl mx-auto p-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-100 flex items-center gap-2">
            <BarChart3 className="w-7 h-7 text-purple-400" />
            Community Poll Management
          </h1>
          <p className="text-sm text-slate-400 mt-1">
            Create and monitor real-time student demand polls across canteen sections.
          </p>
        </div>
      </div>

      {msg.text && (
        <div
          className={`p-4 rounded-xl flex items-center gap-3 border ${
            msg.type === 'success'
              ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-400'
              : 'bg-rose-500/10 border-rose-500/30 text-rose-400'
          }`}
        >
          {msg.type === 'success' ? (
            <CheckCircle2 className="w-5 h-5 shrink-0" />
          ) : (
            <AlertCircle className="w-5 h-5 shrink-0" />
          )}
          <span className="text-sm font-medium">{msg.text}</span>
        </div>
      )}

      {/* Active Poll Display Card */}
      <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-xl">
        <div className="flex items-center justify-between border-b border-slate-800 pb-4 mb-4">
          <div className="flex items-center gap-3">
            <span className="px-3 py-1 bg-purple-500/20 text-purple-300 text-xs font-bold uppercase rounded-full border border-purple-500/30">
              Active Poll
            </span>
            {activePoll && (
              <span className="text-xs text-slate-400">
                Total Participants: <strong className="text-white">{activePoll.total_votes}</strong>
              </span>
            )}
          </div>
          {activePoll && (
            <button
              onClick={handleClosePoll}
              disabled={submitting}
              className="px-3 py-1.5 bg-rose-500/20 hover:bg-rose-500/30 text-rose-300 text-xs font-semibold rounded-lg transition border border-rose-500/30 flex items-center gap-1.5"
            >
              <XCircle className="w-4 h-4" />
              Close Poll
            </button>
          )}
        </div>

        {loading ? (
          <div className="py-8 text-center text-slate-400 text-sm">Loading active poll...</div>
        ) : activePoll ? (
          <div className="space-y-4">
            <div className="flex justify-between items-start">
              <div>
                <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                  Section: {activePoll.section}
                </span>
                <h2 className="text-lg font-bold text-white mt-1">{activePoll.question}</h2>
              </div>
              {(() => {
                const winningOpt = activePoll.options?.reduce((max, opt) => (opt.vote_count > (max?.vote_count || 0) ? opt : max), null);
                if (winningOpt && winningOpt.vote_count > 0) {
                  return (
                    <span className="px-3 py-1 bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 text-xs font-bold rounded-lg flex items-center gap-1">
                      🏆 Winning Option: {winningOpt.text} ({winningOpt.vote_count} votes)
                    </span>
                  );
                }
                return null;
              })()}
            </div>

            <div className="space-y-3 pt-2">
              {activePoll.options.map((opt) => {
                const pct =
                  activePoll.total_votes > 0
                    ? Math.round((opt.vote_count / activePoll.total_votes) * 100)
                    : 0;

                return (
                  <div key={opt.id} className="bg-slate-800/60 p-3.5 rounded-xl border border-slate-700/50">
                    <div className="flex justify-between items-center text-sm font-semibold text-slate-200 mb-1.5">
                      <span>{opt.text}</span>
                      <span className="text-purple-400 font-bold">
                        {opt.vote_count} votes ({pct}%)
                      </span>
                    </div>
                    <div className="w-full bg-slate-700/60 h-2.5 rounded-full overflow-hidden">
                      <div
                        className="bg-gradient-to-r from-purple-500 to-indigo-500 h-full rounded-full transition-all duration-500"
                        style={{ width: `${pct}%` }}
                      />
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        ) : (
          <div className="py-8 text-center text-slate-400 text-sm">
            No active poll right now. Create a new poll below!
          </div>
        )}
      </div>

      {/* Create New Poll Form */}
      <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-xl">
        <h2 className="text-lg font-bold text-white mb-1 flex items-center gap-2">
          <Plus className="w-5 h-5 text-purple-400" />
          Create New Community Poll
        </h2>
        <p className="text-xs text-slate-400 mb-6">
          Publishing a new poll will automatically close any currently active poll.
        </p>

        <form onSubmit={handleCreatePoll} className="space-y-5">
          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-2">
              Poll Question *
            </label>
            <input
              type="text"
              required
              value={question}
              onChange={(e) => setQuestion(e.target.value)}
              className="w-full bg-slate-800/80 border border-slate-700 rounded-xl px-4 py-2.5 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-purple-500"
              placeholder="e.g. Which item would you like to see added to the canteen?"
            />
          </div>

          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-2">
              Canteen Section *
            </label>
            <select
              value={section}
              onChange={(e) => setSection(e.target.value)}
              className="w-full bg-slate-800/80 border border-slate-700 rounded-xl px-4 py-2.5 text-sm text-white focus:outline-none focus:border-purple-500"
            >
              {SECTIONS.map((sec) => (
                <option key={sec} value={sec}>
                  {sec}
                </option>
              ))}
            </select>
          </div>

          <div>
            <div className="flex justify-between items-center mb-2">
              <label className="text-xs font-semibold text-slate-300">
                Poll Options (Min 2, Max 6) *
              </label>
              {options.length < 6 && (
                <button
                  type="button"
                  onClick={handleAddOption}
                  className="text-xs text-purple-400 font-semibold hover:underline"
                >
                  + Add Option
                </button>
              )}
            </div>

            <div className="space-y-2.5">
              {options.map((opt, idx) => (
                <div key={idx} className="flex gap-2">
                  <input
                    type="text"
                    required
                    value={opt}
                    onChange={(e) => handleOptionChange(idx, e.target.value)}
                    className="flex-1 bg-slate-800/80 border border-slate-700 rounded-xl px-4 py-2 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-purple-500"
                    placeholder={`Option ${idx + 1}`}
                  />
                  {options.length > 2 && (
                    <button
                      type="button"
                      onClick={() => handleRemoveOption(idx)}
                      className="px-3 text-rose-400 hover:bg-rose-500/10 rounded-xl transition text-xs font-semibold"
                    >
                      Remove
                    </button>
                  )}
                </div>
              ))}
            </div>
          </div>

          <button
            type="submit"
            disabled={submitting}
            className="w-full py-3 bg-purple-600 hover:bg-purple-700 text-white font-bold rounded-xl shadow-lg shadow-purple-600/30 transition disabled:opacity-50 text-sm flex items-center justify-center gap-2"
          >
            <Vote className="w-4 h-4" />
            {submitting ? 'Publishing Poll...' : 'Publish Community Poll'}
          </button>
        </form>
      </div>
    </div>
  );
}
