import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import ProtectedRoute from './components/layout/ProtectedRoute';
import AppLayout from './components/layout/AppLayout';

// Pages
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import UserList from './pages/Users/UserList';
import UserDetails from './pages/Users/UserDetails';
import InventoryList from './pages/Inventory/InventoryList';
import OrderList from './pages/Orders/OrderList';
import OrderDetails from './pages/Orders/OrderDetails';
import CreateManualOrder from './pages/Orders/CreateManualOrder';
import DepositRequests from './pages/Wallet/DepositRequests';
import RefundRequests from './pages/Wallet/RefundRequests';
import RefundDetails from './pages/Wallet/RefundDetails';
import WalletInvestigation from './pages/Wallet/WalletInvestigation';

// FoodPulse Pages
import FoodPulseDashboard from './pages/FoodPulse/FoodPulseDashboard';
import SuggestionList from './pages/FoodPulse/SuggestionList';
import PollManagement from './pages/FoodPulse/PollManagement';

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          {/* Public Authentication Route */}
          <Route path="/login" element={<Login />} />

          {/* Protected Administrative Console Routes */}
          <Route
            path="/"
            element={
              <ProtectedRoute>
                <AppLayout />
              </ProtectedRoute>
            }
          >
            <Route index element={<Dashboard />} />

            {/* Users */}
            <Route path="users" element={<UserList />} />
            <Route path="users/:uid" element={<UserDetails />} />

            {/* Inventory */}
            <Route path="inventory" element={<InventoryList />} />

            {/* Orders */}
            <Route path="orders" element={<OrderList />} />
            <Route path="orders/create" element={<CreateManualOrder />} />
            <Route path="orders/:id" element={<OrderDetails />} />

            {/* Wallet & Finance */}
            <Route path="wallet/deposits" element={<DepositRequests />} />
            <Route path="wallet/refunds" element={<RefundRequests />} />
            <Route path="wallet/refunds/:id" element={<RefundDetails />} />
            <Route path="wallet/investigation" element={<WalletInvestigation />} />

            {/* FoodPulse – Student Demand & Community Feedback */}
            <Route path="foodpulse" element={<FoodPulseDashboard />} />
            <Route path="foodpulse/suggestions" element={<SuggestionList />} />
            <Route path="foodpulse/polls" element={<PollManagement />} />
          </Route>

          {/* Catch-all fallback redirect */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  );
}
