'use client';

import { useEffect, ReactNode, useState } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@supabase/supabase-js';

interface AdminProtectionProps {
  children: ReactNode;
}

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

// Hardcoded admin emails for reliable access (fallback)
const ADMIN_EMAILS = ['yyounghaz@gmail.com'];

export function AdminProtection({ children }: AdminProtectionProps) {
  const router = useRouter();
  const [isAdmin, setIsAdmin] = useState<boolean | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let isMounted = true;

    const checkAdminStatus = async () => {
      try {
        // Get current user session
        const { data: { user }, error: userError } = await supabase.auth.getUser();

        if (!isMounted) return;

        if (userError || !user) {
          console.log('No user found, redirecting to login');
          router.replace('/login');
          return;
        }

        // First check: Is email in hardcoded admin list? (Reliable fallback)
        const userEmail = user.email?.toLowerCase();
        if (userEmail && ADMIN_EMAILS.includes(userEmail)) {
          console.log('Admin verified via hardcoded list:', userEmail);
          if (isMounted) {
            setIsAdmin(true);
            setLoading(false);
          }
          return;
        }

        // Second check: Try to verify via profiles table
        try {
          const { data: profile, error: profileError } = await supabase
            .from('profiles')
            .select('is_admin, email')
            .eq('id', user.id)
            .single();

          if (!isMounted) return;

          if (profileError) {
            console.log('Profile query failed, checking admin_emails table');
            // Fallback: Check admin_emails table directly
            const { data: adminEmail } = await supabase
              .from('admin_emails')
              .select('email')
              .eq('email', userEmail)
              .eq('is_active', true)
              .single();

            if (adminEmail) {
              console.log('Admin verified via admin_emails table');
              setIsAdmin(true);
              setLoading(false);
              return;
            }
          } else if (profile?.is_admin) {
            console.log('Admin verified via profile:', profile.email);
            setIsAdmin(true);
            setLoading(false);
            return;
          }
        } catch (dbError) {
          console.error('Database check error:', dbError);
        }

        // Not admin
        console.log('User is not admin, redirecting');
        if (isMounted) {
          setIsAdmin(false);
          router.replace('/login');
        }
      } catch (error) {
        console.error('Admin check error:', error);
        if (isMounted) {
          router.replace('/login');
        }
      }
    };

    checkAdminStatus();

    return () => {
      isMounted = false;
    };
  }, [router]);

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-gray-900">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto mb-4"></div>
          <p className="text-gray-400">Verifying access...</p>
        </div>
      </div>
    );
  }

  if (isAdmin === false) {
    return null;
  }

  return <>{children}</>;
}
