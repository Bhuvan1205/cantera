import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { getRefund, updateRefundStatus } from '../../api/wallet';
import { getErrorMessage } from '../../api/client';
import { Alert, LoadingSpinner } from '../../components/common/Feedback';
import StatusBadge from '../../components/common/StatusBadge';

export default function RefundDetails() {
  const { id } = useParams();
  const refundId = id;

  const [refund, setRefund] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isUpdating, setIsUpdating] = useState(false);
  const [error, setError] = useState(null);
  const [successMsg, setSuccessMsg] = useState(null);

  // Rejection reason state
  const [rejectReason, setRejectReason] = useState('');
  const [showRejectForm, setShowRejectForm] = useState(false);

  const fetchRefund = async (targetId) => {
    const queryId = targetId || refundId;
    if (!queryId) {
      setError('Invalid or missing refund request ID.');
      setIsLoading(false);
      return;
    }

    setIsLoading(true);
    setError(null);
    try {
      const data = await getRefund(queryId);
      setRefund(data);
    } catch (err) {
      setError(getErrorMessage(err, `Failed to load refund request: ${queryId}`));
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    if (!refundId) {
      setError('Invalid or missing refund request ID.');
      setIsLoading(false);
      return;
    }
    fetchRefund(refundId);
  }, [refundId]);

  const handleUpdateStatus = async (targetStatus, reason = null) => {
    const activeId = refund?.request_id || refund?.refund_id || refundId;
    if (!activeId) {
      setError('Cannot update status: missing refund request ID.');
      return;
    }

    setIsUpdating(true);
    setError(null);
    setSuccessMsg(null);
    try {
      const payload = { status: targetStatus };
      if (reason && reason.trim()) {
        payload.reason = reason.trim();
      }

      const updated = await updateRefundStatus(activeId, payload);
      setRefund(updated);
      setSuccessMsg(`Refund successfully updated to status: "${targetStatus}".`);
      setShowRejectForm(false);
      setRejectReason('');
    } catch (err) {
      setError(getErrorMessage(err, `Failed to transition refund to ${targetStatus}.`));
    } finally {
      setIsUpdating(false);
    }
  };

  if (isLoading) {
    return (
      <div className="p-xl max-w-7xl mx-auto">
        <LoadingSpinner text={`Loading refund request ${refundId || ''}...`} />
      </div>
    );
  }

  if (error && !refund) {
    return (
      <div className="p-xl max-w-7xl mx-auto space-y-md">
        <Alert type="error" message={error} />
        <Link
          to="/wallet/refunds"
          className="inline-flex items-center gap-xs px-md py-sm bg-surface-container rounded-lg font-body-sm font-medium"
        >
          <span className="material-symbols-outlined text-[18px]">arrow_back</span>
          <span>Back to Refunds</span>
        </Link>
      </div>
    );
  }

  const reqId = refund.request_id || refund.refund_id || refundId;
  const userUid = refund.user_uid || refund.userId || '—';
  const orderId = refund.order_id || refund.orderId || '—';
  const amount = Number(refund.amount || 0);
  const status = refund.status || 'refund_requested';
  const isTerminal = status === 'approved' || status === 'credited' || status === 'rejected';

  return (
    <div className="p-lg md:p-xl space-y-xl max-w-7xl mx-auto">
      {/* Breadcrumb */}
      <div className="flex items-center gap-xs text-on-surface-variant font-body-sm">
        <Link to="/wallet/refunds" className="hover:text-primary transition-colors">
          Refunds
        </Link>
        <span className="material-symbols-outlined text-[14px]">chevron_right</span>
        <span className="text-on-surface font-medium">Request #{reqId}</span>
      </div>

      {successMsg && (
        <Alert type="success" message={successMsg} onClose={() => setSuccessMsg(null)} />
      )}
      {error && <Alert type="error" message={error} onClose={() => setError(null)} />}

      {/* Header Banner */}
      <div className="bg-surface-container-lowest rounded-2xl shadow-sm border border-outline-variant/20 p-xl flex flex-col md:flex-row md:items-center justify-between gap-lg">
        <div>
          <div className="flex items-center gap-sm flex-wrap">
            <h1 className="font-headline-md text-headline-md text-on-surface">
              Refund Request: <span className="font-data-mono text-primary">{reqId}</span>
            </h1>
            <StatusBadge status={status} />
          </div>
          <p className="font-body-md text-on-surface-variant mt-xs">
            Created on {refund.created_at ? new Date(refund.created_at).toLocaleString() : '—'}
          </p>
        </div>

        <div className="bg-surface-container rounded-xl p-lg flex flex-col items-start md:items-end gap-xs border border-outline-variant/10">
          <span className="font-label-caps text-on-surface-variant uppercase text-[10px]">
            Refund Value
          </span>
          <span className="font-display-lg text-[32px] font-bold text-error font-data-mono">
            ₹{amount.toFixed(2)}
          </span>
        </div>
      </div>

      {/* Details Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-lg">
        {/* Request Information */}
        <div className="bg-surface-container-lowest rounded-2xl shadow-sm border border-outline-variant/20 p-xl space-y-md">
          <h2 className="font-title-sm text-on-surface flex items-center gap-xs">
            <span className="material-symbols-outlined text-primary">description</span>
            <span>Request Details</span>
          </h2>

          <div className="space-y-sm text-body-md divide-y divide-outline-variant/10">
            <div className="flex justify-between py-xs">
              <span className="text-on-surface-variant">User UID</span>
              <Link
                to={`/users/${encodeURIComponent(userUid)}`}
                className="font-data-mono text-primary hover:underline"
              >
                {userUid}
              </Link>
            </div>
            <div className="flex justify-between py-xs">
              <span className="text-on-surface-variant">Order Reference</span>
              <Link
                to={`/orders/${encodeURIComponent(orderId)}`}
                className="font-data-mono text-secondary hover:underline"
              >
                {orderId}
              </Link>
            </div>
            <div className="flex justify-between py-xs">
              <span className="text-on-surface-variant">Forensic Investigation</span>
              <Link
                to={`/wallet/investigation?uid=${encodeURIComponent(userUid)}`}
                className="text-primary font-semibold hover:underline flex items-center gap-xs"
              >
                <span>Audit User Ledger</span>
                <span className="material-symbols-outlined text-[16px]">arrow_forward</span>
              </Link>
            </div>
            <div className="py-xs space-y-1">
              <span className="text-on-surface-variant text-body-sm block">Customer Reason</span>
              <p className="font-body-md text-on-surface bg-surface-container p-sm rounded-lg border border-outline-variant/20">
                {refund.reason || 'No statement provided by customer.'}
              </p>
            </div>
          </div>
        </div>

        {/* Audit & Administrative Processing */}
        <div className="bg-surface-container-lowest rounded-2xl shadow-sm border border-outline-variant/20 p-xl space-y-md flex flex-col justify-between">
          <div className="space-y-md">
            <h2 className="font-title-sm text-on-surface flex items-center gap-xs">
              <span className="material-symbols-outlined text-primary">verified_user</span>
              <span>Administrative Action</span>
            </h2>

            {refund.reviewed_at && (
              <div className="bg-surface-container p-md rounded-xl space-y-xs text-body-sm border border-outline-variant/20">
                <div className="flex justify-between">
                  <span className="text-on-surface-variant">Reviewed By</span>
                  <span className="font-data-mono text-on-surface">{refund.reviewed_by || 'Admin'}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-on-surface-variant">Reviewed At</span>
                  <span className="text-on-surface">{new Date(refund.reviewed_at).toLocaleString()}</span>
                </div>
                {refund.reject_reason && (
                  <div className="pt-xs border-t border-outline-variant/20">
                    <span className="text-error font-semibold block mb-0.5">Rejection Reason</span>
                    <p className="text-on-surface">{refund.reject_reason}</p>
                  </div>
                )}
              </div>
            )}

            {!isTerminal && (
              <div className="space-y-sm">
                <p className="font-body-sm text-on-surface-variant">
                  Approving will automatically trigger the backend atomic transaction to credit{' '}
                  <strong className="text-on-surface">₹{amount.toFixed(2)}</strong> back to the user's wallet.
                </p>

                {showRejectForm ? (
                  <div className="space-y-sm p-md bg-surface-container-low rounded-xl border border-error/20">
                    <label className="block font-label-caps text-on-surface uppercase text-[11px]">
                      Reason for Rejection *
                    </label>
                    <textarea
                      rows={2}
                      value={rejectReason}
                      onChange={(e) => setRejectReason(e.target.value)}
                      placeholder="e.g. Order was already collected and confirmed by PIN."
                      className="w-full p-sm bg-surface-container border border-outline-variant/50 rounded-lg font-body-sm text-on-surface focus:ring-2 focus:ring-error resize-none"
                    />
                    <div className="flex justify-end gap-xs">
                      <button
                        type="button"
                        onClick={() => setShowRejectForm(false)}
                        className="px-sm py-1 bg-surface-container rounded-lg text-body-sm"
                      >
                        Cancel
                      </button>
                      <button
                        type="button"
                        onClick={() => handleUpdateStatus('rejected', rejectReason)}
                        disabled={isUpdating || !rejectReason.trim()}
                        className="px-md py-1 bg-error text-on-error rounded-lg text-body-sm font-semibold disabled:opacity-50"
                      >
                        Confirm Rejection
                      </button>
                    </div>
                  </div>
                ) : null}
              </div>
            )}
          </div>

          {/* Action Buttons */}
          {!isTerminal && !showRejectForm && (
            <div className="pt-md border-t border-outline-variant/20 flex flex-wrap items-center gap-sm">
              {status === 'refund_requested' && (
                <button
                  type="button"
                  onClick={() => handleUpdateStatus('refund_under_review')}
                  disabled={isUpdating}
                  className="px-md py-sm bg-surface-container hover:bg-surface-container-high text-on-surface rounded-xl font-body-sm font-semibold transition-colors disabled:opacity-50"
                >
                  Mark Under Review
                </button>
              )}

              <button
                type="button"
                onClick={() => handleUpdateStatus('approved')}
                disabled={isUpdating}
                className="px-md py-sm bg-tertiary hover:bg-tertiary-container text-on-tertiary rounded-xl font-body-sm font-semibold shadow-sm transition-all flex items-center gap-xs disabled:opacity-50"
              >
                <span className="material-symbols-outlined text-[18px]">check_circle</span>
                <span>Approve & Credit Wallet</span>
              </button>

              <button
                type="button"
                onClick={() => setShowRejectForm(true)}
                disabled={isUpdating}
                className="px-md py-sm bg-error-container hover:bg-error text-on-error-container hover:text-on-error rounded-xl font-body-sm font-semibold transition-all disabled:opacity-50"
              >
                Reject Request
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
