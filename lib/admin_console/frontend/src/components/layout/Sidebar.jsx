import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';

export default function Sidebar() {
  const { logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const navLinkClass = ({ isActive }) =>
    `relative flex items-center gap-md px-md py-2.5 rounded-xl transition-all text-body-md font-medium ${
      isActive
        ? 'bg-primary text-on-primary shadow-sm font-semibold'
        : 'text-inverse-on-surface/75 hover:bg-white/10 hover:text-inverse-on-surface'
    }`;

  const subNavLinkClass = ({ isActive }) =>
    `px-md py-2 rounded-lg transition-all text-[13px] block font-medium ${
      isActive
        ? 'bg-primary/90 text-on-primary font-semibold shadow-xs'
        : 'text-inverse-on-surface/65 hover:text-inverse-on-surface hover:bg-white/5'
    }`;

  return (
    <aside className="fixed left-0 top-0 h-full w-sidebar-width bg-inverse-surface text-inverse-on-surface z-50 flex flex-col shadow-xl select-none">
      {/* Brand Header */}
      <div className="p-lg flex items-center gap-md border-b border-white/10">
        <div className="w-10 h-10 rounded-xl bg-primary-container/40 border border-primary-fixed/20 flex items-center justify-center text-primary-fixed shadow-inner">
          <span className="material-symbols-outlined text-[22px]">storefront</span>
        </div>
        <div>
          <div className="font-headline-md text-title-sm tracking-tight text-inverse-on-surface font-bold">
            Canteen Admin
          </div>
          <div className="font-label-caps text-[10px] text-inverse-on-surface/50 uppercase tracking-widest">
            Operations Console
          </div>
        </div>
      </div>

      {/* Navigation Body */}
      <nav className="flex-1 px-md py-md space-y-sm overflow-y-auto">
        {/* Core Navigation */}
        <div className="space-y-xs">
          <NavLink to="/" end className={navLinkClass}>
            <span className="material-symbols-outlined text-[20px]">dashboard</span>
            <span>Dashboard</span>
          </NavLink>

          <NavLink to="/users" className={navLinkClass}>
            <span className="material-symbols-outlined text-[20px]">group</span>
            <span>Users</span>
          </NavLink>

          <NavLink to="/inventory" className={navLinkClass}>
            <span className="material-symbols-outlined text-[20px]">inventory_2</span>
            <span>Inventory</span>
          </NavLink>

          <NavLink to="/orders" className={navLinkClass}>
            <span className="material-symbols-outlined text-[20px]">receipt_long</span>
            <span>Orders</span>
          </NavLink>
        </div>

        {/* Wallet & Finance Section */}
        <div className="pt-md">
          <div className="px-md pb-xs flex items-center gap-xs text-[10px] font-bold uppercase tracking-wider text-inverse-on-surface/45">
            <span className="material-symbols-outlined text-[15px]">account_balance_wallet</span>
            <span>Wallet & Finance</span>
          </div>

          <div className="ml-3 pl-3 border-l border-white/10 space-y-xs">
            <NavLink to="/wallet/deposits" className={subNavLinkClass}>
              Deposit Requests
            </NavLink>
            <NavLink to="/wallet/refunds" className={subNavLinkClass}>
              Refund Requests
            </NavLink>
            <NavLink to="/wallet/investigation" className={subNavLinkClass}>
              Wallet Investigation
            </NavLink>
          </div>
        </div>

        {/* FoodPulse Section */}
        <div className="pt-md">
          <div className="px-md pb-xs flex items-center gap-xs text-[10px] font-bold uppercase tracking-wider text-inverse-on-surface/45">
            <span className="material-symbols-outlined text-[15px]">poll</span>
            <span>FoodPulse</span>
          </div>

          <div className="ml-3 pl-3 border-l border-white/10 space-y-xs">
            <NavLink to="/foodpulse" end className={subNavLinkClass}>
              Dashboard
            </NavLink>
            <NavLink to="/foodpulse/suggestions" className={subNavLinkClass}>
              Student Suggestions
            </NavLink>
            <NavLink to="/foodpulse/polls" className={subNavLinkClass}>
              Community Polls
            </NavLink>
          </div>
        </div>
      </nav>

      {/* Footer / Sign Out */}
      <div className="p-md border-t border-white/10">
        <button
          onClick={handleLogout}
          className="w-full flex items-center gap-md px-md py-2.5 rounded-xl text-error-container hover:bg-error/15 hover:text-white transition-all font-body-sm text-left font-medium"
        >
          <span className="material-symbols-outlined text-[20px] text-error">logout</span>
          <span>Sign Out</span>
        </button>
      </div>
    </aside>
  );
}
