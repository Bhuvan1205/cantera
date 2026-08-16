import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { getUser } from '../../api/users';
import { getErrorMessage } from '../../api/client';
import { Alert, LoadingSpinner } from '../../components/common/Feedback';
import StatusBadge from '../../components/common/StatusBadge';

export default function UserDetails() {
  const { uid } = useParams();
  const [userData, setUserData] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    async function fetchUserDetails() {
      setIsLoading(true);
      setError(null);
      try {
        const data = await getUser(uid);
        setUserData(data);
      } catch (err) {
        setError(getErrorMessage(err, `Failed to load profile for UID: ${uid}`));
      } finally {
        setIsLoading(false);
      }
    }
    if (uid) {
      fetchUserDetails();
    }
  }, [uid]);

  if (isLoading) {
    return (
      <div className="p-xl max-w-7xl mx-auto">
        <LoadingSpinner text={`Loading profile for UID: ${uid}...`} />
      </div>
    );
  }

  if (error || !userData) {
    return (
      <div className="p-xl max-w-7xl mx-auto space-y-md">
        <Alert type="error" message={error || 'User not found'} />
        <Link
          to="/users"
          className="inline-flex items-center gap-xs px-md py-sm bg-surface-container text-on-surface rounded-lg hover:bg-surface-container-high font-body-sm font-medium transition-colors"
        >
          <span className="material-symbols-outlined text-[18px]">arrow_back</span>
          <span>Back to Users</span>
        </Link>
      </div>
    );
  }

  const profile = userData.profile || {};
  const wallet = userData.wallet || {};
  const transactions = userData.transactions || [];

  const name = profile.name || 'Unnamed User';
  const role = profile.is_admin ? 'Admin' : 'Customer';
  const balance = Number(wallet.balance ?? 0);
  const totalAdded = Number(wallet.total_added ?? 0);
  const totalSpent = Number(wallet.total_spent ?? 0);

  return (
    <div className="p-lg md:p-xl space-y-xl max-w-7xl mx-auto">
      {/* Breadcrumb & Navigation */}
      <div className="flex items-center gap-xs text-on-surface-variant font-body-sm">
        <Link to="/users" className="hover:text-primary transition-colors">
          Users
        </Link>
        <span className="material-symbols-outlined text-[14px]">chevron_right</span>
        <span className="text-on-surface font-medium">{name}</span>
      </div>

      {/* User Header Profile Card */}
      <div className="bg-surface-container-lowest rounded-2xl shadow-sm border border-outline-variant/20 p-xl flex flex-col md:flex-row md:items-center justify-between gap-lg">
        <div className="flex items-start gap-lg">
          {profile.profile_photo ? (
            <img
              src={profile.profile_photo}
              alt={name}
              className="w-16 h-16 rounded-2xl object-cover border border-outline-variant/20 shadow-md"
            />
          ) : (
            <div className="w-16 h-16 rounded-2xl bg-primary text-on-primary font-bold text-headline-md flex items-center justify-center shadow-md">
              {name.charAt(0).toUpperCase()}
            </div>
          )}
          <div>
            <div className="flex items-center gap-sm flex-wrap">
              <h1 className="font-headline-md text-headline-md text-on-surface">{name}</h1>
              <span className={`font-label-caps text-[11px] uppercase px-2 py-0.5 rounded-full font-bold ${
                profile.is_admin
                  ? 'bg-primary-fixed text-on-primary-fixed'
                  : 'bg-surface-container text-on-surface-variant'
              }`}>
                {role}
              </span>
            </div>
            <p className="font-body-md text-on-surface-variant mt-xs font-data-mono">
              UID: {profile.uid || uid}
            </p>
            <p className="font-body-sm text-on-surface-variant">{profile.email || 'No email registered'}</p>
          </div>
        </div>

        <div className="bg-surface-container rounded-xl p-lg flex flex-col items-start md:items-end gap-xs border border-outline-variant/10">
          <span className="font-label-caps text-on-surface-variant uppercase text-[10px]">
            Live Wallet Balance
          </span>
          <span className="font-display-lg text-[28px] font-bold text-primary font-data-mono">
            ₹{balance.toFixed(2)}
          </span>
          <Link
            to={`/wallet/investigation?uid=${encodeURIComponent(profile.uid || uid)}`}
            className="text-primary font-body-sm font-semibold hover:underline flex items-center gap-xs mt-xs"
          >
            <span>Full Forensic Audit</span>
            <span className="material-symbols-outlined text-[16px]">arrow_forward</span>
          </Link>
        </div>
      </div>

      {/* Profile Details Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-lg">
        {/* Contact & Account Metadata */}
        <div className="bg-surface-container-lowest rounded-2xl shadow-sm border border-outline-variant/20 p-xl space-y-md">
          <h2 className="font-title-sm text-on-surface flex items-center gap-xs">
            <span className="material-symbols-outlined text-primary">badge</span>
            <span>Account Profile</span>
          </h2>
          <div className="space-y-sm text-body-md divide-y divide-outline-variant/10">
            <div className="flex justify-between py-xs">
              <span className="text-on-surface-variant">Phone Number</span>
              <span className="font-medium text-on-surface">{profile.phone || '—'}</span>
            </div>

            <div className="flex justify-between py-xs">
              <span className="text-on-surface-variant">Admin Privilege</span>
              <StatusBadge status={profile.is_admin ? 'active' : 'inactive'} size="xs" />
            </div>
          </div>
        </div>

        {/* Financial Summary */}
        <div className="bg-surface-container-lowest rounded-2xl shadow-sm border border-outline-variant/20 p-xl space-y-md">
          <h2 className="font-title-sm text-on-surface flex items-center gap-xs">
            <span className="material-symbols-outlined text-primary">account_balance_wallet</span>
            <span>Wallet Financial Snapshot</span>
          </h2>
          <div className="space-y-sm text-body-md divide-y divide-outline-variant/10">
            <div className="flex justify-between py-xs">
              <span className="text-on-surface-variant">Current Balance</span>
              <span className="font-data-mono font-bold text-primary">₹{balance.toFixed(2)}</span>
            </div>
            <div className="flex justify-between py-xs">
              <span className="text-on-surface-variant">Total Added (Lifetime)</span>
              <span className="font-data-mono font-bold text-tertiary">+₹{totalAdded.toFixed(2)}</span>
            </div>
            <div className="flex justify-between py-xs">
              <span className="text-on-surface-variant">Total Spent (Lifetime)</span>
              <span className="font-data-mono font-bold text-error">-₹{totalSpent.toFixed(2)}</span>
            </div>
          </div>
        </div>
      </div>

      {/* Recent Ledger / Activity */}
      <div className="bg-surface-container-lowest rounded-2xl shadow-sm border border-outline-variant/20 overflow-hidden">
        <div className="p-lg bg-surface-container-low border-b border-outline-variant/20 flex items-center justify-between">
          <h2 className="font-title-sm text-on-surface flex items-center gap-xs">
            <span className="material-symbols-outlined text-primary">receipt_long</span>
            <span>Wallet Transaction Ledger</span>
          </h2>
          <span className="font-label-caps text-on-surface-variant text-[11px] uppercase">
            {transactions.length} Records
          </span>
        </div>

        {transactions.length === 0 ? (
          <div className="p-xl text-center text-on-surface-variant">
            <span className="material-symbols-outlined text-[36px] opacity-40 mb-xs">
              history_edu
            </span>
            <p>No wallet transaction records found for this user.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left font-body-md border-collapse">
              <thead>
                <tr className="bg-surface-container-lowest text-on-surface-variant font-label-caps text-label-caps uppercase tracking-wider border-b border-outline-variant/20">
                  <th className="p-table-cell-padding">Txn ID</th>
                  <th className="p-table-cell-padding">Timestamp</th>
                  <th className="p-table-cell-padding">Type & Ref</th>
                  <th className="p-table-cell-padding text-right">Amount</th>
                  <th className="p-table-cell-padding text-right">Balance After</th>
                  <th className="p-table-cell-padding">Status</th>
                  <th className="p-table-cell-padding">Gateway / Initiator</th>
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
  );
}
