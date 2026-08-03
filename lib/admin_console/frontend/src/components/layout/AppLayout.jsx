import React from 'react';
import { Outlet } from 'react-router-dom';
import Sidebar from './Sidebar';
import Header from './Header';

export default function AppLayout() {
  return (
    <div className="bg-background min-h-screen font-body-md text-on-surface">
      <Sidebar />
      <div className="pl-sidebar-width w-full">
        <Header />
        <main className="relative pt-16 min-h-[calc(100vh-64px)] bg-surface">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
