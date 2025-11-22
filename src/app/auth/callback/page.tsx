'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabase';
import { useAuthStore } from '@/store/auth';

export default function AuthCallbackPage() {
  const router = useRouter();
  const { setUser } = useAuthStore();

  useEffect(() => {
    const handleCallback = async () => {
      try {
        // Get session from URL hash
        const { data, error } = await supabase.auth.getSession();

        if (error) {
          console.error('Auth error:', error);
          router.push('/login?error=Authentication failed');
          return;
        }

        if (data.session) {
          // Set user in store
          setUser({
            id: data.session.user.id,
            email: data.session.user.email || '',
            role: 'admin',
          });

          // Redirect to dashboard
          router.push('/dashboard');
        } else {
          router.push('/login?error=No session found');
        }
      } catch (err) {
        console.error('Callback error:', err);
        router.push('/login?error=Something went wrong');
      }
    };

    handleCallback();
  }, [router, setUser]);

  return (
    <div className="min-h-screen bg-blue-600 flex items-center justify-center">
      <div className="text-white text-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-white mx-auto mb-4"></div>
        <p className="text-lg">Signing you in...</p>
      </div>
    </div>
  );
}
