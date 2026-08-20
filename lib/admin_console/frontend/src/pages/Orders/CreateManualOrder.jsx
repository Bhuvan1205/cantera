import React, { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { listInventory } from '../../api/inventory';
import { createManualOrder } from '../../api/orders';
import { getErrorMessage } from '../../api/client';
import { Alert, LoadingSpinner, EmptyState } from '../../components/common/Feedback';
import StatusBadge from '../../components/common/StatusBadge';

export default function CreateManualOrder() {
  const navigate = useNavigate();

  // State
  const [menuItems, setMenuItems] = useState([]);
  const [cart, setCart] = useState([]); // Array of { menu_id, name, price (int), category, quantity }
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [search, setSearch] = useState('');
  const [paymentMethod, setPaymentMethod] = useState('cash'); // 'cash' | 'card' | 'upi'

  const [isLoadingMenu, setIsLoadingMenu] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState(null);

  // Fetch live inventory
  useEffect(() => {
    async function fetchMenu() {
      setIsLoadingMenu(true);
      setError(null);
      try {
        const data = await listInventory();
        setMenuItems(Array.isArray(data) ? data : []);
      } catch (err) {
        setError(getErrorMessage(err, 'Failed to load menu catalog from backend inventory.'));
      } finally {
        setIsLoadingMenu(false);
      }
    }
    fetchMenu();
  }, []);

  // Compute unique categories
  const categories = [
    'all',
    ...new Set(
      menuItems.map((item) => (item.category || 'other').toLowerCase()).filter(Boolean)
    ),
  ];

  // Filtered menu
  const filteredMenu = menuItems.filter((item) => {
    const matchesCategory =
      selectedCategory === 'all' ||
      (item.category || '').toLowerCase() === selectedCategory.toLowerCase();
    const term = search.toLowerCase().trim();
    const matchesSearch =
      !term ||
      (item.name || '').toLowerCase().includes(term) ||
      (item.description || '').toLowerCase().includes(term);
    return matchesCategory && matchesSearch;
  });

  // Cart operations
  const addToCart = (item) => {
    if (!item.is_available) return;
    const menuId = item.menu_id || item.id;
    const itemPrice = parseInt(item.price, 10) || 0;

    setCart((prev) => {
      const existing = prev.find((ci) => ci.menu_id === menuId);
      if (existing) {
        return prev.map((ci) =>
          ci.menu_id === menuId ? { ...ci, quantity: ci.quantity + 1 } : ci
        );
      } else {
        return [
          ...prev,
          {
            menu_id: menuId,
            name: item.name,
            price: itemPrice,
            category: (item.category || 'mess').toLowerCase(),
            quantity: 1,
          },
        ];
      }
    });
  };

  const updateQuantity = (menuId, delta) => {
    setCart((prev) =>
      prev
        .map((ci) => {
          if (ci.menu_id === menuId) {
            const newQty = ci.quantity + delta;
            return newQty > 0 ? { ...ci, quantity: newQty } : null;
          }
          return ci;
        })
        .filter(Boolean)
    );
  };

  const removeFromCart = (menuId) => {
    setCart((prev) => prev.filter((ci) => ci.menu_id !== menuId));
  };

  const clearCart = () => setCart([]);

  // Calculate totals
  const totalItemsCount = cart.reduce((acc, ci) => acc + ci.quantity, 0);
  const totalAmount = cart.reduce((acc, ci) => acc + ci.price * ci.quantity, 0);

  // Submit manual order
  const handlePlaceOrder = async () => {
    if (cart.length === 0) {
      setError('Please add items to cart before submitting.');
      return;
    }

    setIsSubmitting(true);
    setError(null);

    try {
      const orderPayload = {
        items: cart.map((ci) => ({
          name: ci.name.trim(),
          price: parseInt(ci.price, 10),
          quantity: parseInt(ci.quantity, 10),
          category: ci.category.toLowerCase().trim(),
        })),
        payment_method: paymentMethod, // 'cash' | 'card' | 'upi'
      };

      const response = await createManualOrder(orderPayload);
      const createdOrderId = response.order_id || response.id;

      // Navigate to order details
      navigate(`/orders/${encodeURIComponent(createdOrderId)}`);
    } catch (err) {
      setError(getErrorMessage(err, 'Failed to place manual order.'));
      setIsSubmitting(false);
    }
  };

  return (
    <div className="p-lg md:p-xl max-w-7xl mx-auto space-y-md">
      {/* ── Page Header ─────────────────────────────────────────────────── */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-sm">
        <div>
          {/* Breadcrumb */}
          <div className="flex items-center gap-xs text-on-surface-variant font-body-sm mb-xs">
            <Link to="/orders" className="hover:text-primary transition-colors">Orders</Link>
            <span className="material-symbols-outlined text-[14px]">chevron_right</span>
            <span className="text-on-surface font-medium">Walk-in POS</span>
          </div>
          <h1 className="font-headline-sm text-headline-sm text-on-surface leading-tight">
            Walk-in Cashier Checkout
          </h1>
          <p className="font-body-sm text-on-surface-variant mt-0.5">
            Select items from the live canteen menu and process cash / card / UPI transactions.
          </p>
        </div>

        <Link
          to="/orders"
          className="px-md py-xs bg-surface-container hover:bg-surface-container-high text-on-surface rounded-lg font-body-sm font-medium transition-colors self-start sm:self-auto flex items-center gap-xs border border-outline-variant/30 shadow-sm"
        >
          <span className="material-symbols-outlined text-[18px]">close</span>
          <span>Cancel</span>
        </Link>
      </div>

      {error && <Alert type="error" message={error} onClose={() => setError(null)} />}

      {/* ── Main Grid: Left Menu (7 cols) · Right Cart (5 cols) ─────────── */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-md items-start">

        {/* ── LEFT: Menu Catalog ────────────────────────────────────────── */}
        <div className="lg:col-span-7 space-y-sm">

          {/* ── Search Bar (universal — searches across ALL categories) ── */}
          <div className="bg-surface-container-lowest rounded-xl border border-outline-variant/20 shadow-sm px-sm py-xs flex items-center gap-sm">
            <span className="material-symbols-outlined text-on-surface-variant text-[18px] shrink-0">search</span>
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search all menu items…"
              className="flex-1 bg-transparent font-body-sm text-on-surface placeholder:text-on-surface-variant focus:outline-none text-[13px]"
            />
            {search && (
              <button
                onClick={() => setSearch('')}
                className="text-on-surface-variant hover:text-on-surface transition-colors shrink-0"
                title="Clear search"
              >
                <span className="material-symbols-outlined text-[16px]">close</span>
              </button>
            )}
          </div>

          {/* ── Category Filter Chips ─────────────────────────────────── */}
          <div className="bg-surface-container-lowest rounded-xl border border-outline-variant/20 shadow-sm px-sm py-xs flex items-center gap-xs overflow-x-auto scrollbar-hide">
            <span className="font-label-caps text-on-surface-variant text-[10px] uppercase tracking-wider shrink-0 mr-xs">
              Category
            </span>
            {categories.map((cat) => {
              const isActive = selectedCategory === cat;
              return (
                <button
                  key={cat}
                  onClick={() => setSelectedCategory(cat)}
                  className={`px-sm py-1 rounded-full font-body-sm font-medium whitespace-nowrap transition-all capitalize text-[12px] ${
                    isActive
                      ? 'bg-primary text-on-primary shadow-sm'
                      : 'bg-surface-container text-on-surface-variant hover:bg-surface-variant/40'
                  }`}
                >
                  {cat}
                </button>
              );
            })}
          </div>

          {/* ── Result count (only when a filter is active) ───────────── */}
          {(search.trim() || selectedCategory !== 'all') && !isLoadingMenu && (
            <p className="font-body-sm text-on-surface-variant text-[12px] px-xs">
              {filteredMenu.length === 0
                ? 'No items match the current filters.'
                : `${filteredMenu.length} item${filteredMenu.length !== 1 ? 's' : ''} found`}
              {search.trim() && (
                <span className="ml-xs">
                  for <span className="font-semibold text-on-surface">"{search.trim()}"</span>
                </span>
              )}
              {selectedCategory !== 'all' && (
                <span className="ml-xs">
                  in <span className="font-semibold text-on-surface capitalize">{selectedCategory}</span>
                </span>
              )}
            </p>
          )}

          {/* Menu Items Grid */}
          {isLoadingMenu ? (
            <LoadingSpinner text="Loading fresh canteen menu..." />
          ) : filteredMenu.length === 0 ? (
            <EmptyState
              icon="restaurant_menu"
              title="No items found"
              description="No menu items matched your category or search query."
            />
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-sm">
              {filteredMenu.map((item) => {
                const menuId = item.menu_id || item.id;
                const isAvailable = Boolean(item.is_available);
                const cartQty = cart.find((ci) => ci.menu_id === menuId)?.quantity || 0;

                return (
                  <div
                    key={menuId}
                    className={`bg-surface-container-lowest rounded-xl border shadow-sm flex flex-col transition-all ${
                      isAvailable
                        ? 'border-outline-variant/20 hover:border-primary/40 hover:shadow-md'
                        : 'border-outline-variant/10 opacity-55 bg-surface-container-low'
                    }`}
                  >
                    {/* Compact image row */}
                    <div className="h-20 w-full rounded-t-xl overflow-hidden bg-surface-container relative shrink-0">
                      {item.image_url ? (
                        <img
                          src={item.image_url}
                          alt={item.name}
                          className="w-full h-full object-cover"
                        />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center text-outline">
                          <span className="material-symbols-outlined text-[28px]">lunch_dining</span>
                        </div>
                      )}
                      {/* Availability badge */}
                      <div className="absolute top-1.5 right-1.5">
                        <StatusBadge
                          status={isAvailable ? 'available' : 'unavailable'}
                          size="xs"
                        />
                      </div>
                      {/* Category tag */}
                      <span className="absolute bottom-1.5 left-1.5 px-1.5 py-0.5 rounded font-label-caps text-[9px] uppercase bg-inverse-surface/75 text-inverse-on-surface font-semibold">
                        {item.category}
                      </span>
                    </div>

                    {/* Card body */}
                    <div className="p-sm flex flex-col gap-xs flex-1">
                      {/* Name */}
                      <div className="font-semibold text-on-surface text-[13px] leading-tight line-clamp-1">
                        {item.name}
                      </div>
                      {/* Description (optional) */}
                      {item.description && (
                        <p className="font-body-sm text-on-surface-variant text-[11px] line-clamp-1">
                          {item.description}
                        </p>
                      )}

                      {/* Price + Action row */}
                      <div className="flex items-center justify-between mt-auto pt-xs border-t border-outline-variant/10">
                        <span className="font-data-mono font-bold text-primary text-[15px]">
                          ₹{Number(item.price || 0)}
                        </span>

                        {isAvailable ? (
                          cartQty > 0 ? (
                            <div className="flex items-center gap-xs bg-primary/10 rounded-lg p-0.5">
                              <button
                                onClick={() => updateQuantity(menuId, -1)}
                                className="w-6 h-6 rounded bg-surface-container-lowest text-primary hover:bg-surface-variant font-bold flex items-center justify-center transition-colors text-[14px]"
                              >
                                −
                              </button>
                              <span className="font-data-mono font-bold text-primary px-1 text-[13px] min-w-[16px] text-center">
                                {cartQty}
                              </span>
                              <button
                                onClick={() => updateQuantity(menuId, 1)}
                                className="w-6 h-6 rounded bg-primary text-on-primary hover:opacity-90 font-bold flex items-center justify-center transition-colors text-[14px]"
                              >
                                +
                              </button>
                            </div>
                          ) : (
                            <button
                              onClick={() => addToCart(item)}
                              className="px-sm py-1 bg-primary text-on-primary rounded-lg font-body-sm font-semibold hover:opacity-90 transition-all flex items-center gap-xs text-[12px] shadow-sm"
                            >
                              <span className="material-symbols-outlined text-[14px]">add</span>
                              <span>Add</span>
                            </button>
                          )
                        ) : (
                          <span className="font-label-caps text-error text-[10px] uppercase font-semibold">
                            Unavailable
                          </span>
                        )}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* ── RIGHT: Cart / POS Transaction Panel ──────────────────────── */}
        <div className="lg:col-span-5 sticky top-20">
          <div className="bg-surface-container-lowest rounded-xl shadow-md border border-outline-variant/30 overflow-hidden flex flex-col max-h-[calc(100vh-110px)]">

            {/* Cart Header */}
            <div className="px-md py-sm bg-surface-container-low border-b border-outline-variant/20 flex items-center justify-between shrink-0">
              <div className="flex items-center gap-xs">
                <div className="w-7 h-7 rounded-lg bg-primary/10 text-primary flex items-center justify-center">
                  <span className="material-symbols-outlined text-[18px]">point_of_sale</span>
                </div>
                <div>
                  <h2 className="font-title-sm text-on-surface leading-tight">Walk-in Order</h2>
                  <p className="font-label-caps text-on-surface-variant text-[10px] uppercase tracking-wider">
                    Cashier POS Terminal
                  </p>
                </div>
              </div>

              {cart.length > 0 && (
                <button
                  onClick={clearCart}
                  className="text-error font-body-sm text-[11px] hover:underline"
                >
                  Clear
                </button>
              )}
            </div>

            {/* Cart Items */}
            <div className="px-md py-sm overflow-y-auto flex-1 divide-y divide-outline-variant/10">
              {cart.length === 0 ? (
                /* Compact empty state */
                <div className="py-lg text-center text-on-surface-variant flex flex-col items-center gap-xs">
                  <span className="material-symbols-outlined text-[32px] opacity-25">
                    shopping_basket
                  </span>
                  <p className="font-title-sm text-on-surface text-[13px]">Cart is Empty</p>
                  <p className="font-body-sm text-on-surface-variant text-[12px] max-w-[200px]">
                    Click "Add" on any available menu item to start building the order.
                  </p>
                </div>
              ) : (
                cart.map((ci) => {
                  const lineTotal = ci.price * ci.quantity;

                  return (
                    <div key={ci.menu_id} className="py-sm first:pt-0 flex items-center gap-sm">
                      {/* Item info */}
                      <div className="flex-1 min-w-0">
                        <div className="font-semibold text-on-surface text-[13px] truncate leading-tight">
                          {ci.name}
                        </div>
                        <div className="flex items-center gap-xs mt-0.5">
                          <span className="font-label-caps uppercase text-[9px] bg-surface-container px-1 py-0.5 rounded text-on-surface-variant">
                            {ci.category}
                          </span>
                          <span className="text-on-surface-variant text-[10px]">·</span>
                          <span className="font-data-mono text-on-surface-variant text-[11px]">
                            ₹{ci.price} ea
                          </span>
                        </div>
                      </div>

                      {/* Qty controls */}
                      <div className="flex items-center gap-xs bg-surface-container rounded-lg p-0.5 shrink-0">
                        <button
                          onClick={() => updateQuantity(ci.menu_id, -1)}
                          className="w-5 h-5 rounded bg-surface-container-lowest text-on-surface hover:bg-surface-variant flex items-center justify-center font-bold text-[12px]"
                        >
                          −
                        </button>
                        <span className="font-data-mono font-bold text-on-surface text-[12px] min-w-[18px] text-center">
                          {ci.quantity}
                        </span>
                        <button
                          onClick={() => updateQuantity(ci.menu_id, 1)}
                          className="w-5 h-5 rounded bg-primary text-on-primary hover:opacity-90 flex items-center justify-center font-bold text-[12px]"
                        >
                          +
                        </button>
                      </div>

                      {/* Line total */}
                      <div className="font-data-mono font-bold text-on-surface text-[13px] text-right min-w-[52px] shrink-0">
                        ₹{lineTotal}
                      </div>

                      {/* Remove */}
                      <button
                        onClick={() => removeFromCart(ci.menu_id)}
                        className="text-on-surface-variant hover:text-error p-0.5 rounded transition-colors shrink-0"
                        title="Remove item"
                      >
                        <span className="material-symbols-outlined text-[16px]">delete</span>
                      </button>
                    </div>
                  );
                })
              )}
            </div>

            {/* Checkout Footer — only shown when cart has items */}
            {cart.length > 0 && (
              <div className="px-md py-sm bg-surface-container-low border-t border-outline-variant/20 space-y-sm shrink-0">

                {/* Payment Method */}
                <div>
                  <label className="block font-label-caps text-on-surface-variant uppercase text-[10px] mb-xs tracking-wider">
                    Payment Method
                  </label>
                  <div className="grid grid-cols-3 gap-xs">
                    <button
                      type="button"
                      onClick={() => setPaymentMethod('cash')}
                      className={`py-xs px-sm rounded-lg font-body-sm font-semibold flex items-center justify-center gap-xs border transition-all text-[12px] ${
                        paymentMethod === 'cash'
                          ? 'bg-primary text-on-primary border-primary shadow-sm'
                          : 'bg-surface-container text-on-surface border-outline-variant/30 hover:bg-surface-container-high'
                      }`}
                    >
                      <span className="material-symbols-outlined text-[16px]">payments</span>
                      <span>Cash</span>
                    </button>

                    <button
                      type="button"
                      onClick={() => setPaymentMethod('card')}
                      className={`py-xs px-sm rounded-lg font-body-sm font-semibold flex items-center justify-center gap-xs border transition-all text-[12px] ${
                        paymentMethod === 'card'
                          ? 'bg-primary text-on-primary border-primary shadow-sm'
                          : 'bg-surface-container text-on-surface border-outline-variant/30 hover:bg-surface-container-high'
                      }`}
                    >
                      <span className="material-symbols-outlined text-[16px]">credit_card</span>
                      <span>Card</span>
                    </button>

                    <button
                      type="button"
                      onClick={() => setPaymentMethod('upi')}
                      className={`py-xs px-sm rounded-lg font-body-sm font-semibold flex items-center justify-center gap-xs border transition-all text-[12px] ${
                        paymentMethod === 'upi'
                          ? 'bg-primary text-on-primary border-primary shadow-sm'
                          : 'bg-surface-container text-on-surface border-outline-variant/30 hover:bg-surface-container-high'
                      }`}
                    >
                      <span className="material-symbols-outlined text-[16px]">qr_code_scanner</span>
                      <span>UPI</span>
                    </button>
                  </div>
                </div>

                {/* Order summary */}
                <div className="space-y-xs border-t border-outline-variant/20 pt-xs">
                  <div className="flex justify-between text-[12px] text-on-surface-variant">
                    <span>Total items</span>
                    <span className="font-data-mono font-medium text-on-surface">
                      {totalItemsCount}
                    </span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="font-semibold text-on-surface text-[13px]">Payable Total</span>
                    <span className="font-data-mono font-bold text-primary text-[22px]">
                      ₹{totalAmount}
                    </span>
                  </div>
                </div>

                {/* Place Order */}
                <button
                  type="button"
                  onClick={handlePlaceOrder}
                  disabled={isSubmitting}
                  className="w-full py-sm bg-primary text-on-primary rounded-lg font-title-sm font-bold hover:opacity-90 shadow-sm active:scale-[0.99] transition-all flex items-center justify-center gap-xs disabled:opacity-50 text-[13px]"
                >
                  {isSubmitting ? (
                    <>
                      <span className="material-symbols-outlined animate-spin text-[18px]">refresh</span>
                      <span>Submitting…</span>
                    </>
                  ) : (
                    <>
                      <span className="material-symbols-outlined text-[18px]">check_circle</span>
                      <span>Confirm & Place Order — ₹{totalAmount}</span>
                    </>
                  )}
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
