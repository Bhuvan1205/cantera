import React, { useState } from 'react';
import { useNavigate, useLocation, useSearchParams } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { getErrorMessage } from '../api/client';
import { Alert } from '../components/common/Feedback';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState(null);

  const { login } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [searchParams] = useSearchParams();

  const isExpired = searchParams.get('expired') === '1';
  const from = location.state?.from?.pathname || '/';

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!email || !password) {
      setError('Please enter both email and password.');
      return;
    }

    setIsSubmitting(true);
    setError(null);

    try {
      await login(email, password);
      navigate(from, { replace: true });
    } catch (err) {
      setError(getErrorMessage(err, 'Authentication failed. Please check your credentials.'));
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen bg-surface flex flex-col justify-center py-xl px-md sm:px-lg">
      <div className="sm:mx-auto sm:w-full sm:max-w-md">
        <div className="flex justify-center mb-md">
          <div className="w-14 h-14 rounded-2xl bg-primary text-on-primary flex items-center justify-center shadow-lg">
            <span className="material-symbols-outlined text-[32px]">restaurant_menu</span>
          </div>
        </div>
        <h2 className="text-center font-display-lg text-headline-md font-bold tracking-tight text-on-surface">
          Canteen Admin Console
        </h2>
        <p className="mt-xs text-center font-body-md text-on-surface-variant">
          Sign in with your administrative credentials
        </p>
      </div>

      <div className="mt-lg sm:mx-auto sm:w-full sm:max-w-md">
        <div className="bg-surface-container-lowest py-xl px-lg sm:px-xl shadow-xl rounded-2xl border border-outline-variant/30 space-y-lg">
          {isExpired && !error && (
            <Alert
              type="warning"
              message="Your session has expired. Please log in again to continue."
            />
          )}

          {error && <Alert type="error" message={error} onClose={() => setError(null)} />}

          <form onSubmit={handleSubmit} className="space-y-md">
            <div>
              <label
                htmlFor="email"
                className="block font-label-caps text-on-surface uppercase tracking-wider text-[11px] mb-xs"
              >
                Admin Email
              </label>
              <div className="relative">
                <span className="material-symbols-outlined absolute left-md top-1/2 -translate-y-1/2 text-outline text-[20px]">
                  mail
                </span>
                <input
                  id="email"
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="admin@canteen.internal"
                  className="w-full pl-[42px] pr-md py-sm bg-surface-container border border-outline-variant/50 rounded-xl font-body-md text-on-surface focus:outline-none focus:ring-2 focus:ring-primary focus:bg-surface-container-lowest transition-all"
                />
              </div>
            </div>

            <div>
              <label
                htmlFor="password"
                className="block font-label-caps text-on-surface uppercase tracking-wider text-[11px] mb-xs"
              >
                Password
              </label>
              <div className="relative">
                <span className="material-symbols-outlined absolute left-md top-1/2 -translate-y-1/2 text-outline text-[20px]">
                  lock
                </span>
                <input
                  id="password"
                  type="password"
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  className="w-full pl-[42px] pr-md py-sm bg-surface-container border border-outline-variant/50 rounded-xl font-body-md text-on-surface focus:outline-none focus:ring-2 focus:ring-primary focus:bg-surface-container-lowest transition-all"
                />
              </div>
            </div>

            <div className="pt-sm">
              <button
                type="submit"
                disabled={isSubmitting}
                className="w-full py-sm px-md rounded-xl font-title-sm font-semibold text-on-primary bg-primary hover:bg-primary-container active:scale-[0.99] transition-all shadow-md flex items-center justify-center gap-xs disabled:opacity-50"
              >
                {isSubmitting ? (
                  <>
                    <span className="material-symbols-outlined animate-spin text-[20px]">
                      refresh
                    </span>
                    <span>Authenticating...</span>
                  </>
                ) : (
                  <>
                    <span className="material-symbols-outlined text-[20px]">login</span>
                    <span>Sign In to Console</span>
                  </>
                )}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}
