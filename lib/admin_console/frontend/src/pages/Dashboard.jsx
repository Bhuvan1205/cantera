import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { getHealth, ping } from '../api/auth';
import { useAuth } from '../context/AuthContext';
import { Alert, LoadingSpinner } from '../components/common/Feedback';
import StatusBadge from '../components/common/StatusBadge';

export default function Dashboard() {
  const { user } = useAuth();
  const [health, setHealth] = useState(null);
  const [pingStatus, setPingStatus] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchStatus = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const [healthData, pingData] = await Promise.all([
        getHealth().catch((e) => ({ status: 'unreachable', error: e.message })),
        ping().catch((e) => ({ status: 'error', error: e.message })),
      ]);
      setHealth(healthData);
      setPingStatus(pingData);
    } catch (err) {
      setError('Failed to fetch system diagnostic status.');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchStatus();
  }, []);

  return (
    <div className="p-lg md:p-xl space-y-xl max-w-7xl mx-auto">
      {/* Welcome Banner */}
      <div className="bg-gradient-to-r from-primary to-primary-container text-on-primary rounded-2xl p-xl shadow-md flex flex-col md:flex-row items-start md:items-center justify-between gap-lg relative overflow-hidden">
        <div className="z-10 space-y-xs">
          <div className="flex items-center gap-xs font-label-caps text-[11px] uppercase tracking-wider text-primary-fixed">
            <span className="material-symbols-outlined text-[16px]">verified_user</span>
            <span>Administrative Session Active</span>
          </div>
          <h1 className="font-display-lg text-display-lg font-bold">
            Welcome back, {user?.email || 'Administrator'}
          </h1>
          <p className="font-body-md text-on-primary-container max-w-xl">
            Live operations overview, service health monitoring, and administrative access control.
          </p>
        </div>

        <button
          onClick={fetchStatus}
          disabled={isLoading}
          className="z-10 px-md py-sm bg-surface-container-lowest/10 hover:bg-surface-container-lowest/20 backdrop-blur-md rounded-xl font-body-sm font-medium transition-all flex items-center gap-xs border border-white/20"
        >
          <span className={`material-symbols-outlined text-[18px] ${isLoading ? 'animate-spin' : ''}`}>
            refresh
          </span>
          <span>Refresh Status</span>
        </button>

        {/* Decorative circle */}
        <div className="absolute -right-16 -bottom-16 w-64 h-64 bg-white/5 rounded-full blur-2xl pointer-events-none"></div>
      </div>

      {error && <Alert type="error" message={error} onClose={() => setError(null)} />}

      {/* Health & Diagnostic Overview Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-lg">
        {/* Backend API Health */}
        <div className="bg-surface-container-lowest p-lg rounded-2xl shadow-sm border border-outline-variant/20 space-y-sm">
          <div className="flex items-center justify-between">
            <span className="font-label-caps text-on-surface-variant uppercase text-[11px]">
              Backend API
            </span>
            <div className="w-8 h-8 rounded-lg bg-surface-container flex items-center justify-center text-primary">
              <span className="material-symbols-outlined text-[18px]">dns</span>
            </div>
          </div>
          <div className="font-title-sm text-on-surface">
            {isLoading ? (
              <span className="text-on-surface-variant text-body-sm">Checking...</span>
            ) : health?.status === 'healthy' ? (
              <div className="flex items-center gap-xs text-tertiary">
                <span className="material-symbols-outlined text-[20px]">check_circle</span>
                <span>Healthy</span>
              </div>
            ) : (
              <div className="flex items-center gap-xs text-error">
                <span className="material-symbols-outlined text-[20px]">error</span>
                <span className="capitalize">{health?.status || 'Offline'}</span>
              </div>
            )}
          </div>
          <div className="font-data-mono text-[11px] text-on-surface-variant">
            Endpoint: GET /health
          </div>
        </div>

        {/* Admin Ping & Token Verification */}
        <div className="bg-surface-container-lowest p-lg rounded-2xl shadow-sm border border-outline-variant/20 space-y-sm">
          <div className="flex items-center justify-between">
            <span className="font-label-caps text-on-surface-variant uppercase text-[11px]">
              Auth & Security
            </span>
            <div className="w-8 h-8 rounded-lg bg-surface-container flex items-center justify-center text-primary">
              <span className="material-symbols-outlined text-[18px]">key</span>
            </div>
          </div>
          <div className="font-title-sm text-on-surface">
            {isLoading ? (
              <span className="text-on-surface-variant text-body-sm">Verifying...</span>
            ) : pingStatus?.status === 'ok' ? (
              <div className="flex items-center gap-xs text-tertiary">
                <span className="material-symbols-outlined text-[20px]">verified</span>
                <span>Admin Verified</span>
              </div>
            ) : (
              <div className="flex items-center gap-xs text-error">
                <span className="material-symbols-outlined text-[20px]">gpp_bad</span>
                <span>Invalid Auth</span>
              </div>
            )}
          </div>
          <div className="font-data-mono text-[11px] text-on-surface-variant">
            UID: {user?.uid ? `${user.uid.slice(0, 10)}...` : 'Unknown'}
          </div>
        </div>

        {/* Database Connectivity */}
        <div className="bg-surface-container-lowest p-lg rounded-2xl shadow-sm border border-outline-variant/20 space-y-sm">
          <div className="flex items-center justify-between">
            <span className="font-label-caps text-on-surface-variant uppercase text-[11px]">
              Firestore DB
            </span>
            <div className="w-8 h-8 rounded-lg bg-surface-container flex items-center justify-center text-primary">
              <span className="material-symbols-outlined text-[18px]">database</span>
            </div>
          </div>
          <div className="font-title-sm text-on-surface">
            {isLoading ? (
              <span className="text-on-surface-variant text-body-sm">Checking...</span>
            ) : health?.services?.firestore === 'connected' || health?.status === 'healthy' ? (
              <div className="flex items-center gap-xs text-tertiary">
                <span className="material-symbols-outlined text-[20px]">cloud_done</span>
                <span>Connected</span>
              </div>
            ) : (
              <div className="flex items-center gap-xs text-error">
                <span className="material-symbols-outlined text-[20px]">cloud_off</span>
                <span>Disconnected</span>
              </div>
            )}
          </div>
          <div className="font-data-mono text-[11px] text-on-surface-variant">
            Service: Firestore Native
          </div>
        </div>

        {/* App Environment */}
        <div className="bg-surface-container-lowest p-lg rounded-2xl shadow-sm border border-outline-variant/20 space-y-sm">
          <div className="flex items-center justify-between">
            <span className="font-label-caps text-on-surface-variant uppercase text-[11px]">
              Environment
            </span>
            <div className="w-8 h-8 rounded-lg bg-surface-container flex items-center justify-center text-primary">
              <span className="material-symbols-outlined text-[18px]">terminal</span>
            </div>
          </div>
          <div className="font-title-sm text-on-surface">
            <span className="capitalize font-semibold text-primary">Production-Ready</span>
          </div>
          <div className="font-data-mono text-[11px] text-on-surface-variant">
            Client: React Thin Client
          </div>
        </div>
      </div>

      {/* Fast Navigation Quick Actions */}
      <div className="space-y-md">
        <h2 className="font-title-sm text-on-surface">Quick Administrative Actions</h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-md">
          <Link
            to="/orders/create"
            className="p-lg bg-surface-container-lowest rounded-2xl border border-outline-variant/20 hover:border-primary hover:shadow-md transition-all group flex flex-col justify-between h-36"
          >
            <div className="flex items-center justify-between">
              <div className="w-10 h-10 rounded-xl bg-primary/10 text-primary flex items-center justify-center group-hover:bg-primary group-hover:text-on-primary transition-all">
                <span className="material-symbols-outlined text-[22px]">point_of_sale</span>
              </div>
              <span className="material-symbols-outlined text-outline group-hover:translate-x-1 group-hover:text-primary transition-all text-[20px]">
                arrow_forward
              </span>
            </div>
            <div>
              <div className="font-title-sm text-on-surface">Walk-in POS Order</div>
              <div className="font-body-sm text-on-surface-variant text-[12px] mt-xs">
                Manual customer order cashier flow
              </div>
            </div>
          </Link>

          <Link
            to="/inventory"
            className="p-lg bg-surface-container-lowest rounded-2xl border border-outline-variant/20 hover:border-primary hover:shadow-md transition-all group flex flex-col justify-between h-36"
          >
            <div className="flex items-center justify-between">
              <div className="w-10 h-10 rounded-xl bg-primary/10 text-primary flex items-center justify-center group-hover:bg-primary group-hover:text-on-primary transition-all">
                <span className="material-symbols-outlined text-[22px]">inventory_2</span>
              </div>
              <span className="material-symbols-outlined text-outline group-hover:translate-x-1 group-hover:text-primary transition-all text-[20px]">
                arrow_forward
              </span>
            </div>
            <div>
              <div className="font-title-sm text-on-surface">Menu Catalog</div>
              <div className="font-body-sm text-on-surface-variant text-[12px] mt-xs">
                Manage stock, prices & categories
              </div>
            </div>
          </Link>

          <Link
            to="/orders"
            className="p-lg bg-surface-container-lowest rounded-2xl border border-outline-variant/20 hover:border-primary hover:shadow-md transition-all group flex flex-col justify-between h-36"
          >
            <div className="flex items-center justify-between">
              <div className="w-10 h-10 rounded-xl bg-primary/10 text-primary flex items-center justify-center group-hover:bg-primary group-hover:text-on-primary transition-all">
                <span className="material-symbols-outlined text-[22px]">receipt_long</span>
              </div>
              <span className="material-symbols-outlined text-outline group-hover:translate-x-1 group-hover:text-primary transition-all text-[20px]">
                arrow_forward
              </span>
            </div>
            <div>
              <div className="font-title-sm text-on-surface">Live Orders Feed</div>
              <div className="font-body-sm text-on-surface-variant text-[12px] mt-xs">
                Track status and override tokens
              </div>
            </div>
          </Link>

          <Link
            to="/wallet/refunds"
            className="p-lg bg-surface-container-lowest rounded-2xl border border-outline-variant/20 hover:border-primary hover:shadow-md transition-all group flex flex-col justify-between h-36"
          >
            <div className="flex items-center justify-between">
              <div className="w-10 h-10 rounded-xl bg-primary/10 text-primary flex items-center justify-center group-hover:bg-primary group-hover:text-on-primary transition-all">
                <span className="material-symbols-outlined text-[22px]">currency_exchange</span>
              </div>
              <span className="material-symbols-outlined text-outline group-hover:translate-x-1 group-hover:text-primary transition-all text-[20px]">
                arrow_forward
              </span>
            </div>
            <div>
              <div className="font-title-sm text-on-surface">Refund Claims</div>
              <div className="font-body-sm text-on-surface-variant text-[12px] mt-xs">
                Audit and credit pending refunds
              </div>
            </div>
          </Link>
        </div>
      </div>
    </div>
  );
}
