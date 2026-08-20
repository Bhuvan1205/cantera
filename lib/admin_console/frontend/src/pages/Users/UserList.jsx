import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { listUsers } from '../../api/users';
import { getErrorMessage } from '../../api/client';
import { Alert, LoadingSpinner, EmptyState } from '../../components/common/Feedback';
import StatusBadge from '../../components/common/StatusBadge';

export default function UserList() {
  const [users, setUsers] = useState([]);
  const [search, setSearch] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchUsers = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const data = await listUsers();
      setUsers(Array.isArray(data) ? data : []);
    } catch (err) {
      setError(getErrorMessage(err, 'Failed to fetch user directory.'));
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchUsers();
  }, []);

  const filteredUsers = users.filter((u) => {
    const term = search.toLowerCase().trim();
    if (!term) return true;
    const uid = (u.uid || u.id || '').toLowerCase();
    const email = (u.email || '').toLowerCase();
    const name = (u.display_name || u.name || '').toLowerCase();
    const phone = (u.phone_number || u.phone || '').toLowerCase();
    return uid.includes(term) || email.includes(term) || name.includes(term) || phone.includes(term);
  });

  return (
    <div className="p-lg md:p-xl space-y-xl max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-md">
        <div>
          <h1 className="font-headline-md text-headline-md text-on-surface">User Management</h1>
          <p className="font-body-md text-on-surface-variant mt-xs">
            Inspect customer accounts, roles, and balance histories.
          </p>
        </div>

        <button
          onClick={fetchUsers}
          disabled={isLoading}
          className="p-sm bg-surface-container-low hover:bg-surface-container text-on-surface rounded-lg border border-outline-variant/30 transition-colors shadow-sm self-start md:self-auto"
          title="Refresh Users"
        >
          <span className={`material-symbols-outlined text-[20px] ${isLoading ? 'animate-spin' : ''}`}>
            refresh
          </span>
        </button>
      </div>

      {error && <Alert type="error" message={error} onClose={() => setError(null)} />}

      {/* Search & Filter Toolbar */}
      <div className="bg-surface-container-lowest p-md rounded-2xl shadow-sm border border-outline-variant/20 flex flex-col sm:flex-row items-center justify-between gap-md">
        <div className="relative w-full sm:w-80">
          <span className="material-symbols-outlined absolute left-md top-1/2 -translate-y-1/2 text-outline text-[20px]">
            search
          </span>
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by name, email, or phone..."
            className="w-full pl-[42px] pr-md py-xs bg-surface-container border border-outline-variant/30 rounded-xl font-body-sm text-on-surface focus:outline-none focus:ring-2 focus:ring-primary focus:bg-surface-container-lowest transition-all"
          />
        </div>

        <div className="font-label-caps text-on-surface-variant text-[11px] uppercase tracking-wider">
          Total Users: {filteredUsers.length}
        </div>
      </div>

      {/* Users Table */}
      <div className="bg-surface-container-lowest rounded-2xl shadow-sm border border-outline-variant/20 overflow-hidden">
        {isLoading ? (
          <LoadingSpinner text="Fetching user records..." />
        ) : filteredUsers.length === 0 ? (
          <EmptyState
            icon="group"
            title={search ? 'No matching users' : 'No users registered'}
            description={
              search
                ? 'Try adjusting your search terms.'
                : 'Registered customer and staff accounts will appear here.'
            }
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left font-body-md border-collapse">
              <thead>
                <tr className="bg-surface-container-low text-on-surface-variant font-label-caps text-label-caps uppercase tracking-wider border-b border-outline-variant/20">
                  <th className="p-table-cell-padding">User</th>
                  <th className="p-table-cell-padding">Role</th>
                  <th className="p-table-cell-padding">Contact</th>
                  <th className="p-table-cell-padding text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-outline-variant/10">
                {filteredUsers.map((u) => {
                  const uid = u.uid || u.id;
                  const name = u.display_name || u.name || 'Unnamed User';
                  const email = u.email || 'No email';
                  const role = u.role || (u.is_admin ? 'Admin' : 'Customer');
                  const phone = u.phone_number || u.phone || '—';

                  return (
                    <tr
                      key={uid}
                      className="hover:bg-surface-container-low/50 transition-colors group"
                    >
                      <td className="p-table-cell-padding">
                        <div className="flex items-center gap-sm">
                          <div className="w-8 h-8 rounded-full bg-primary/10 text-primary font-bold flex items-center justify-center text-body-sm">
                            {name.charAt(0).toUpperCase()}
                          </div>
                          <div>
                            <div className="font-semibold text-on-surface">{name}</div>
                            <div className="font-body-sm text-on-surface-variant text-[12px]">
                              {email}
                            </div>
                          </div>
                        </div>
                      </td>

                      <td className="p-table-cell-padding">
                        <span
                          className={`font-label-caps text-[10px] uppercase font-bold px-2 py-0.5 rounded-full ${
                            role.toLowerCase().includes('admin')
                              ? 'bg-primary-fixed text-on-primary-fixed'
                              : 'bg-surface-container text-on-surface-variant'
                          }`}
                        >
                          {role}
                        </span>
                      </td>

                      <td className="p-table-cell-padding font-body-sm text-on-surface-variant">
                        {phone}
                      </td>

                      <td className="p-table-cell-padding text-right">
                        <div className="flex items-center justify-end gap-xs">
                          <Link
                            to={`/wallet/investigation?uid=${encodeURIComponent(uid)}`}
                            className="p-1 rounded text-on-surface-variant hover:text-primary hover:bg-surface-container transition-colors"
                            title="Investigate Wallet"
                          >
                            <span className="material-symbols-outlined text-[18px]">
                              account_balance_wallet
                            </span>
                          </Link>

                          <Link
                            to={`/users/${encodeURIComponent(uid)}`}
                            className="inline-flex items-center gap-xs px-md py-xs bg-surface-container hover:bg-primary hover:text-on-primary text-on-surface rounded-lg font-body-sm font-medium transition-all shadow-sm"
                          >
                            <span>View Profile</span>
                            <span className="material-symbols-outlined text-[16px]">
                              arrow_forward
                            </span>
                          </Link>
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
    </div>
  );
}
