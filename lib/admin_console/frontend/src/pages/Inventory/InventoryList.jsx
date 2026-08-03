import React, { useState, useEffect } from 'react';
import { listInventory, createMenuItem, updateMenuItem } from '../../api/inventory';
import { getErrorMessage } from '../../api/client';
import { Alert, LoadingSpinner, EmptyState } from '../../components/common/Feedback';
import StatusBadge from '../../components/common/StatusBadge';
import Modal from '../../components/common/Modal';

export default function InventoryList() {
  const [items, setItems] = useState([]);
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [search, setSearch] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);
  const [successMsg, setSuccessMsg] = useState(null);

  // Modals
  const [viewModalItem, setViewModalItem] = useState(null);
  const [editModalItem, setEditModalItem] = useState(null);
  const [isCreateOpen, setIsCreateOpen] = useState(false);

  // Form states
  const [formData, setFormData] = useState({
    name: '',
    category: 'mess',
    price: '',
    stock: '',
    is_available: true,
    description: '',
    image_url: '',
  });
  const [isSubmitting, setIsSubmitting] = useState(false);

  const fetchItems = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const data = await listInventory();
      setItems(Array.isArray(data) ? data : []);
    } catch (err) {
      setError(getErrorMessage(err, 'Failed to fetch inventory catalog.'));
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchItems();
  }, []);

  const categories = [
    'all',
    ...new Set(
      items.map((item) => (item.category || 'other').toLowerCase()).filter(Boolean)
    ),
  ];

  const filteredItems = items.filter((item) => {
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

  const handleOpenCreate = () => {
    setFormData({
      name: '',
      category: 'mess',
      price: '',
      stock: '',
      is_available: true,
      description: '',
      image_url: '',
    });
    setIsCreateOpen(true);
  };

  const handleOpenEdit = (item) => {
    setEditModalItem(item);
    setFormData({
      name: item.name || '',
      category: item.category || 'mess',
      price: item.price !== undefined && item.price !== null ? String(item.price) : '',
      stock: item.stock !== undefined && item.stock !== null ? String(item.stock) : '',
      is_available: Boolean(item.is_available),
      description: item.description || '',
      image_url: item.image_url || '',
    });
  };

  const handleCreateSubmit = async (e) => {
    e.preventDefault();
    setIsSubmitting(true);
    setError(null);
    setSuccessMsg(null);

    try {
      const intPrice = parseInt(formData.price, 10);
      if (isNaN(intPrice) || intPrice <= 0) {
        throw new Error('Price must be a positive whole integer (in rupees).');
      }

      const payload = {
        name: formData.name.trim(),
        category: formData.category.toLowerCase().trim(),
        price: intPrice,
        is_available: Boolean(formData.is_available),
      };

      if (formData.stock.trim() !== '') {
        const intStock = parseInt(formData.stock, 10);
        if (!isNaN(intStock) && intStock >= 0) {
          payload.stock = intStock;
        }
      }

      if (formData.description.trim()) {
        payload.description = formData.description.trim();
      }
      if (formData.image_url.trim()) {
        payload.image_url = formData.image_url.trim();
      }

      await createMenuItem(payload);
      setSuccessMsg(`Created item "${formData.name}" successfully.`);
      setIsCreateOpen(false);
      await fetchItems();
    } catch (err) {
      setError(getErrorMessage(err, 'Failed to create menu item.'));
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleEditSubmit = async (e) => {
    e.preventDefault();
    if (!editModalItem) return;
    setIsSubmitting(true);
    setError(null);
    setSuccessMsg(null);

    try {
      const menuId = editModalItem.menu_id || editModalItem.id;
      const payload = {};

      if (formData.price.trim() !== '') {
        const intPrice = parseInt(formData.price, 10);
        if (!isNaN(intPrice) && intPrice > 0 && intPrice !== editModalItem.price) {
          payload.price = intPrice;
        }
      }

      if (formData.stock.trim() !== '') {
        const intStock = parseInt(formData.stock, 10);
        if (!isNaN(intStock) && intStock >= 0 && intStock !== editModalItem.stock) {
          payload.stock = intStock;
        }
      } else if (editModalItem.stock !== null && editModalItem.stock !== undefined) {
        payload.stock = null;
      }

      if (Boolean(formData.is_available) !== Boolean(editModalItem.is_available)) {
        payload.is_available = Boolean(formData.is_available);
      }

      if (formData.description.trim() !== (editModalItem.description || '')) {
        payload.description = formData.description.trim() || null;
      }

      if (formData.image_url.trim() !== (editModalItem.image_url || '')) {
        payload.image_url = formData.image_url.trim() || null;
      }

      await updateMenuItem(menuId, payload);
      setSuccessMsg(`Updated item "${editModalItem.name || menuId}" successfully.`);
      setEditModalItem(null);
      await fetchItems();
    } catch (err) {
      setError(getErrorMessage(err, 'Failed to update menu item.'));
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleToggleStock = async (item) => {
    const menuId = item.menu_id || item.id;
    try {
      await updateMenuItem(menuId, { is_available: !item.is_available });
      setItems((prev) =>
        prev.map((it) =>
          (it.menu_id || it.id) === menuId ? { ...it, is_available: !it.is_available } : it
        )
      );
    } catch (err) {
      setError(getErrorMessage(err, 'Failed to toggle availability status.'));
    }
  };

  return (
    <div className="p-lg md:p-xl space-y-xl max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-md">
        <div>
          <h1 className="font-headline-md text-headline-md text-on-surface">Menu Inventory</h1>
          <p className="font-body-md text-on-surface-variant mt-xs">
            Manage canteen dishes, live pricing, stock availability, and categories.
          </p>
        </div>

        <div className="flex items-center gap-sm">
          <button
            onClick={fetchItems}
            disabled={isLoading}
            className="p-sm bg-surface-container-low hover:bg-surface-container text-on-surface rounded-lg border border-outline-variant/30 transition-colors shadow-sm"
            title="Refresh Inventory"
          >
            <span className={`material-symbols-outlined text-[20px] ${isLoading ? 'animate-spin' : ''}`}>
              refresh
            </span>
          </button>

          <button
            onClick={handleOpenCreate}
            className="px-md py-sm bg-primary text-on-primary rounded-xl font-body-sm font-semibold hover:bg-primary-container shadow-sm flex items-center gap-xs transition-all"
          >
            <span className="material-symbols-outlined text-[20px]">add</span>
            <span>Add Menu Item</span>
          </button>
        </div>
      </div>

      {successMsg && (
        <Alert type="success" message={successMsg} onClose={() => setSuccessMsg(null)} />
      )}
      {error && <Alert type="error" message={error} onClose={() => setError(null)} />}

      {/* Categories & Search Filter Bar */}
      <div className="bg-surface-container-lowest p-md rounded-2xl shadow-sm border border-outline-variant/20 flex flex-col md:flex-row items-center justify-between gap-md">
        {/* Category Tabs */}
        <div className="flex items-center gap-xs overflow-x-auto w-full md:w-auto pb-1 md:pb-0 scrollbar-hide">
          {categories.map((cat) => {
            const isActive = selectedCategory === cat;
            return (
              <button
                key={cat}
                onClick={() => setSelectedCategory(cat)}
                className={`px-md py-xs rounded-full font-body-sm font-medium whitespace-nowrap transition-all capitalize ${
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

        {/* Search Bar */}
        <div className="relative w-full md:w-72">
          <span className="material-symbols-outlined absolute left-md top-1/2 -translate-y-1/2 text-outline text-[18px]">
            search
          </span>
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search items..."
            className="w-full pl-[38px] pr-md py-xs bg-surface-container border border-outline-variant/30 rounded-lg font-body-sm text-on-surface focus:outline-none focus:ring-2 focus:ring-primary focus:bg-surface-container-lowest"
          />
        </div>
      </div>

      {/* Inventory Grid / Table */}
      <div className="bg-surface-container-lowest rounded-2xl shadow-sm border border-outline-variant/20 overflow-hidden">
        {isLoading ? (
          <LoadingSpinner text="Fetching inventory catalog..." />
        ) : filteredItems.length === 0 ? (
          <EmptyState
            icon="lunch_dining"
            title="No items found"
            description="No menu items matched your current filter criteria."
            action={
              <button
                onClick={handleOpenCreate}
                className="px-md py-xs bg-primary text-on-primary rounded-lg font-body-sm"
              >
                Create Item Now
              </button>
            }
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left font-body-md border-collapse">
              <thead>
                <tr className="bg-surface-container-low text-on-surface-variant font-label-caps text-label-caps uppercase tracking-wider border-b border-outline-variant/20">
                  <th className="p-table-cell-padding">Item</th>
                  <th className="p-table-cell-padding">Category</th>
                  <th className="p-table-cell-padding text-right">Price</th>
                  <th className="p-table-cell-padding text-center">Stock</th>
                  <th className="p-table-cell-padding">Status</th>
                  <th className="p-table-cell-padding text-center">Toggle Stock</th>
                  <th className="p-table-cell-padding text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-outline-variant/10">
                {filteredItems.map((item) => {
                  const menuId = item.menu_id || item.id;
                  const price = Number(item.price || 0);
                  const isAvailable = Boolean(item.is_available);
                  const stock = item.stock;

                  return (
                    <tr
                      key={menuId}
                      className="hover:bg-surface-container-low/50 transition-colors group"
                    >
                      <td className="p-table-cell-padding">
                        <div className="flex items-center gap-md">
                          <div className="w-12 h-12 rounded-xl bg-surface-container overflow-hidden flex-shrink-0 flex items-center justify-center border border-outline-variant/20">
                            {item.image_url ? (
                              <img
                                src={item.image_url}
                                alt={item.name}
                                className="w-full h-full object-cover"
                              />
                            ) : (
                              <span className="material-symbols-outlined text-outline text-[22px]">
                                lunch_dining
                              </span>
                            )}
                          </div>
                          <div>
                            <div className="font-semibold text-on-surface">{item.name}</div>
                            {item.description && (
                              <div className="font-body-sm text-on-surface-variant text-[12px] truncate max-w-xs">
                                {item.description}
                              </div>
                            )}
                            <div className="font-data-mono text-[10px] text-outline">
                              ID: {menuId}
                            </div>
                          </div>
                        </div>
                      </td>

                      <td className="p-table-cell-padding">
                        <span className="font-label-caps text-[11px] uppercase bg-surface-container text-on-surface-variant px-2 py-0.5 rounded font-medium">
                          {item.category || 'general'}
                        </span>
                      </td>

                      <td className="p-table-cell-padding text-right font-data-mono font-bold text-headline-md text-on-surface">
                        ₹{price}
                      </td>

                      <td className="p-table-cell-padding text-center font-data-mono text-body-sm">
                        {stock !== null && stock !== undefined ? (
                          <span className={`font-semibold ${stock <= 5 ? 'text-error' : 'text-on-surface'}`}>
                            {stock}
                          </span>
                        ) : (
                          <span className="text-on-surface-variant italic text-[12px]">Unlimited</span>
                        )}
                      </td>

                      <td className="p-table-cell-padding">
                        <StatusBadge
                          status={isAvailable ? 'available' : 'unavailable'}
                          size="xs"
                        />
                      </td>

                      <td className="p-table-cell-padding text-center">
                        <button
                          type="button"
                          onClick={() => handleToggleStock(item)}
                          className={`relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none ${
                            isAvailable ? 'bg-tertiary-container' : 'bg-surface-variant'
                          }`}
                        >
                          <span
                            className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                              isAvailable ? 'translate-x-5' : 'translate-x-0'
                            }`}
                          />
                        </button>
                      </td>

                      <td className="p-table-cell-padding text-right">
                        <div className="flex items-center justify-end gap-xs">
                          <button
                            onClick={() => setViewModalItem(item)}
                            className="p-1 rounded text-on-surface-variant hover:text-primary hover:bg-surface-container transition-colors"
                            title="View details"
                          >
                            <span className="material-symbols-outlined text-[18px]">
                              visibility
                            </span>
                          </button>

                          <button
                            onClick={() => handleOpenEdit(item)}
                            className="p-1 rounded text-on-surface-variant hover:text-primary hover:bg-surface-container transition-colors"
                            title="Edit item"
                          >
                            <span className="material-symbols-outlined text-[18px]">
                              edit
                            </span>
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* View Item Modal */}
      <Modal
        isOpen={Boolean(viewModalItem)}
        onClose={() => setViewModalItem(null)}
        title="Item Details"
      >
        {viewModalItem && (
          <div className="space-y-md">
            <div className="h-44 rounded-xl bg-surface-container overflow-hidden flex items-center justify-center border">
              {viewModalItem.image_url ? (
                <img
                  src={viewModalItem.image_url}
                  alt={viewModalItem.name}
                  className="w-full h-full object-cover"
                />
              ) : (
                <span className="material-symbols-outlined text-[48px] text-outline">
                  lunch_dining
                </span>
              )}
            </div>

            <div className="space-y-xs">
              <div className="flex items-center justify-between">
                <h3 className="font-title-sm text-on-surface">{viewModalItem.name}</h3>
                <StatusBadge
                  status={viewModalItem.is_available ? 'available' : 'unavailable'}
                />
              </div>
              <p className="font-body-md text-on-surface-variant">
                {viewModalItem.description || 'No description provided.'}
              </p>
            </div>

            <div className="grid grid-cols-2 gap-sm py-sm border-t border-b border-outline-variant/20 text-body-sm">
              <div>
                <span className="text-on-surface-variant">Category:</span>{' '}
                <span className="font-semibold capitalize text-on-surface">
                  {viewModalItem.category}
                </span>
              </div>
              <div>
                <span className="text-on-surface-variant">Price:</span>{' '}
                <span className="font-data-mono font-bold text-primary">
                  ₹{Number(viewModalItem.price || 0)}
                </span>
              </div>
              <div>
                <span className="text-on-surface-variant">Stock Level:</span>{' '}
                <span className="font-data-mono font-medium text-on-surface">
                  {viewModalItem.stock !== null && viewModalItem.stock !== undefined
                    ? `${viewModalItem.stock} units`
                    : 'Unlimited'}
                </span>
              </div>
              <div>
                <span className="text-on-surface-variant">Menu ID:</span>{' '}
                <span className="font-data-mono text-outline">
                  {viewModalItem.menu_id || viewModalItem.id}
                </span>
              </div>
            </div>

            <div className="flex justify-end gap-sm pt-sm">
              <button
                onClick={() => {
                  const it = viewModalItem;
                  setViewModalItem(null);
                  handleOpenEdit(it);
                }}
                className="px-md py-xs bg-primary text-on-primary rounded-lg font-body-sm font-semibold"
              >
                Edit Item
              </button>
            </div>
          </div>
        )}
      </Modal>

      {/* Create / Edit Item Modal */}
      <Modal
        isOpen={isCreateOpen || Boolean(editModalItem)}
        onClose={() => {
          setIsCreateOpen(false);
          setEditModalItem(null);
        }}
        title={isCreateOpen ? 'Add New Menu Item' : `Edit Item: ${editModalItem?.name || ''}`}
      >
        <form onSubmit={isCreateOpen ? handleCreateSubmit : handleEditSubmit} className="space-y-md">
          {isCreateOpen && (
            <div>
              <label className="block font-label-caps text-on-surface uppercase text-[11px] mb-xs">
                Item Name *
              </label>
              <input
                type="text"
                required
                maxLength={100}
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                placeholder="e.g. Masala Dosa"
                className="w-full p-sm bg-surface-container border border-outline-variant/50 rounded-xl font-body-md text-on-surface focus:outline-none focus:ring-2 focus:ring-primary"
              />
            </div>
          )}

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-md">
            {isCreateOpen && (
              <div>
                <label className="block font-label-caps text-on-surface uppercase text-[11px] mb-xs">
                  Category *
                </label>
                <select
                  required
                  value={formData.category}
                  onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                  className="w-full p-sm bg-surface-container border border-outline-variant/50 rounded-xl font-body-md text-on-surface focus:outline-none focus:ring-2 focus:ring-primary cursor-pointer capitalize"
                >
                  <option value="mess">Mess</option>
                  <option value="bakery">Bakery</option>
                  <option value="beverages">Beverages</option>
                  <option value="continental">Continental</option>
                </select>
              </div>
            )}

            <div>
              <label className="block font-label-caps text-on-surface uppercase text-[11px] mb-xs">
                Price (₹ whole rupees) *
              </label>
              <input
                type="number"
                step="1"
                min="1"
                required={isCreateOpen}
                value={formData.price}
                onChange={(e) => setFormData({ ...formData, price: e.target.value })}
                placeholder="40"
                className="w-full p-sm bg-surface-container border border-outline-variant/50 rounded-xl font-data-mono text-on-surface focus:outline-none focus:ring-2 focus:ring-primary"
              />
            </div>

            <div>
              <label className="block font-label-caps text-on-surface uppercase text-[11px] mb-xs">
                Stock (units, optional)
              </label>
              <input
                type="number"
                step="1"
                min="0"
                value={formData.stock}
                onChange={(e) => setFormData({ ...formData, stock: e.target.value })}
                placeholder="Leave blank for unlimited"
                className="w-full p-sm bg-surface-container border border-outline-variant/50 rounded-xl font-data-mono text-on-surface focus:outline-none focus:ring-2 focus:ring-primary"
              />
            </div>
          </div>

          <div>
            <label className="block font-label-caps text-on-surface uppercase text-[11px] mb-xs">
              Image URL (Optional)
            </label>
            <input
              type="url"
              value={formData.image_url}
              onChange={(e) => setFormData({ ...formData, image_url: e.target.value })}
              placeholder="https://images.unsplash.com/..."
              className="w-full p-sm bg-surface-container border border-outline-variant/50 rounded-xl font-body-md text-on-surface focus:outline-none focus:ring-2 focus:ring-primary"
            />
          </div>

          <div>
            <label className="block font-label-caps text-on-surface uppercase text-[11px] mb-xs">
              Description (Optional)
            </label>
            <textarea
              rows={3}
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              placeholder="Crispy fermented rice pancake served with sambar and coconut chutney..."
              className="w-full p-sm bg-surface-container border border-outline-variant/50 rounded-xl font-body-md text-on-surface focus:outline-none focus:ring-2 focus:ring-primary resize-none"
            />
          </div>

          <div className="flex items-center gap-sm pt-xs">
            <input
              id="is_available"
              type="checkbox"
              checked={formData.is_available}
              onChange={(e) => setFormData({ ...formData, is_available: e.target.checked })}
              className="w-5 h-5 rounded text-primary focus:ring-primary cursor-pointer"
            />
            <label htmlFor="is_available" className="font-body-md text-on-surface cursor-pointer select-none">
              Item is currently available in stock
            </label>
          </div>

          <div className="flex justify-end gap-sm pt-md border-t border-outline-variant/20">
            <button
              type="button"
              onClick={() => {
                setIsCreateOpen(false);
                setEditModalItem(null);
              }}
              className="px-md py-xs rounded-xl font-body-sm font-medium text-on-surface bg-surface-container hover:bg-surface-container-high transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className="px-md py-xs rounded-xl font-body-sm font-semibold text-on-primary bg-primary hover:bg-primary-container transition-all flex items-center gap-xs disabled:opacity-50"
            >
              {isSubmitting ? (
                <>
                  <span className="material-symbols-outlined animate-spin text-[16px]">
                    refresh
                  </span>
                  <span>Saving...</span>
                </>
              ) : (
                <span>{isCreateOpen ? 'Create Item' : 'Save Changes'}</span>
              )}
            </button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
