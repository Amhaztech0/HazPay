'use client';

import { useEffect, useState, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { useAuthStore } from '@/store/auth';
import { supabase, isSupabaseReady } from '@/lib/supabase';

interface ProtectedLayoutProps {
  children: React.ReactNode;
}

export function ProtectedLayout({ children }: ProtectedLayoutProps) {
  const router = useRouter();
  const { user, setUser } = useAuthStore();
  const [isLoading, setIsLoading] = useState(true);
  const [isClientReady, setIsClientReady] = useState(false);
  const hasCheckedAuth = useRef(false);

  // First, wait for client-side hydration
  useEffect(() => {
    setIsClientReady(true);
  }, []);

  useEffect(() => {
    // Don't run on server or before client is ready
    if (!isClientReady) return;
    
    // Prevent duplicate auth checks
    if (hasCheckedAuth.current) return;
    hasCheckedAuth.current = true;

    let isMounted = true;
    let timeoutId: NodeJS.Timeout;

    const checkAuth = async () => {
      try {
        // Check if Supabase is ready
        if (!isSupabaseReady()) {
          console.warn('Supabase not ready, waiting...');
          // Retry after a short delay
          setTimeout(() => {
            if (isMounted) {
              hasCheckedAuth.current = false; // Allow retry
              setIsClientReady(prev => !prev); // Trigger re-check
            }
          }, 500);
          return;
        }

        const { data, error } = await supabase.auth.getSession();
        
        if (error) {
          console.error('Auth error:', error);
          if (isMounted) {
            router.push('/login');
          }
          return;
        }

        if (!data.session) {
          console.log('No session found, redirecting to login');
          if (isMounted) {
            router.push('/login');
          }
          return;
        }

        // Set user in store
        if (isMounted) {
          setUser({
            id: data.session.user.id,
            email: data.session.user.email || '',
            role: 'admin',
          });
          setIsLoading(false);
        }
      } catch (error) {
        console.error('Auth check failed:', error);
        if (isMounted) {
          router.push('/login');
        }
      }
    };

    // Set timeout to prevent infinite loading - redirect to login after 8 seconds
    timeoutId = setTimeout(() => {
      if (isMounted && isLoading) {
        console.warn('Auth check timeout, redirecting to login');
        setIsLoading(false);
        router.push('/login');
      }
    }, 8000);

    checkAuth();

    // Subscribe to auth changes
    const { data: listener } = supabase.auth.onAuthStateChange((event: string, session: unknown) => {
      if (!session) {
        if (isMounted) {
          setUser(null);
          router.push('/login');
        }
      }
    });

    return () => {
      isMounted = false;
      clearTimeout(timeoutId);
      listener?.subscription?.unsubscribe();
    };
  }, [isClientReady, router, setUser, isLoading]);

  // Show loading while checking auth (only on client)
  if (!isClientReady || isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-[var(--color-gray-50)]">
        <div className="text-center">
          <div className="inline-block animate-spin rounded-full h-8 w-8 border-4 border-[var(--color-primary)] border-t-transparent mb-4"></div>
          <div className="text-lg text-[var(--color-text-secondary)]">Loading dashboard...</div>
        </div>
      </div>
    );
  }

  return <>{children}</>;
}
