import React, { useState, useEffect } from 'react';
import { useSearchParams, Link } from 'react-router-dom';
import { getWalletInvestigation } from '../../api/wallet';
import { getErrorMessage } from '../../api/client';
import { Alert, LoadingSpinner, EmptyState } from '../../components/common/Feedback';
import StatusBadge from '../../components/common/StatusBadge';

export default function WalletInvestigation() {
  const [searchParams, setSearchParams] = useSearchParams();
  const initialUid = searchParams.get('uid') || '';

  const [inputUid, setInputUid] = useState(initialUid);
  const [investigationData, setInvestigationData] = useState(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState(null);

  const fetchInvestigation = async (uidToFetch) => {
    if (!uidToFetch || !uidToFetch.trim()) return;
    setIsLoading(true);
    setError(null);
    try {
      const data = await getWalletInvestigation(uidToFetch.trim());
      setInvestigationData(data);
    } catch (err) {
      setError(getErrorMessage(err, `Failed to fetch wallet audit for UID: ${uidToFetch}`));
      setInvestigationData(null);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    if (initialUid) {
      fetchInvestigation(initialUid);
    }
  }, [initialUid]);

  const handleSearchSubmit = (e) => {
    e.preventDefault();
    if (inputUid.trim()) {
      setSearchParams({ uid: inputUid.trim() });
      fetchInvestigation(inputUid.trim());
    }
  };

  const balance = Number(investigationData?.balance ?? 0);
  const totalAdded = Number(investigationData?.total_added ?? 0);
  const totalSpent = Number(investigationData?.total_spent ?? 0);
  const transactions = investigationData?.transactions || [];
  const pendingDeposits = investigationData?.pending_deposits || [];
  const refundRequests = investigationData?.refund_requests || [];

  return (
    <div className="p-lg md:p-xl space-y-xl max-w-7xl mx-auto">
      {/* Header */}
      <div>
        <h1 className="font-headline-md text-headline-md text-on-surface">
          User Wallet Investigation
        </h1>
        <p className="font-body-md text-on-surface-variant mt-xs">
          Perform forensic financial audits, transaction ledger cross-checks, and pending dispute investigations.
        </p>
      </div>

      {/* Search Bar for UID */}
      <div className="bg-surface-container-lowest p-lg rounded-2xl shadow-sm border border-outline-variant/20">
        <form onSubmit={handleSearchSubmit} className="flex flex-col sm:flex-row gap-sm items-center">
          <div className="relative flex-1 w-full">
            <span className="material-symbols-outlined absolute left-md top-1/2 -translate-y-1/2 text-outline text-[20px]">
              search
            </span>
            <input
              type="text"
              required
              value={inputUid}
              onChange={(e) => setInputUid(e.target.value)}
              placeholder="Enter User Firebase UID (e.g. 7h8d9f...)"
              className="w-full pl-[42px] pr-md py-sm bg-surface-container border border-outline-variant/40 rounded-xl font-data-mono text-body-md text-on-surface focus:outline-none focus:ring-2 focus:ring-primary focus:bg-surface-container-lowest"
            />
          </div>

          <button
            type="submit"
            disabled={isLoading || !inputUid.trim()}
            className="w-full sm:w-auto px-lg py-sm bg-primary text-on-primary rounded-xl font-body-sm font-semibold hover:bg-primary-container shadow-sm transition-all flex items-center justify-center gap-xs disabled:opacity-50"
          >
            {isLoading ? (
              <>
                <span className="material-symbols-outlined animate-spin text-[18px]">refresh</span>
                <span>Investigating...</span>
              </>
            ) : (
              <>
                <span className="material-symbols-outlined text-[18px]">troubleshoot</span>
                <span>Run Investigation</span>
              </>
            )}
          </button>
        </form>
      </div>

      {error && <Alert type="error" message={error} onClose={() => setError(null)} />}

      {/* Investigation Results */}
      {isLoading ? (
        <LoadingSpinner text={`Auditing wallet ledger for UID: ${inputUid}...`} />
      ) : investigationData ? (
        <div className="space-y-xl">
          {/* Top Summary Cards */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-md">
            <div className="bg-surface-container-lowest p-lg rounded-2xl shadow-sm border border-outline-variant/20">
              <div className="font-label-caps text-on-surface-variant uppercase text-[10px]">
                Investigated User
              </div>
              <div className="font-data-mono font-bold text-on-surface text-body-sm truncate mt-xs" title={investigationData.user_uid}>
                {investigationData.user_uid}
              </div>
              <Link
                to={`/users/${encodeURIComponent(investigationData.user_uid)}`}
                className="text-primary text-body-sm font-semibold hover:underline mt-xs inline-block"
              >
                View Account Profile →
              </Link>
            </div>

            <div className="bg-surface-container-lowest p-lg rounded-2xl shadow-sm border border-outline-variant/20">
              <div className="font-label-caps text-on-surface-variant uppercase text-[10px]">
                Current Balance
              </div>
              <div className="font-display-lg text-[26px] font-bold text-primary font-data-mono mt-xs">
                ₹{balance.toFixed(2)}
              </div>
            </div>

            <div className="bg-surface-container-lowest p-lg rounded-2xl shadow-sm border border-outline-variant/20">
              <div className="font-label-caps text-on-surface-variant uppercase text-[10px]">
                Total Lifetime Deposited
              </div>
              <div className="font-display-lg text-[26px] font-bold text-tertiary font-data-mono mt-xs">
                +₹{totalAdded.toFixed(2)}
              </div>
            </div>

            <div className="bg-surface-container-lowest p-lg rounded-2xl shadow-sm border border-outline-variant/20">
              <div className="font-label-caps text-on-surface-variant uppercase text-[10px]">
                Total Lifetime Spent
              </div>
              <div className="font-display-lg text-[26px] font-bold text-error font-data-mono mt-xs">
                -₹{totalSpent.toFixed(2)}
              </div>
            </div>
          </div>

          {/* Pending Deposits & Refund Requests Sub-tables */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-lg">
            {/* Pending Deposits */}
            <div className="bg-surface-container-lowest rounded-2xl shadow-sm border border-outline-variant/20 overflow-hidden">
              <div className="p-md bg-surface-container-low border-b border-outline-variant/20 flex items-center justify-between">
                <h3 className="font-title-sm text-on-surface flex items-center gap-xs">
                  <span className="material-symbols-outlined text-primary">account_balance</span>
                  <span>Pending / Recent Deposits ({pendingDeposits.length})</span>
                </h3>
              </div>

              {pendingDeposits.length === 0 ? (
                <div className="p-lg text-center text-on-surface-variant font-body-sm">
                  No deposit records for this user.
                </div>
              ) : (
                <div className="overflow-x-auto max-h-72">
                  <table className="w-full text-left font-body-sm">
                    <thead>
                      <tr className="bg-surface-container text-on-surface-variant text-[11px] uppercase font-label-caps">
                        <th className="p-sm">Deposit ID</th>
                        <th className="p-sm text-right">Amount</th>
                        <th className="p-sm">Gateway / Ref</th>
                        <th className="p-sm">Status</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-outline-variant/10">
                      {pendingDeposits.map((dep, idx) => (
                        <tr key={dep.deposit_id || idx} className="hover:bg-surface-container-low/50">
                          <td className="p-sm font-data-mono text-primary font-semibold">{dep.deposit_id}</td>
                          <td className="p-sm text-right font-data-mono font-bold text-tertiary">
                            ₹{Number(dep.amount || 0).toFixed(2)}
                          </td>
                          <td className="p-sm text-on-surface-variant text-[12px]">
                            {dep.razorpay_payment_id || dep.gateway || 'direct'}
                          </td>
                          <td className="p-sm">
                            <StatusBadge status={dep.status || 'awaiting_review'} size="xs" />
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>

            {/* Refund Requests */}
            <div className="bg-surface-container-lowest rounded-2xl shadow-sm border border-outline-variant/20 overflow-hidden">
              <div className="p-md bg-surface-container-low border-b border-outline-variant/20 flex items-center justify-between">
                <h3 className="font-title-sm text-on-surface flex items-center gap-xs">
                  <span className="material-symbols-outlined text-primary">assignment_return</span>
                  <span>Refund Disputes ({refundRequests.length})</span>
                </h3>
              </div>

              {refundRequests.length === 0 ? (
                <div className="p-lg text-center text-on-surface-variant font-body-sm">
                  No refund requests for this user.
                </div>
              ) : (
                <div className="overflow-x-auto max-h-72">
                  <table className="w-full text-left font-body-sm">
                    <thead>
                      <tr className="bg-surface-container text-on-surface-variant text-[11px] uppercase font-label-caps">
                        <th className="p-sm">Request ID</th>
                        <th className="p-sm text-right">Amount</th>
                        <th className="p-sm">Order ID</th>
                        <th className="p-sm">Status</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-outline-variant/10">
                      {refundRequests.map((ref, idx) => (
                        <tr key={ref.request_id || idx} className="hover:bg-surface-container-low/50">
                          <td className="p-sm font-data-mono font-semibold">
                            <Link
                              to={`/wallet/refunds/${encodeURIComponent(ref.request_id || ref.id)}`}
                              className="text-primary hover:underline"
                            >
                              {ref.request_id || ref.id}
                            </Link>
                          </td>
                          <td className="p-sm text-right font-data-mono font-bold text-error">
                            ₹{Number(ref.amount || 0).toFixed(2)}
                          </td>
                          <td className="p-sm font-data-mono text-[12px]">
                            {ref.order_id ? (
                              <Link to={`/orders/${encodeURIComponent(ref.order_id)}`} className="text-secondary hover:underline">
                                {ref.order_id}
                              </Link>
                            ) : (
                              '—'
                            )}
                          </td>
                          <td className="p-sm">
                            <StatusBadge status={ref.status || 'refund_requested'} size="xs" />
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          </div>

          {/* Full Transaction History Ledger */}
          <div className="bg-surface-container-lowest rounded-2xl shadow-sm border border-outline-variant/20 overflow-hidden">
            <div className="p-lg bg-surface-container-low border-b border-outline-variant/20 flex items-center justify-between">
              <h2 className="font-title-sm text-on-surface flex items-center gap-xs">
                <span className="material-symbols-outlined text-primary">receipt_long</span>
                <span>Complete Ledger Transactions ({transactions.length})</span>
              </h2>
            </div>

            {transactions.length === 0 ? (
              <div className="p-xl text-center text-on-surface-variant font-body-sm">
                No ledger transactions found for this UID.
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-left font-body-md border-collapse">
                  <thead>
                    <tr className="bg-surface-container text-on-surface-variant font-label-caps text-label-caps uppercase tracking-wider border-b border-outline-variant/20">
                      <th className="p-table-cell-padding">Txn ID</th>
                      <th className="p-table-cell-padding">Timestamp</th>
                      <th className="p-table-cell-padding">Type & Ref</th>
                      <th className="p-table-cell-padding text-right">Amount</th>
                      <th className="p-table-cell-padding text-right">Balance After</th>
                      <th className="p-table-cell-padding">Status</th>
                      <th className="p-table-cell-padding">Gateway / Actor</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-outline-variant/10">
                    {transactions.map((tx, idx) => {
                      const txId = tx.transaction_id || `TXN-${idx}`;
                      const isCredit =
                        String(tx.type).toLowerCase().includes('deposit') ||
                        String(tx.type).toLowerCase().includes('refund') ||
                        Number(tx.amount || 0) > 0;

                      return (
                        <tr key={txId} className="hover:bg-surface-container-low/50 transition-colors">
                          <td className="p-table-cell-padding font-data-mono text-primary font-bold">
                            {txId}
                          </td>
                          <td className="p-table-cell-padding font-body-sm text-on-surface-variant whitespace-nowrap">
                            {tx.timestamp ? new Date(tx.timestamp).toLocaleString() : '—'}
                          </td>
                          <td className="p-table-cell-padding">
                            <div className="font-medium text-on-surface capitalize">{tx.type}</div>
                            {tx.reference_id && (
                              <div className="font-data-mono text-[11px] text-outline">
                                Ref ({tx.reference_type || 'id'}): {tx.reference_id}
                              </div>
                            )}
                          </td>
                          <td
                            className={`p-table-cell-padding text-right font-data-mono font-bold ${
                              isCredit ? 'text-tertiary' : 'text-error'
                            }`}
                          >
                            {isCredit ? '+' : ''}₹{Number(tx.amount || 0).toFixed(2)}
                          </td>
                          <td className="p-table-cell-padding text-right font-data-mono text-on-surface">
                            {tx.balance_after !== null && tx.balance_after !== undefined
                              ? `₹${Number(tx.balance_after).toFixed(2)}`
                              : '—'}
                          </td>
                          <td className="p-table-cell-padding">
                            <StatusBadge status={tx.status || 'completed'} size="xs" />
                          </td>
                          <td className="p-table-cell-padding font-body-sm text-on-surface-variant">
                            {tx.gateway || tx.initiated_by || 'system'}
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
      ) : (
        <EmptyState
          icon="manage_search"
          title="No Active Audit"
          description="Enter a user's Firebase UID above to pull their real-time wallet ledger, pending deposits, and refund disputes."
        />
      )}
    </div>
  );
}
