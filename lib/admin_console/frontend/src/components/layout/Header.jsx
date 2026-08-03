import React from 'react';
import { useLocation, Link } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';

export default function Header() {
  const { user } = useAuth();
  const location = useLocation();

  const getBreadcrumbs = () => {
    const segments = location.pathname.split('/').filter(Boolean);
    if (segments.length === 0) return 'Dashboard';

    return segments
      .map((seg) => seg.replace(/[-_]/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase()))
      .join(' / ');
  };

  return (
    <header className="fixed top-0 left-sidebar-width right-0 h-16 bg-surface-container-lowest/90 backdrop-blur-md z-40 flex items-center justify-between px-lg border-b border-outline-variant/20 shadow-[0_1px_8px_rgba(0,0,0,0.03)]">
      <div className="flex items-center gap-md">
        <span className="material-symbols-outlined text-outline text-[20px]">chevron_right</span>
        <div className="font-label-caps text-on-surface-variant uppercase tracking-wider text-[11px] font-bold">
          Canteen Console / {getBreadcrumbs()}
        </div>
      </div>

      <div className="flex items-center gap-lg">
        <div className="flex items-center gap-sm">
          <div className="text-right hidden sm:block">
            <div className="font-body-sm font-bold text-on-surface truncate max-w-[180px]">
              {user?.email || 'Admin User'}
            </div>
            <div className="font-label-caps text-on-surface-variant text-[10px] uppercase tracking-wider">
              {user?.is_admin ? 'Super Admin' : 'Admin'}
            </div>
          </div>
          <div className="w-8 h-8 rounded-full bg-primary flex items-center justify-center text-on-primary shadow-sm font-bold text-body-sm">
            {user?.email ? user.email.charAt(0).toUpperCase() : 'A'}
          </div>
        </div>
      </div>
    </header>
  );
}
