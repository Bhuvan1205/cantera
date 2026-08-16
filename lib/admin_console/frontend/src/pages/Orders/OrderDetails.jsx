import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { getOrder, getOrderTokens, updateOrderStatus } from '../../api/orders';
import { getErrorMessage } from '../../api/client';
import { Alert, LoadingSpinner } from '../../components/common/Feedback';
import StatusBadge from '../../components/common/StatusBadge';

export default function OrderDetails() {
  const { id: orderId } = useParams();
  const [order, setOrder] = useState(null);
  const [tokens, setTokens] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);
  const [successMsg, setSuccessMsg] = useState(null);

  // Status override state
  const [selectedStatus, setSelectedStatus] = useState('');
  const [isUpdating, setIsUpdating] = useState(false);

  const fetchOrderData = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const [orderData, tokensData] = await Promise.all([
        getOrder(orderId),
        getOrderTokens(orderId).catch(() => []),
      ]);
      setOrder(orderData);
      setTokens(Array.isArray(tokensData) ? tokensData : []);
      if (orderData?.status) {
        setSelectedStatus(orderData.status);
      }
    } catch (err) {
      setError(getErrorMessage(err, `Failed to load order #${orderId}`));
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    if (orderId) {
      fetchOrderData();
    }
  }, [orderId]);

  const handleStatusUpdate = async (e) => {
    e.preventDefault();
    if (!selectedStatus || selectedStatus === order?.status) return;

    setIsUpdating(true);
    setError(null);
    setSuccessMsg(null);

    try {
      await updateOrderStatus(orderId, selectedStatus);
      setSuccessMsg(`Order #${orderId} status updated to "${selectedStatus}".`);
      await fetchOrderData();
    } catch (err) {
      setError(getErrorMessage(err, 'Failed to update order status.'));
    } finally {
      setIsUpdating(false);
    }
  };

  if (isLoading) {
    return (
      <div className="p-xl max-w-7xl mx-auto">
        <LoadingSpinner text={`Loading order #${orderId}...`} />
      </div>
    );
  }

  if (error && !order) {
    return (
      <div className="p-xl max-w-7xl mx-auto space-y-md">
        <Alert type="error" message={error} />
        <Link
          to="/orders"
          className="inline-flex items-center gap-xs px-md py-sm bg-surface-container text-on-surface rounded-lg hover:bg-surface-container-high font-body-sm font-medium transition-colors"
        >
          <span className="material-symbols-outlined text-[18px]">arrow_back</span>
          <span>Back to Orders</span>
        </Link>
      </div>
    );
  }

  const items = order.items || [];
  const totalAmount = Number(order.total_amount ?? order.total ?? 0);
  const uid = order.user_id || order.uid;
  const status = order.status || 'placed';
  const createdAt = order.created_at || order.timestamp;

  return (
    <div className="p-lg md:p-xl space-y-xl max-w-7xl mx-auto">
      {/* Navigation Breadcrumb */}
      <div className="flex items-center gap-xs text-on-surface-variant font-body-sm">
        <Link to="/orders" className="hover:text-primary transition-colors">
          Orders
        </Link>
        <span className="material-symbols-outlined text-[14px]">chevron_right</span>
        <span className="text-on-surface font-medium">Order #{orderId}</span>
      </div>

      {successMsg && (
        <Alert type="success" message={successMsg} onClose={() => setSuccessMsg(null)} />
      )}
      {error && <Alert type="error" message={error} onClose={() => setError(null)} />}

      {/* Header Banner */}
      <div className="flex flex-col lg:flex-row justify-between items-start lg:items-center gap-md bg-surface-container rounded-2xl p-xl shadow-sm relative overflow-hidden">
        <div className="z-10 flex flex-col gap-sm">
          <div className="flex flex-wrap items-center gap-sm">
            <span className="font-display-lg text-display-lg text-on-surface">
              Order #{orderId}
            </span>
            <StatusBadge status={status} size="md" />
            {order.overall_status && (
              <StatusBadge status={order.overall_status} size="md" />
            )}
          </div>

          <div className="flex flex-wrap items-center gap-md font-body-md text-on-surface-variant">
            <div className="flex items-center gap-xs">
              <span className="material-symbols-outlined text-[18px]">schedule</span>
              <span>Placed: {createdAt ? new Date(createdAt).toLocaleString() : '—'}</span>
            </div>

            <span className="w-1 h-1 bg-outline-variant rounded-full"></span>

            <div className="flex items-center gap-xs">
              <span className="material-symbols-outlined text-[18px]">payments</span>
              <span className="capitalize">{order.payment_method || 'Digital'}</span>
            </div>

            {uid && (
              <>
                <span className="w-1 h-1 bg-outline-variant rounded-full"></span>
                <div className="flex items-center gap-xs">
                  <span className="material-symbols-outlined text-[18px]">person</span>
                  <Link
                    to={`/users/${encodeURIComponent(uid)}`}
                    className="text-primary font-medium hover:underline"
                  >
                    User: {uid}
                  </Link>
                </div>
              </>
            )}
          </div>
        </div>

        <div className="z-10 flex flex-col items-start lg:items-end gap-xs">
          <span className="font-headline-md text-headline-md text-primary font-bold">
            ₹{totalAmount.toFixed(2)}
          </span>
          <span className="font-body-sm text-on-surface-variant font-medium">Grand Total</span>
        </div>
      </div>

      {/* Main Grid: Left Ordered Items & Tokens, Right Status Override */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-lg">
        {/* Left Side: Items & Fulfillment Tokens (8 cols) */}
        <div className="lg:col-span-8 space-y-lg">
          {/* Order Items Card */}
          <div className="bg-surface-container-lowest rounded-2xl shadow-sm border border-outline-variant/20 overflow-hidden">
            <div className="p-lg bg-surface-container-low border-b border-outline-variant/20 flex items-center justify-between">
              <h2 className="font-title-sm text-on-surface flex items-center gap-xs">
                <span className="material-symbols-outlined text-primary">restaurant_menu</span>
                <span>Ordered Items</span>
              </h2>
              <span className="font-label-caps text-on-surface-variant text-[11px] uppercase">
                {items.length} Line Items
              </span>
            </div>

            <div className="divide-y divide-outline-variant/10">
              {items.map((item, idx) => {
                const itemTotal = (item.price || 0) * (item.quantity || 1);

                return (
                  <div key={idx} className="p-lg flex items-center justify-between gap-md">
                    <div className="flex items-center gap-md">
                      <div className="w-10 h-10 rounded-xl bg-surface-container text-primary flex items-center justify-center font-bold font-data-mono">
                        {item.quantity || 1}x
                      </div>
                      <div>
                        <div className="font-semibold text-on-surface">{item.name}</div>
                        <div className="font-body-sm text-on-surface-variant text-[12px] flex items-center gap-xs">
                          <span className="capitalize">{item.category || 'General'}</span>
                          <span>•</span>
                          <span className="font-data-mono">₹{Number(item.price || 0).toFixed(2)} each</span>
                        </div>
                      </div>
                    </div>

                    <div className="font-data-mono font-bold text-on-surface text-right">
                      ₹{itemTotal.toFixed(2)}
                    </div>
                  </div>
                );
              })}
            </div>

            <div className="p-lg bg-surface-container-low border-t border-outline-variant/20 flex justify-between items-center">
              <span className="font-title-sm text-on-surface">Subtotal</span>
              <span className="font-data-mono font-bold text-headline-md text-primary">
                ₹{totalAmount.toFixed(2)}
              </span>
            </div>
          </div>

          {/* Fulfillment Tokens Card */}
          <div className="bg-surface-container-lowest rounded-2xl shadow-sm border border-outline-variant/20 overflow-hidden">
            <div className="p-lg bg-surface-container-low border-b border-outline-variant/20 flex items-center justify-between">
              <h2 className="font-title-sm text-on-surface flex items-center gap-xs">
                <span className="material-symbols-outlined text-primary">confirmation_number</span>
                <span>Fulfillment Tokens</span>
              </h2>
              <span className="font-label-caps text-on-surface-variant text-[11px] uppercase">
                {tokens.length} Counter Tokens
              </span>
            </div>

            {tokens.length === 0 ? (
              <div className="p-xl text-center text-on-surface-variant">
                No active token allocations recorded for this order.
              </div>
            ) : (
              <div className="p-lg grid grid-cols-1 sm:grid-cols-2 gap-md">
                {tokens.map((tok, idx) => {
                  const counterName = tok.counter_name || tok.counter || `Counter ${idx + 1}`;
                  const tokenNumber = tok.token_number || tok.token || tok.otp || `#${idx + 1}`;
                  const estTime = tok.estimated_prep_time || tok.estimated_time;
                  const queuePos = tok.queue_position;

                  return (
                    <div
                      key={tok.token_id || idx}
                      className="bg-surface-container-low p-md rounded-xl border border-outline-variant/20 space-y-sm"
                    >
                      <div className="flex items-center justify-between">
                        <span className="font-label-caps text-[11px] uppercase font-bold text-primary">
                          {counterName}
                        </span>
                        <StatusBadge status={tok.token_status || tok.status || 'preparing'} size="xs" />
                      </div>

                      <div className="flex items-baseline gap-xs">
                        <span className="font-display-lg text-[32px] font-bold text-on-surface font-data-mono">
                          {tokenNumber}
                        </span>
                        <span className="font-label-caps text-on-surface-variant text-[10px] uppercase">
                          TOKEN
                        </span>
                      </div>

                      {(estTime || queuePos !== undefined) && (
                        <div className="text-body-sm text-on-surface-variant pt-xs border-t border-outline-variant/10 flex justify-between">
                          {queuePos !== undefined && (
                            <span>Queue: #{queuePos}</span>
                          )}
                          {estTime && (
                            <span>Prep: {estTime} min</span>
                          )}
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </div>

        {/* Right Side: Status Override Controls (4 cols) */}
        <div className="lg:col-span-4">
          <div className="bg-surface-container-lowest rounded-2xl shadow-sm border border-outline-variant/20 p-lg sticky top-20 space-y-lg">
            <div>
              <h3 className="font-title-sm text-on-surface flex items-center gap-xs">
                <span className="material-symbols-outlined text-primary">rule</span>
                <span>Status Override</span>
              </h3>
              <p className="font-body-sm text-on-surface-variant mt-xs">
                Directly transition this order through its preparation and delivery lifecycle.
              </p>
            </div>

            <form onSubmit={handleStatusUpdate} className="space-y-md">
              <div>
                <label className="block font-label-caps text-on-surface-variant uppercase text-[11px] mb-xs">
                  Lifecycle Status
                </label>
                <select
                  value={selectedStatus}
                  onChange={(e) => setSelectedStatus(e.target.value)}
                  className="w-full bg-surface-container border border-outline-variant/50 p-sm rounded-xl font-body-md text-on-surface focus:outline-none focus:ring-2 focus:ring-primary cursor-pointer"
                >
                  <option value="placed">Placed (Order Received)</option>
                  <option value="preparing">Preparing (In Kitchen)</option>
                  <option value="ready_for_pickup">Ready for Pickup (At Counter)</option>
                  <option value="delivered">Delivered (Completed)</option>
                  <option value="cancelled">Cancelled (Void Order)</option>
                </select>
              </div>

              <button
                type="submit"
                disabled={isUpdating || selectedStatus === order?.status}
                className="w-full py-sm px-md rounded-xl font-body-sm font-semibold text-on-primary bg-primary hover:bg-primary-container active:scale-[0.99] transition-all shadow-md flex items-center justify-center gap-xs disabled:opacity-50"
              >
                {isUpdating ? (
                  <>
                    <span className="material-symbols-outlined animate-spin text-[18px]">
                      refresh
                    </span>
                    <span>Updating Status...</span>
                  </>
                ) : (
                  <>
                    <span className="material-symbols-outlined text-[18px]">save</span>
                    <span>Apply Status Override</span>
                  </>
                )}
              </button>
            </form>

            <div className="pt-sm border-t border-outline-variant/10 text-body-sm text-on-surface-variant space-y-xs">
              <div className="flex justify-between">
                <span>Order Reference:</span>
                <span className="font-data-mono font-medium text-on-surface">{orderId}</span>
              </div>
              <div className="flex justify-between">
                <span>Current State:</span>
                <StatusBadge status={order?.status} size="xs" />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
