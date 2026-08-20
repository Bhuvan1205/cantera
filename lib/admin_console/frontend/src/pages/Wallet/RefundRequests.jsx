import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { listRefunds } from '../../api/wallet';
import { getUser } from '../../api/users';
import { getErrorMessage } from '../../api/client';
import { Alert, LoadingSpinner, EmptyState } from '../../components/common/Feedback';
import StatusBadge from '../../components/common/StatusBadge';

export default function RefundRequests() {
  const [refunds, setRefunds] = useState([]);
  const [selectedStatus, setSelectedStatus] = useState('all');
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);
  // Map of uid → display name/email resolved from the Users collection.
  const [userDisplayMap, setUserDisplayMap] = useState({});

  const fetchRefunds = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const data = await listRefunds({ status: selectedStatus });
      const list = Array.isArray(data) ? data : [];
      setRefunds(list);

      // Batch-resolve human-readable identities for all unique UIDs in this page.
      const uniqueUids = [...new Set(
        list
          .map((r) => r.user_uid || r.userId)
          .filter(Boolean)
      )];

      const resolved = {};
      await Promise.allSettled(
        uniqueUids.map(async (uid) => {
          try {
            const detail = await getUser(uid);
            const name = detail?.profile?.name || detail?.name || null;
            const email = detail?.profile?.email || detail?.email || null;
            resolved[uid] = name || email || null;
          } catch {
            resolved[uid] = null;
          }
        })
      );
      setUserDisplayMap(resolved);
    } catch (err) {
      setError(getErrorMessage(err, 'Failed to fetch refund requests.'));
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchRefunds();
  }, [selectedStatus]);

  const statuses = [
    { value: 'all', label: 'All Statuses' },
    { value: 'refund_requested', label: 'Pending Request' },
    { value: 'refund_under_review', label: 'Under Review' },
    { value: 'approved', label: 'Approved' },
    { value: 'credited', label: 'Credited' },
    { value: 'rejected', label: 'Rejected' },
  ];

  return (
    <div className="p-lg md:p-xl space-y-xl max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-md">
        <div>
          <h1 className="font-headline-md text-headline-md text-on-surface">Refund Requests</h1>
          <p className="font-body-md text-on-surface-variant mt-xs">
            Review customer refund requests, perform ledger audit, and approve/reject wallet refunds.
          </p>
        </div>

        <button
          onClick={fetchRefunds}
          disabled={isLoading}
          className="p-sm bg-surface-container-low hover:bg-surface-container text-on-surface rounded-lg border border-outline-variant/30 transition-colors shadow-sm self-start sm:self-auto"
          title="Refresh Refunds"
        >
          <span className={`material-symbols-outlined text-[20px] ${isLoading ? 'animate-spin' : ''}`}>
            refresh
          </span>
        </button>
      </div>

      {error && <Alert type="error" message={error} onClose={() => setError(null)} />}

      {/* Filter Tabs */}
      <div className="bg-surface-container-lowest p-md rounded-2xl shadow-sm border border-outline-variant/20 flex items-center gap-xs overflow-x-auto scrollbar-hide">
        {statuses.map((tab) => {
          const isActive = selectedStatus === tab.value;
          return (
            <button
              key={tab.value}
              onClick={() => setSelectedStatus(tab.value)}
              className={`px-md py-xs rounded-full font-body-sm font-medium whitespace-nowrap transition-all ${
                isActive
                  ? 'bg-primary text-on-primary shadow-sm'
                  : 'bg-surface-container text-on-surface-variant hover:bg-surface-variant/40'
              }`}
            >
              {tab.label}
            </button>
          );
        })}
      </div>

      {/* Refunds Table */}
      <div className="bg-surface-container-lowest rounded-2xl shadow-sm border border-outline-variant/20 overflow-hidden">
        {isLoading ? (
          <LoadingSpinner text="Fetching refund requests..." />
        ) : refunds.length === 0 ? (
          <EmptyState
            icon="assignment_return"
            title="No refund requests"
            description="No refund records match the selected status filter."
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left font-body-md border-collapse">
              <thead>
                <tr className="bg-surface-container-low text-on-surface-variant font-label-caps text-label-caps uppercase tracking-wider border-b border-outline-variant/20">
                  <th className="p-table-cell-padding">Customer</th>
                  <th className="p-table-cell-padding">Order Ref</th>
                  <th className="p-table-cell-padding text-right">Amount</th>
                  <th className="p-table-cell-padding">Status</th>
                  <th className="p-table-cell-padding">Reason</th>
                  <th className="p-table-cell-padding">Requested At</th>
                  <th className="p-table-cell-padding text-right">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-outline-variant/10">
                {refunds.map((ref) => {
                  const reqId = ref.request_id || ref.refund_id || ref.id;
                  const userUid = ref.user_uid || ref.userId || '—';
                  const orderId = ref.order_id || ref.orderId || '—';
                  const amount = Number(ref.amount || 0);
                  // Use resolved name/email from userDisplayMap, or a neutral fallback (no UID fragment).
                  const resolvedDisplay =
                    (userUid !== '—' && userDisplayMap[userUid]) || null;
                  const customerName =
                    ref.user_name || ref.user_email || resolvedDisplay || 'Customer';
                  const tokenNum = ref.token_number || ref.tokenNumber;
                  const orderRef = orderId !== '—' ? (tokenNum ? `Token #${tokenNum}` : `#${orderId.slice(0, 6).toUpperCase()}`) : '—';

                  return (
                    <tr
                      key={reqId}
                      className="hover:bg-surface-container-low/50 transition-colors"
                    >
                      <td className="p-table-cell-padding font-body-sm">
                        {userUid !== '—' ? (
                          <Link
                            to={`/users/${encodeURIComponent(userUid)}`}
                            className="font-semibold text-on-surface hover:text-primary hover:underline truncate block max-w-[160px]"
                            title={customerName}
                          >
                            {customerName}
                          </Link>
                        ) : (
                          <span className="font-medium text-on-surface">{customerName}</span>
                        )}
                      </td>

                      <td className="p-table-cell-padding font-data-mono text-body-sm">
                        {orderId !== '—' ? (
                          <Link
                            to={`/orders/${encodeURIComponent(orderId)}`}
                            className="font-bold text-primary hover:underline truncate block max-w-[140px]"
                            title={orderId}
                          >
                            {orderRef}
                          </Link>
                        ) : (
                          <span className="text-outline">—</span>
                        )}
                      </td>

                      <td className="p-table-cell-padding text-right font-data-mono font-bold text-error">
                        ₹{amount.toFixed(2)}
                      </td>

                      <td className="p-table-cell-padding">
                        <StatusBadge status={ref.status || 'refund_requested'} size="xs" />
                      </td>

                      <td className="p-table-cell-padding font-body-sm text-on-surface-variant max-w-xs truncate">
                        {ref.reason || 'No reason provided'}
                      </td>

                      <td className="p-table-cell-padding font-body-sm text-on-surface-variant whitespace-nowrap">
                        {ref.created_at ? new Date(ref.created_at).toLocaleString() : '—'}
                      </td>

                      <td className="p-table-cell-padding text-right">
                        <Link
                          to={`/wallet/refunds/${encodeURIComponent(reqId)}`}
                          className="inline-flex items-center gap-xs px-sm py-1 bg-surface-container hover:bg-primary hover:text-on-primary text-on-surface rounded-lg font-body-sm font-medium transition-all shadow-sm"
                        >
                          <span>Review</span>
                          <span className="material-symbols-outlined text-[16px]">arrow_forward</span>
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
