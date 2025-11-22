'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabase';
import { useAuthStore } from '@/store/auth';
import { AlertCircle, Loader } from 'lucide-react';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [otpCode, setOtpCode] = useState('');
  const [showOtpInput, setShowOtpInput] = useState(false);
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [successMessage, setSuccessMessage] = useState('');
  const router = useRouter();
  const { setUser } = useAuthStore();

  // If a magic link redirected back with an access token in the URL, parse and store it
  useEffect(() => {
    // Subscribe to auth events. This will catch session changes after magic link redirect.
    const { data: listener } = supabase.auth.onAuthStateChange((event: any, session: any) => {
      if (session) {
        setUser({ id: session.user.id, email: session.user.email || '', role: 'admin' });
        router.push('/dashboard');
      }
    });

    // Also check immediately if a session already exists (e.g., from magic link redirect)
    (async () => {
      const { data } = await supabase.auth.getSession();
      if (data?.session) {
        setUser({ id: data.session.user.id, email: data.session.user.email || '', role: 'admin' });
        router.push('/dashboard');
      }
    })();

    return () => listener?.subscription?.unsubscribe?.();
  }, [router, setUser]);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setIsLoading(true);
    setSuccessMessage('');

    try {
      if (!showOtpInput) {
        // Step 1: Request OTP code
        const { error: otpError } = await supabase.auth.signInWithOtp({
          email,
          options: {
            emailRedirectTo: `${window.location.origin}/dashboard`,
          },
        });

        if (otpError) {
          setError(otpError.message);
          return;
        }

        setShowOtpInput(true);
        setSuccessMessage('✓ Check your email! Enter the 8-digit code below.');
        setError('');
      } else {
        // Step 2: Verify OTP code
        if (!otpCode || otpCode.length !== 8) {
          setError('Please enter the 8-digit code from your email');
          return;
        }

        const { data, error: verifyError } = await supabase.auth.verifyOtp({
          email,
          token: otpCode,
          type: 'email',
        });

        if (verifyError) {
          setError(verifyError.message);
          return;
        }

        if (data.user) {
          setUser({ id: data.user.id, email: data.user.email || '', role: 'admin' });
          setSuccessMessage('✓ Success! Redirecting to dashboard...');
          setTimeout(() => router.push('/dashboard'), 1000);
        }
      }
    } catch (err: unknown) {
      console.error('Error:', err);
      setError('An error occurred. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
  <div className="min-h-screen bg-blue-600 flex items-center justify-center p-4">
      <div className="w-full max-w-md bg-white rounded-lg shadow-xl p-8">
        {/* Header */}
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-slate-900">HazPay Admin</h1>
          <p className="text-slate-600 mt-2">Fintech Dashboard</p>
        </div>

        {/* Info banner */}
        <div className="mb-4 p-3 bg-blue-50 border border-blue-200 rounded-lg">
          <p className="text-sm text-blue-800 text-center">
            Enter your email to receive a sign-in link (same as mobile app)
          </p>
        </div>

        {/* Error Message */}
        {error && (
          <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg flex gap-3">
            <AlertCircle className="text-red-600 shrink-0" size={20} />
            <p className="text-red-700 text-sm">{error}</p>
          </div>
        )}

        {successMessage && (
          <div className="mb-6 p-4 bg-green-50 border border-green-200 rounded-lg flex gap-3">
            <AlertCircle className="text-green-600 shrink-0" size={20} />
            <p className="text-green-700 text-sm">{successMessage}</p>
          </div>
        )}

        {/* Form */}
        <form onSubmit={handleLogin} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-slate-700 mb-2">
              Email Address
            </label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="admin@hazpay.com"
              disabled={showOtpInput}
              className="w-full px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:bg-slate-100"
              required
            />
          </div>

          {showOtpInput && (
            <div>
              <label className="block text-sm font-medium text-slate-700 mb-2">
                8-Digit Code from Email
              </label>
              <input
                type="text"
                value={otpCode}
                onChange={(e) => setOtpCode(e.target.value.replace(/\D/g, '').slice(0, 8))}
                placeholder="64173066"
                maxLength={8}
                className="w-full px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-center text-2xl font-mono tracking-widest"
                required
                autoFocus
              />
            </div>
          )}

          <button
            type="submit"
            disabled={isLoading}
            className="w-full bg-blue-600 text-white py-2 rounded-lg font-medium hover:bg-blue-700 transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
          >
            {isLoading && <Loader size={18} className="animate-spin" />}
            {isLoading ? (showOtpInput ? 'Verifying...' : 'Sending...') : (showOtpInput ? 'Verify Code' : 'Send Code')}
          </button>

          {showOtpInput && (
            <button
              type="button"
              onClick={() => {
                setShowOtpInput(false);
                setOtpCode('');
                setSuccessMessage('');
                setError('');
              }}
              className="w-full bg-slate-200 text-slate-700 py-2 rounded-lg font-medium hover:bg-slate-300 transition-colors"
            >
              Use different email
            </button>
          )}
        </form>

        {/* Info */}
        <p className="mt-6 text-sm text-slate-600 text-center">
          No password needed. Click the link in your email to sign in.
        </p>
      </div>
    </div>
  );
}
