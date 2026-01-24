'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@supabase/supabase-js';
import { Mail, Loader, ShieldAlert } from 'lucide-react';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

// Hardcoded admin emails for reliable access (fallback if DB fails)
const ADMIN_EMAILS = ['yyounghaz@gmail.com'];

// Check if email is admin (client-side validation)
async function checkIsAdmin(email: string): Promise<boolean> {
  const normalizedEmail = email.toLowerCase().trim();
  
  // Hardcoded check first (always reliable)
  if (ADMIN_EMAILS.includes(normalizedEmail)) {
    return true;
  }
  
  // Then check admin_emails table
  try {
    const { data, error } = await supabase
      .from('admin_emails')
      .select('email')
      .eq('email', normalizedEmail)
      .eq('is_active', true)
      .single();
    
    if (data && !error) {
      return true;
    }
  } catch (e) {
    console.log('Admin check via DB failed, using hardcoded list only');
  }
  
  return false;
}

export function SignupProtection() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [otp, setOtp] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [successMessage, setSuccessMessage] = useState('');
  const [isCheckingSession, setIsCheckingSession] = useState(true);
  const [otpSent, setOtpSent] = useState(false);
  const [storedEmail, setStoredEmail] = useState('');
  const [notAdmin, setNotAdmin] = useState(false);

  // Check if already logged in
  useEffect(() => {
    const checkSession = async () => {
      const { data: { session } } = await supabase.auth.getSession();
      if (session) {
        router.push('/admin/bills');
      }
      setIsCheckingSession(false);
    };
    checkSession();
  }, [router]);

  const handleSendOTP = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    setSuccessMessage('');
    setNotAdmin(false);

    const normalizedEmail = email.toLowerCase().trim();

    try {
      // Check if email is admin BEFORE sending OTP
      const isAdmin = await checkIsAdmin(normalizedEmail);
      
      if (!isAdmin) {
        setError('❌ Access denied. This email is not authorized for admin access.');
        setNotAdmin(true);
        setLoading(false);
        return;
      }

      // Send OTP via email (only for admins)
      const { error: otpError } = await supabase.auth.signInWithOtp({
        email: normalizedEmail,
        options: {
          emailRedirectTo: `${typeof window !== 'undefined' ? window.location.origin : ''}/admin/bills`,
        },
      });

      if (otpError) {
        setError(otpError.message);
      } else {
        setSuccessMessage('✅ Check your email for the login code!');
        setStoredEmail(normalizedEmail);
        setOtpSent(true);
        setEmail('');
      }
    } catch (err) {
      setError('An error occurred. Please try again.');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyOTP = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      console.log('Starting OTP verification for:', storedEmail);
      const { error: verifyError, data } = await supabase.auth.verifyOtp({
        email: storedEmail,
        token: otp,
        type: 'email',
      });

      if (verifyError) {
        console.error('OTP verification failed:', verifyError);
        setError(verifyError.message);
        setLoading(false);
        return;
      }

      console.log('OTP verified successfully, session:', data.session ? 'active' : 'none');
      setSuccessMessage('✅ Logged in successfully! Redirecting...');
      
      // Use replace to prevent back navigation to login
      // Small delay to show success message
      await new Promise(resolve => setTimeout(resolve, 500));
      window.location.href = '/admin/bills';
    } catch (err) {
      console.error('OTP verification error:', err);
      setError('An error occurred. Please try again.');
      setLoading(false);
    }
  };

  if (isCheckingSession) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-gradient-to-br from-gray-900 to-gray-800">
        <Loader className="w-8 h-8 animate-spin text-blue-500" />
      </div>
    );
  }

  // Show access denied screen if user tried non-admin email
  if (notAdmin) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-gradient-to-br from-gray-900 to-gray-800 px-4">
        <div className="w-full max-w-md">
          <div className="bg-gray-800 border border-red-700 rounded-lg shadow-lg p-8">
            <div className="text-center mb-6">
              <ShieldAlert className="w-16 h-16 mx-auto mb-4 text-red-500" />
              <h1 className="text-2xl font-bold text-white mb-2">Access Denied</h1>
              <p className="text-gray-400">This email is not authorized for admin access.</p>
            </div>
            
            <button
              onClick={() => {
                setNotAdmin(false);
                setError('');
                setEmail('');
              }}
              className="w-full py-2 bg-gray-700 hover:bg-gray-600 text-white font-medium rounded-lg transition-colors"
            >
              Try Different Email
            </button>
            
            <p className="text-center text-gray-500 text-xs mt-6">
              Contact the system administrator if you need access.
            </p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex items-center justify-center min-h-screen bg-gradient-to-br from-gray-900 to-gray-800 px-4">
      <div className="w-full max-w-md">
        <div className="bg-gray-800 border border-gray-700 rounded-lg shadow-lg p-8">
          <div className="text-center mb-8">
            <Mail className="w-12 h-12 mx-auto mb-4 text-blue-500" />
            <h1 className="text-2xl font-bold text-white mb-2">Admin Access</h1>
            <p className="text-gray-400">Login with your admin email</p>
          </div>

          {error && (
            <div className="mb-4 p-4 bg-red-900/30 border border-red-700 rounded-lg text-red-300 text-sm">
              {error}
            </div>
          )}

          {successMessage && (
            <div className="mb-4 p-4 bg-green-900/30 border border-green-700 rounded-lg text-green-300 text-sm">
              {successMessage}
            </div>
          )}

          {!otpSent ? (
            // Email form
            <form onSubmit={handleSendOTP} className="space-y-4">
              <div>
                <label htmlFor="email" className="block text-sm font-medium text-gray-300 mb-2">
                  Email Address
                </label>
                <input
                  type="email"
                  id="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="yyounghaz@gmail.com"
                  className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
                  required
                  disabled={loading}
                />
              </div>

              <button
                type="submit"
                disabled={loading || !email}
                className="w-full py-2 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 disabled:cursor-not-allowed text-white font-medium rounded-lg transition-colors flex items-center justify-center gap-2"
              >
                {loading ? (
                  <>
                    <Loader className="w-4 h-4 animate-spin" />
                    Sending...
                  </>
                ) : (
                  'Send Login Code'
                )}
              </button>
            </form>
          ) : (
            // OTP form
            <form onSubmit={handleVerifyOTP} className="space-y-4">
              <div>
                <label htmlFor="otp" className="block text-sm font-medium text-gray-300 mb-2">
                  Enter Login Code
                </label>
                <p className="text-xs text-gray-400 mb-3">
                  We sent a code to <strong>{storedEmail}</strong>
                </p>
                <input
                  type="text"
                  id="otp"
                  value={otp}
                  onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 8))}
                  placeholder="000000"
                  maxLength={8}
                  className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500 text-center text-2xl tracking-widest"
                  required
                  disabled={loading}
                />
              </div>

              <button
                type="submit"
                disabled={loading || otp.length < 6}
                className="w-full py-2 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 disabled:cursor-not-allowed text-white font-medium rounded-lg transition-colors flex items-center justify-center gap-2"
              >
                {loading ? (
                  <>
                    <Loader className="w-4 h-4 animate-spin" />
                    Verifying...
                  </>
                ) : (
                  'Verify Code'
                )}
              </button>

              <button
                type="button"
                onClick={() => {
                  setOtpSent(false);
                  setOtp('');
                  setSuccessMessage('');
                }}
                className="w-full py-2 bg-gray-700 hover:bg-gray-600 text-gray-300 font-medium rounded-lg transition-colors"
              >
                Change Email
              </button>
            </form>
          )}

          <p className="text-center text-gray-400 text-sm mt-4">
           
          </p>
        </div>

        <p className="text-center text-gray-500 text-xs mt-4">
          🔒 Protected Admin Access • Only whitelisted emails can login
        </p>
      </div>
    </div>
  );
}
