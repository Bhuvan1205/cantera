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
    `flex items-center gap-md px-md py-sm rounded transition-all text-body-md ${
      isActive
        ? 'bg-primary text-on-primary shadow-md font-medium'
        : 'text-on-surface-variant hover:bg-surface-variant/10 hover:text-inverse-on-surface'
    }`;

  const subNavLinkClass = ({ isActive }) =>
    `px-md py-xs rounded transition-all text-body-sm block ${
      isActive
        ? 'bg-primary text-on-primary shadow-sm font-medium'
        : 'text-on-surface-variant/80 hover:text-inverse-on-surface hover:bg-surface-variant/5'
    }`;

  return (
    <aside className="fixed left-0 top-0 h-full w-sidebar-width bg-inverse-surface text-inverse-on-surface z-50 flex flex-col shadow-lg">
      <div className="p-lg flex items-center gap-md border-b border-outline/20">
        <span className="material-symbols-outlined text-primary-fixed text-[28px]">
          restaurant_menu
        </span>
        <span className="font-headline-md text-title-sm tracking-tight text-inverse-on-surface">
          Canteen Admin
        </span>
      </div>

      <nav className="flex-1 px-md py-lg space-y-base overflow-y-auto">
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

        <div className="space-y-xs pt-xs">
          <div className="flex items-center gap-md px-md py-sm text-on-surface-variant font-body-md">
            <span className="material-symbols-outlined text-[20px]">account_balance_wallet</span>
            <span>Wallet & Finance</span>
          </div>

          <div className="pl-xl flex flex-col gap-xs">
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
        <div className="space-y-xs pt-xs">
          <div className="flex items-center gap-md px-md py-sm text-on-surface-variant font-body-md">
            <span className="material-symbols-outlined text-[20px] text-purple-400">poll</span>
            <span>FoodPulse</span>
          </div>

          <div className="pl-xl flex flex-col gap-xs">
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

      <div className="p-md border-t border-outline/20">
        <button
          onClick={handleLogout}
          className="w-full flex items-center gap-md px-md py-sm rounded text-error hover:bg-error/10 transition-all font-body-md text-left"
        >
          <span className="material-symbols-outlined text-[20px]">logout</span>
          <span>Sign Out</span>
        </button>
      </div>
    </aside>
  );
}
