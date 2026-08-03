import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { listOrders } from '../../api/orders';
import { getErrorMessage } from '../../api/client';
import { Alert, LoadingSpinner, EmptyState } from '../../components/common/Feedback';
import StatusBadge from '../../components/common/StatusBadge';

export default function OrderList() {
  const [orders, setOrders] = useState([]);
  const [statusFilter, setStatusFilter] = useState('all');
  const [limit, setLimit] = useState('25');
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchOrders = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const data = await listOrders({ status: statusFilter, limit });
      setOrders(Array.isArray(data) ? data : []);
    } catch (err) {
      setError(getErrorMessage(err, 'Failed to fetch orders list.'));
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchOrders();
  }, [statusFilter, limit]);

  return (
    <div className="p-lg md:p-xl space-y-xl max-w-7xl mx-auto">
      {/* Header Bar */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-md">
        <div>
          <h1 className="font-headline-md text-headline-md text-on-surface">Order Operations</h1>
          <p className="font-body-md text-on-surface-variant mt-xs">
            Monitor incoming customer food orders, prep progress, and token fulfillment.
          </p>
        </div>

        <div className="flex items-center gap-sm">
          <button
            onClick={fetchOrders}
            disabled={isLoading}
            className="p-sm bg-surface-container-low hover:bg-surface-container text-on-surface rounded-lg border border-outline-variant/30 transition-colors shadow-sm"
            title="Refresh Feed"
          >
            <span className={`material-symbols-outlined text-[20px] ${isLoading ? 'animate-spin' : ''}`}>
              refresh
            </span>
          </button>

          <Link
            to="/orders/create"
            className="px-md py-sm bg-primary text-on-primary rounded-xl font-body-sm font-semibold hover:bg-primary-container shadow-sm flex items-center gap-xs transition-all"
          >
            <span className="material-symbols-outlined text-[20px]">point_of_sale</span>
            <span>Manual Cashier Order</span>
          </Link>
        </div>
      </div>

      {error && <Alert type="error" message={error} onClose={() => setError(null)} />}

      {/* Filters Toolbar */}
      <div className="bg-surface-container-lowest p-md rounded-2xl shadow-sm border border-outline-variant/20 flex flex-wrap items-center justify-between gap-md">
        <div className="flex flex-wrap items-center gap-md">
          {/* Status Filter */}
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
              <option value="all">All Orders</option>
              <option value="placed">Placed</option>
              <option value="preparing">Preparing</option>
              <option value="delivered">Delivered</option>
              <option value="cancelled">Cancelled</option>
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
          Showing {orders.length} Orders
        </div>
      </div>

      {/* Orders Table */}
      <div className="bg-surface-container-lowest rounded-2xl shadow-sm border border-outline-variant/20 overflow-hidden">
        {isLoading ? (
          <LoadingSpinner text="Fetching active orders..." />
        ) : orders.length === 0 ? (
          <EmptyState
            icon="receipt_long"
            title={statusFilter !== 'all' ? `No orders in "${statusFilter}" state` : 'No orders recorded'}
            description="Incoming food orders from mobile apps and POS will be displayed here."
            action={
              <Link
                to="/orders/create"
                className="px-md py-xs bg-primary text-on-primary rounded-lg font-body-sm"
              >
                Create Manual Order
              </Link>
            }
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left font-body-md border-collapse">
              <thead>
                <tr className="bg-surface-container-low text-on-surface-variant font-label-caps text-label-caps uppercase tracking-wider border-b border-outline-variant/20">
                  <th className="p-table-cell-padding">Order ID</th>
                  <th className="p-table-cell-padding">Placed At</th>
                  <th className="p-table-cell-padding">Customer / UID</th>
                  <th className="p-table-cell-padding">Items</th>
                  <th className="p-table-cell-padding text-right">Total</th>
                  <th className="p-table-cell-padding">Status</th>
                  <th className="p-table-cell-padding text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-outline-variant/10">
                {orders.map((ord) => {
                  const orderId = ord.order_id || ord.id;
                  const uid = ord.user_id || ord.uid;
                  const total = Number(ord.total_amount ?? ord.total ?? 0);
                  const itemsCount = ord.items?.length || 0;
                  const timestamp = ord.created_at || ord.timestamp;
                  const status = ord.status || 'placed';

                  return (
                    <tr
                      key={orderId}
                      className="hover:bg-surface-container-low/50 transition-colors group"
                    >
                      <td className="p-table-cell-padding font-data-mono font-bold text-primary">
                        {orderId}
                      </td>

                      <td className="p-table-cell-padding font-body-sm text-on-surface-variant whitespace-nowrap">
                        {timestamp ? new Date(timestamp).toLocaleTimeString() : '—'}
                      </td>

                      <td className="p-table-cell-padding text-body-sm">
                        {ord.user_name ? (
                          <div>
                            <div className="font-semibold text-on-surface">{ord.user_name}</div>
                            {uid && uid !== 'admin_placed' ? (
                              <Link
                                to={`/users/${encodeURIComponent(uid)}`}
                                className="font-data-mono text-outline hover:text-primary hover:underline block truncate max-w-[130px] text-[11px]"
                                title={uid}
                              >
                                {uid}
                              </Link>
                            ) : null}
                          </div>
                        ) : uid ? (
                          <Link
                            to={`/users/${encodeURIComponent(uid)}`}
                            className="font-data-mono text-outline hover:text-primary hover:underline block truncate max-w-[130px]"
                            title={uid}
                          >
                            {uid}
                          </Link>
                        ) : (
                          <span className="italic text-on-surface-variant">Walk-in Customer</span>
                        )}
                      </td>

                      <td className="p-table-cell-padding font-body-sm">
                        <div className="flex items-center gap-xs">
                          <span className="font-semibold text-on-surface">{itemsCount}</span>
                          <span className="text-on-surface-variant">
                            {itemsCount === 1 ? 'item' : 'items'}
                          </span>
                        </div>
                      </td>

                      <td className="p-table-cell-padding text-right font-data-mono font-bold text-on-surface">
                        ₹{total.toFixed(2)}
                      </td>

                      <td className="p-table-cell-padding">
                        <StatusBadge status={status} size="xs" />
                      </td>

                      <td className="p-table-cell-padding text-right">
                        <Link
                          to={`/orders/${encodeURIComponent(orderId)}`}
                          className="inline-flex items-center gap-xs px-md py-xs bg-surface-container hover:bg-primary hover:text-on-primary text-on-surface rounded-lg font-body-sm font-medium transition-all shadow-sm"
                        >
                          <span>Manage</span>
                          <span className="material-symbols-outlined text-[16px]">
                            arrow_forward
                          </span>
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
