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
    <div className="p-lg md:p-xl max-w-7xl mx-auto space-y-lg">
      {/* Header Bar */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-md">
        <div>
          <div className="flex items-center gap-xs text-on-surface-variant font-body-sm mb-xs">
            <Link to="/orders" className="hover:text-primary transition-colors">Orders</Link>
            <span className="material-symbols-outlined text-[14px]">chevron_right</span>
            <span className="text-on-surface font-medium">Create Manual Order</span>
          </div>
          <h1 className="font-headline-md text-headline-md text-on-surface">Walk-in Cashier Checkout</h1>
          <p className="font-body-md text-on-surface-variant mt-xs">
            Select items from live canteen menu and process cash/card/UPI transactions.
          </p>
        </div>

        <Link
          to="/orders"
          className="px-md py-sm bg-surface-container hover:bg-surface-container-high text-on-surface rounded-xl font-body-sm font-medium transition-colors self-start sm:self-auto flex items-center gap-xs"
        >
          <span className="material-symbols-outlined text-[18px]">close</span>
          <span>Cancel</span>
        </Link>
      </div>

      {error && <Alert type="error" message={error} onClose={() => setError(null)} />}

      {/* Main Grid: Left Menu catalog (7 cols), Right Cart Checkout (5 cols) */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-lg items-start">
        {/* Left Side: Dynamic Menu (7 cols) */}
        <div className="lg:col-span-7 space-y-md">
          {/* Categories & Search Bar */}
          <div className="bg-surface-container-lowest p-md rounded-2xl shadow-sm border border-outline-variant/20 flex flex-col sm:flex-row items-center justify-between gap-sm">
            {/* Category tabs */}
            <div className="flex items-center gap-xs overflow-x-auto w-full sm:w-auto pb-1 sm:pb-0 scrollbar-hide">
              {categories.map((cat) => {
                const isActive = selectedCategory === cat;
                return (
                  <button
                    key={cat}
                    onClick={() => setSelectedCategory(cat)}
                    className={`px-md py-xs rounded-full font-body-sm font-medium whitespace-nowrap transition-all capitalize ${
                      isActive
                        ? 'bg-primary text-on-primary shadow-sm'
                        : 'bg-surface-container text-on-surface-variant hover:bg-surface-variant/30'
                    }`}
                  >
                    {cat}
                  </button>
                );
              })}
            </div>

            {/* Search Input */}
            <div className="relative w-full sm:w-56">
              <span className="material-symbols-outlined absolute left-md top-1/2 -translate-y-1/2 text-on-surface-variant text-[18px]">
                search
              </span>
              <input
                type="text"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Search food..."
                className="w-full pl-[38px] pr-md py-xs bg-surface-container border border-outline-variant/30 rounded-lg font-body-sm text-on-surface focus:outline-none focus:ring-2 focus:ring-primary focus:bg-surface-container-lowest"
              />
            </div>
          </div>

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
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-md">
              {filteredMenu.map((item) => {
                const menuId = item.menu_id || item.id;
                const isAvailable = Boolean(item.is_available);
                const cartQty = cart.find((ci) => ci.menu_id === menuId)?.quantity || 0;

                return (
                  <div
                    key={menuId}
                    className={`bg-surface-container-lowest rounded-2xl p-md border shadow-sm flex flex-col justify-between transition-all ${
                      isAvailable
                        ? 'border-outline-variant/20 hover:border-primary/50 hover:shadow-md'
                        : 'border-outline-variant/10 opacity-60 bg-surface-container-low'
                    }`}
                  >
                    <div className="space-y-sm">
                      {/* Image Thumbnail */}
                      <div className="h-32 w-full rounded-xl overflow-hidden bg-surface-container relative">
                        {item.image_url ? (
                          <img
                            src={item.image_url}
                            alt={item.name}
                            className="w-full h-full object-cover"
                          />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center text-outline">
                            <span className="material-symbols-outlined text-[36px]">lunch_dining</span>
                          </div>
                        )}

                        <div className="absolute top-2 right-2">
                          <StatusBadge
                            status={isAvailable ? 'available' : 'unavailable'}
                            size="xs"
                          />
                        </div>

                        <span className="absolute bottom-2 left-2 px-2 py-0.5 rounded-full font-label-caps text-[10px] uppercase bg-inverse-surface/80 text-inverse-on-surface font-semibold backdrop-blur-sm">
                          {item.category}
                        </span>
                      </div>

                      {/* Title & Description */}
                      <div>
                        <h3 className="font-title-sm text-on-surface">{item.name}</h3>
                        {item.description && (
                          <p className="font-body-sm text-on-surface-variant text-[12px] line-clamp-2 mt-0.5">
                            {item.description}
                          </p>
                        )}
                      </div>
                    </div>

                    {/* Price & Add to Cart */}
                    <div className="pt-md mt-sm border-t border-outline-variant/10 flex items-center justify-between">
                      <div className="font-data-mono font-bold text-headline-md text-primary">
                        ₹{Number(item.price || 0)}
                      </div>

                      {isAvailable ? (
                        cartQty > 0 ? (
                          <div className="flex items-center gap-xs bg-primary-fixed rounded-xl p-1">
                            <button
                              onClick={() => updateQuantity(menuId, -1)}
                              className="w-7 h-7 rounded-lg bg-surface-container-lowest text-primary hover:bg-surface-variant font-bold flex items-center justify-center transition-colors shadow-sm"
                            >
                              -
                            </button>
                            <span className="font-data-mono font-bold text-on-primary-fixed px-1.5 text-body-sm">
                              {cartQty}
                            </span>
                            <button
                              onClick={() => updateQuantity(menuId, 1)}
                              className="w-7 h-7 rounded-lg bg-primary text-on-primary hover:bg-primary-container font-bold flex items-center justify-center transition-colors shadow-sm"
                            >
                              +
                            </button>
                          </div>
                        ) : (
                          <button
                            onClick={() => addToCart(item)}
                            className="px-md py-xs bg-primary text-on-primary rounded-xl font-body-sm font-semibold hover:bg-primary-container transition-all flex items-center gap-xs shadow-sm"
                          >
                            <span className="material-symbols-outlined text-[18px]">add</span>
                            <span>Add</span>
                          </button>
                        )
                      ) : (
                        <span className="font-label-caps text-on-error-container text-[11px] uppercase font-semibold">
                          Out of Stock
                        </span>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Right Side: Cart & Checkout (5 cols) */}
        <div className="lg:col-span-5 sticky top-20">
          <div className="bg-surface-container-lowest rounded-2xl shadow-xl border border-outline-variant/30 overflow-hidden flex flex-col max-h-[calc(100vh-100px)]">
            {/* Cart Header */}
            <div className="p-lg bg-surface-container-low border-b border-outline-variant/20 flex items-center justify-between">
              <div className="flex items-center gap-sm">
                <div className="w-8 h-8 rounded-lg bg-primary/10 text-primary flex items-center justify-center">
                  <span className="material-symbols-outlined text-[20px]">shopping_cart</span>
                </div>
                <div>
                  <h2 className="font-title-sm text-on-surface">Walk-in Order</h2>
                  <p className="font-label-caps text-on-surface-variant text-[10px] uppercase tracking-wider">
                    Cashier POS Terminal
                  </p>
                </div>
              </div>

              {cart.length > 0 && (
                <button
                  onClick={clearCart}
                  className="text-error font-body-sm text-[12px] hover:underline"
                >
                  Clear Cart
                </button>
              )}
            </div>

            {/* Cart Items List */}
            <div className="p-lg overflow-y-auto flex-1 space-y-md divide-y divide-outline-variant/10">
              {cart.length === 0 ? (
                <div className="py-xl text-center text-on-surface-variant">
                  <span className="material-symbols-outlined text-[42px] opacity-30 mb-xs">
                    shopping_basket
                  </span>
                  <p className="font-title-sm text-on-surface">Cart is Empty</p>
                  <p className="font-body-sm text-on-surface-variant mt-xs">
                    Click "Add" on any available menu item to start building the order.
                  </p>
                </div>
              ) : (
                cart.map((ci) => {
                  const lineTotal = ci.price * ci.quantity;

                  return (
                    <div key={ci.menu_id} className="pt-md first:pt-0 flex items-center justify-between gap-sm">
                      <div className="flex-1 min-w-0">
                        <div className="font-semibold text-on-surface truncate">{ci.name}</div>
                        <div className="font-body-sm text-on-surface-variant text-[12px] flex items-center gap-xs">
                          <span className="font-label-caps uppercase text-[10px] bg-surface-container px-1.5 py-0.2 rounded">
                            {ci.category}
                          </span>
                          <span>•</span>
                          <span className="font-data-mono">₹{ci.price} each</span>
                        </div>
                      </div>

                      {/* Quantity Controls */}
                      <div className="flex items-center gap-xs bg-surface-container rounded-lg p-1">
                        <button
                          onClick={() => updateQuantity(ci.menu_id, -1)}
                          className="w-6 h-6 rounded bg-surface-container-lowest text-on-surface hover:bg-surface-variant flex items-center justify-center font-bold text-body-sm"
                        >
                          -
                        </button>
                        <span className="font-data-mono font-bold text-on-surface px-1 text-body-sm min-w-[20px] text-center">
                          {ci.quantity}
                        </span>
                        <button
                          onClick={() => updateQuantity(ci.menu_id, 1)}
                          className="w-6 h-6 rounded bg-primary text-on-primary hover:bg-primary-container flex items-center justify-center font-bold text-body-sm"
                        >
                          +
                        </button>
                      </div>

                      {/* Line Total */}
                      <div className="font-data-mono font-bold text-on-surface text-right min-w-[65px]">
                        ₹{lineTotal}
                      </div>

                      {/* Delete */}
                      <button
                        onClick={() => removeFromCart(ci.menu_id)}
                        className="text-on-surface-variant hover:text-error p-1 rounded transition-colors"
                        title="Remove item"
                      >
                        <span className="material-symbols-outlined text-[18px]">delete</span>
                      </button>
                    </div>
                  );
                })
              )}
            </div>

            {/* Cart Summary & Checkout Footer */}
            {cart.length > 0 && (
              <div className="p-lg bg-surface-container-low border-t border-outline-variant/20 space-y-md">
                {/* Payment Method Selector */}
                <div>
                  <label className="block font-label-caps text-on-surface-variant uppercase text-[10px] mb-xs">
                    Payment Method
                  </label>
                  <div className="grid grid-cols-3 gap-xs">
                    <button
                      type="button"
                      onClick={() => setPaymentMethod('cash')}
                      className={`p-sm rounded-xl font-body-sm font-semibold flex items-center justify-center gap-xs border transition-all ${
                        paymentMethod === 'cash'
                          ? 'bg-primary text-on-primary border-primary shadow-sm'
                          : 'bg-surface-container text-on-surface border-outline-variant/30 hover:bg-surface-container-high'
                      }`}
                    >
                      <span className="material-symbols-outlined text-[18px]">payments</span>
                      <span>Cash</span>
                    </button>

                    <button
                      type="button"
                      onClick={() => setPaymentMethod('card')}
                      className={`p-sm rounded-xl font-body-sm font-semibold flex items-center justify-center gap-xs border transition-all ${
                        paymentMethod === 'card'
                          ? 'bg-primary text-on-primary border-primary shadow-sm'
                          : 'bg-surface-container text-on-surface border-outline-variant/30 hover:bg-surface-container-high'
                      }`}
                    >
                      <span className="material-symbols-outlined text-[18px]">credit_card</span>
                      <span>Card</span>
                    </button>

                    <button
                      type="button"
                      onClick={() => setPaymentMethod('upi')}
                      className={`p-sm rounded-xl font-body-sm font-semibold flex items-center justify-center gap-xs border transition-all ${
                        paymentMethod === 'upi'
                          ? 'bg-primary text-on-primary border-primary shadow-sm'
                          : 'bg-surface-container text-on-surface border-outline-variant/30 hover:bg-surface-container-high'
                      }`}
                    >
                      <span className="material-symbols-outlined text-[18px]">qr_code_scanner</span>
                      <span>UPI</span>
                    </button>
                  </div>
                </div>

                {/* Subtotals */}
                <div className="space-y-xs text-body-sm text-on-surface-variant pt-xs border-t border-outline-variant/20">
                  <div className="flex justify-between">
                    <span>Total Quantity</span>
                    <span className="font-data-mono font-medium text-on-surface">
                      {totalItemsCount} items
                    </span>
                  </div>
                  <div className="flex justify-between items-center pt-xs">
                    <span className="font-title-sm text-on-surface">Payable Total</span>
                    <span className="font-display-lg text-[26px] font-bold text-primary font-data-mono">
                      ₹{totalAmount}
                    </span>
                  </div>
                </div>

                {/* Place Order Button */}
                <button
                  type="button"
                  onClick={handlePlaceOrder}
                  disabled={isSubmitting}
                  className="w-full py-md bg-tertiary text-on-tertiary rounded-xl font-title-sm font-bold hover:bg-tertiary-container shadow-md active:scale-[0.99] transition-all flex items-center justify-center gap-sm disabled:opacity-50"
                >
                  {isSubmitting ? (
                    <>
                      <span className="material-symbols-outlined animate-spin text-[22px]">
                        refresh
                      </span>
                      <span>Submitting Order...</span>
                    </>
                  ) : (
                    <>
                      <span className="material-symbols-outlined text-[22px]">check_circle</span>
                      <span>Confirm & Place Order (₹{totalAmount})</span>
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
