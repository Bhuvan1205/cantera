import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { listDeposits } from '../../api/wallet';
import { getErrorMessage } from '../../api/client';
import { Alert, LoadingSpinner, EmptyState } from '../../components/common/Feedback';
import StatusBadge from '../../components/common/StatusBadge';

export default function DepositRequests() {
  const [deposits, setDeposits] = useState([]);
  const [statusFilter, setStatusFilter] = useState('all');
  const [limit, setLimit] = useState('25');
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchDeposits = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const data = await listDeposits({ status: statusFilter, limit });
      setDeposits(Array.isArray(data) ? data : []);
    } catch (err) {
      setError(getErrorMessage(err, 'Failed to fetch deposit requests.'));
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchDeposits();
  }, [statusFilter, limit]);

  return (
    <div className="p-lg md:p-xl space-y-xl max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-md">
        <div>
          <h1 className="font-headline-md text-headline-md text-on-surface">Deposit Requests</h1>
          <p className="font-body-md text-on-surface-variant mt-xs">
            Review and audit digital wallet balance top-ups and bank transfer confirmations.
          </p>
        </div>

        <button
          onClick={fetchDeposits}
          disabled={isLoading}
          className="p-sm bg-surface-container-low hover:bg-surface-container text-on-surface rounded-lg border border-outline-variant/30 transition-colors shadow-sm self-start md:self-auto"
          title="Refresh Deposits"
        >
          <span className={`material-symbols-outlined text-[20px] ${isLoading ? 'animate-spin' : ''}`}>
            refresh
          </span>
        </button>
      </div>

      {error && <Alert type="error" message={error} onClose={() => setError(null)} />}

      {/* Filters Bar */}
      <div className="bg-surface-container-lowest p-md rounded-2xl shadow-sm border border-outline-variant/20 flex flex-wrap items-center justify-between gap-md">
        <div className="flex flex-wrap items-center gap-md">
          {/* Status filter */}
          <div className="flex items-center gap-xs bg-surface-container px-sm py-xs rounded-lg">
            <span className="material-symbols-outlined text-outline text-[18px]">filter_list</span>
            <label className="font-label-caps text-on-surface-variant text-[11px] uppercase">
              Status:
            </label>
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              className="bg-transparent font-body-sm text-on-surface font-medium focus:outline-none cursor-pointer pr-xs"
            >
              <option value="all">All Statuses</option>
              <option value="awaiting_review">Awaiting Review</option>
              <option value="approved">Approved</option>
              <option value="rejected">Rejected</option>
            </select>
          </div>

          {/* Limit selector */}
          <div className="flex items-center gap-xs bg-surface-container px-sm py-xs rounded-lg">
            <label className="font-label-caps text-on-surface-variant text-[11px] uppercase">
              Show:
            </label>
            <select
              value={limit}
              onChange={(e) => setLimit(e.target.value)}
              className="bg-transparent font-body-sm text-on-surface font-medium focus:outline-none cursor-pointer pr-xs"
            >
              <option value="10">10</option>
              <option value="25">25</option>
              <option value="50">50</option>
              <option value="100">100</option>
            </select>
          </div>
        </div>

        <div className="font-label-caps text-on-surface-variant text-[11px] uppercase tracking-wider">
          Showing {deposits.length} Records
        </div>
      </div>

      {/* Deposits Table */}
      <div className="bg-surface-container-lowest rounded-2xl shadow-sm border border-outline-variant/20 overflow-hidden">
        {isLoading ? (
          <LoadingSpinner text="Fetching deposit requests..." />
        ) : deposits.length === 0 ? (
          <EmptyState
            icon="payments"
            title={statusFilter !== 'all' ? `No deposits matching status "${statusFilter}"` : 'No deposit records'}
            description="User wallet deposit submissions will appear here for verification."
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left font-body-md border-collapse">
              <thead>
                <tr className="bg-surface-container-low text-on-surface-variant font-label-caps text-label-caps uppercase tracking-wider border-b border-outline-variant/20">
                  <th className="p-table-cell-padding">Deposit ID</th>
                  <th className="p-table-cell-padding">User UID</th>
                  <th className="p-table-cell-padding text-right">Amount</th>
                  <th className="p-table-cell-padding">Gateway / UTR</th>
                  <th className="p-table-cell-padding">Status</th>
                  <th className="p-table-cell-padding">Created At</th>
                  <th className="p-table-cell-padding text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-outline-variant/10">
                {deposits.map((dep) => {
                  const depId = dep.deposit_id || dep.id;
                  const uid = dep.user_uid || dep.user_id || dep.uid;
                  const amount = Number(dep.amount || 0);
                  const status = dep.status || 'awaiting_review';
                  const gateway = dep.gateway || dep.reference_id || dep.utr || 'Direct Topup';
                  const createdAt = dep.created_at || dep.timestamp;

                  return (
                    <tr
                      key={depId}
                      className="hover:bg-surface-container-low/50 transition-colors group"
                    >
                      <td className="p-table-cell-padding font-data-mono font-bold text-primary">
                        {depId}
                      </td>

                      <td className="p-table-cell-padding font-data-mono text-body-sm">
                        <Link
                          to={`/wallet/investigation?uid=${encodeURIComponent(uid)}`}
                          className="hover:text-primary underline truncate block max-w-[140px]"
                          title={uid}
                        >
                          {uid}
                        </Link>
                      </td>

                      <td className="p-table-cell-padding text-right font-data-mono font-bold text-tertiary">
                        +₹{amount.toFixed(2)}
                      </td>

                      <td className="p-table-cell-padding font-body-sm text-on-surface-variant">
                        {gateway}
                      </td>

                      <td className="p-table-cell-padding">
                        <StatusBadge status={status} size="xs" />
                      </td>

                      <td className="p-table-cell-padding font-body-sm text-on-surface-variant whitespace-nowrap">
                        {createdAt ? new Date(createdAt).toLocaleString() : '—'}
                      </td>

                      <td className="p-table-cell-padding text-right">
                        <Link
                          to={`/wallet/investigation?uid=${encodeURIComponent(uid)}`}
                          className="inline-flex items-center gap-xs px-md py-xs bg-surface-container hover:bg-primary hover:text-on-primary text-on-surface rounded-lg font-body-sm font-medium transition-all shadow-sm"
                        >
                          <span>Audit</span>
                          <span className="material-symbols-outlined text-[16px]">account_balance_wallet</span>
                        </Link>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
