import React from 'react';
import { useLocation, Link } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';

function getBreadcrumbItems(pathname) {
  const segments = pathname.split('/').filter(Boolean);

  if (segments.length === 0) {
    return [{ label: 'Dashboard', path: null }];
  }

  const first = segments[0];

  if (first === 'users') {
    if (segments.length === 1) {
      return [{ label: 'Users', path: null }];
    }
    return [
      { label: 'Users', path: '/users' },
      { label: 'User Profile', path: null },
    ];
  }

  if (first === 'inventory') {
    return [{ label: 'Inventory', path: null }];
  }

  if (first === 'orders') {
    if (segments.length === 1) {
      return [{ label: 'Orders', path: null }];
    }
    if (segments[1] === 'create') {
      return [
        { label: 'Orders', path: '/orders' },
        { label: 'Walk-in POS Order', path: null },
      ];
    }
    return [
      { label: 'Orders', path: '/orders' },
      { label: 'Order Details', path: null },
    ];
  }

  if (first === 'wallet') {
    const sub = segments[1];
    if (sub === 'deposits') {
      return [
        { label: 'Wallet & Finance', path: null },
        { label: 'Deposit Requests', path: null },
      ];
    }
    if (sub === 'refunds') {
      if (segments.length > 2) {
        return [
          { label: 'Wallet & Finance', path: null },
          { label: 'Refund Requests', path: '/wallet/refunds' },
          { label: 'Refund Details', path: null },
        ];
      }
      return [
        { label: 'Wallet & Finance', path: null },
        { label: 'Refund Requests', path: null },
      ];
    }
    if (sub === 'investigation') {
      return [
        { label: 'Wallet & Finance', path: null },
        { label: 'Wallet Investigation', path: null },
      ];
    }
  }

  if (first === 'foodpulse') {
    if (segments.length === 1) {
      return [{ label: 'FoodPulse', path: null }];
    }
    const sub = segments[1];
    if (sub === 'suggestions') {
      return [
        { label: 'FoodPulse', path: '/foodpulse' },
        { label: 'Student Suggestions', path: null },
      ];
    }
    if (sub === 'polls') {
      return [
        { label: 'FoodPulse', path: '/foodpulse' },
        { label: 'Community Polls', path: null },
      ];
    }
  }

  return segments.map((seg, idx) => {
    const isLast = idx === segments.length - 1;
    const label = seg.replace(/[-_]/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
    return {
      label,
      path: isLast ? null : '/' + segments.slice(0, idx + 1).join('/'),
    };
  });
}

export default function Header() {
  const { user } = useAuth();
  const location = useLocation();
  const breadcrumbItems = getBreadcrumbItems(location.pathname);

  return (
    <header className="fixed top-0 left-sidebar-width right-0 h-16 bg-surface-container-lowest/90 backdrop-blur-md z-40 flex items-center justify-between px-lg border-b border-outline-variant/20 shadow-[0_1px_8px_rgba(0,0,0,0.02)] select-none">
      {/* Dynamic Breadcrumbs */}
      <nav className="flex items-center gap-xs font-label-caps text-[12px]">
        <Link
          to="/"
          className="text-on-surface-variant/80 hover:text-primary transition-colors flex items-center gap-1 font-semibold"
        >
          <span className="material-symbols-outlined text-[16px]">storefront</span>
          <span>Canteen Console</span>
        </Link>

        {breadcrumbItems.map((item, index) => (
          <React.Fragment key={index}>
            <span className="text-outline-variant text-[12px] font-mono select-none mx-0.5">/</span>
            {item.path ? (
              <Link
                to={item.path}
                className="text-on-surface-variant/80 hover:text-primary transition-colors font-semibold"
              >
                {item.label}
              </Link>
            ) : (
              <span className="text-on-surface font-bold">
                {item.label}
              </span>
            )}
          </React.Fragment>
        ))}
      </nav>

      {/* Right Header Admin Details */}
      <div className="flex items-center gap-md">
        <div className="flex items-center gap-sm">
          <div className="text-right hidden sm:block">
            <div className="font-body-sm font-bold text-on-surface truncate max-w-[180px]">
              {user?.email || 'Admin User'}
            </div>
            <div className="font-label-caps text-on-surface-variant text-[10px] uppercase tracking-wider font-semibold">
              {user?.is_admin ? 'Super Admin' : 'Admin'}
            </div>
          </div>
          <div className="w-8 h-8 rounded-full bg-primary/10 text-primary border border-primary/20 flex items-center justify-center font-bold text-body-sm shadow-xs">
            {user?.email ? user.email.charAt(0).toUpperCase() : 'A'}
          </div>
        </div>
      </div>
    </header>
  );
}
