import React, { createContext, useContext, useState, useEffect } from 'react';
import { login as apiLogin, ping as apiPing } from '../api/auth';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [token, setToken] = useState(() => localStorage.getItem('admin_token'));
  const [user, setUser] = useState(() => {
    const saved = localStorage.getItem('admin_user');
    return saved ? JSON.parse(saved) : null;
  });
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    async function checkExistingAuth() {
      const savedToken = localStorage.getItem('admin_token');
      if (savedToken) {
        try {
          const pingRes = await apiPing();
          if (!user || user.uid !== pingRes.admin_uid) {
            const updatedUser = { ...(user || {}), uid: pingRes.admin_uid, is_admin: true };
            setUser(updatedUser);
            localStorage.setItem('admin_user', JSON.stringify(updatedUser));
          }
        } catch (err) {
          console.warn('Session verification failed:', err);
          logout();
        }
      }
      setIsLoading(false);
    }
    checkExistingAuth();
  }, []);

  const login = async (email, password) => {
    const data = await apiLogin(email, password);
    const idToken = data.id_token;
    const userData = {
      uid: data.uid,
      email: data.email,
      is_admin: data.is_admin,
    };

    localStorage.setItem('admin_token', idToken);
    localStorage.setItem('admin_user', JSON.stringify(userData));
    setToken(idToken);
    setUser(userData);
    return userData;
  };

  const logout = () => {
    localStorage.removeItem('admin_token');
    localStorage.removeItem('admin_user');
    setToken(null);
    setUser(null);
  };

  const isAuthenticated = Boolean(token && user);

  return (
    <AuthContext.Provider
      value={{
        token,
        user,
        isLoading,
        isAuthenticated,
        login,
        logout,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
