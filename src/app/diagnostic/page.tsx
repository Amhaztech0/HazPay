'use client';

import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';

interface ProfileData {
  is_admin?: boolean;
  email?: string;
}

interface DiagnosticResults {
  auth?: {
    authenticated: boolean;
    userId?: string;
    email?: string;
  };
  profile?: {
    data: ProfileData | null;
    error?: string;
  };
  adminEmail?: {
    data: unknown;
    error?: string;
  };
  agentApplications?: {
    count: number;
    data: unknown;
    error?: string;
    errorCode?: string;
  };
  policies?: {
    available: boolean;
    error: unknown;
  };
  generalError?: string;
}

export default function DiagnosticPage() {
  const [results, setResults] = useState<DiagnosticResults>({});
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const runDiagnostics = async () => {
      const diagnostics: DiagnosticResults = {};

      try {
        // Test 1: Check authentication
        const { data: { session } } = await supabase.auth.getSession();
        diagnostics.auth = {
          authenticated: !!session,
          userId: session?.user?.id,
          email: session?.user?.email,
        };

        // Test 2: Check admin status
        if (session?.user?.id) {
          const { data: profile, error: profileError } = await supabase
            .from('profiles')
            .select('is_admin, email')
            .eq('id', session.user.id)
            .single();
          
          diagnostics.profile = {
            data: profile as ProfileData | null,
            error: profileError?.message,
          };

          // Test 3: Check admin_emails
          const { data: adminEmail, error: adminError } = await supabase
            .from('admin_emails')
            .select('*')
            .eq('email', session.user.email)
            .single();
          
          diagnostics.adminEmail = {
            data: adminEmail,
            error: adminError?.message,
          };
        }

        // Test 4: Try to fetch agent_applications
        const { data: apps, error: appsError } = await supabase
          .from('agent_applications')
          .select('*')
          .limit(5);
        
        diagnostics.agentApplications = {
          count: apps?.length || 0,
          data: apps,
          error: appsError?.message,
          errorCode: appsError?.code,
        };

        // Test 5: Check RLS policies (via public schema)
        const { error: policiesError } = await supabase
          .rpc('pg_policies_view', {})
          .catch(() => ({ data: null, error: 'RPC not available' }));
        
        diagnostics.policies = {
          available: !policiesError,
          error: policiesError,
        };

      } catch (err: unknown) {
        const error = err as Error;
        diagnostics.generalError = error.message;
      }

      setResults(diagnostics);
      setLoading(false);
    };

    runDiagnostics();
  }, []);

  if (loading) {
    return (
      <div className="p-8">
        <h1 className="text-2xl font-bold mb-4">Running Diagnostics...</h1>
      </div>
    );
  }

  return (
    <div className="p-8 space-y-6 bg-gray-900 min-h-screen text-white">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-3xl font-bold mb-2">System Diagnostics</h1>
        <p className="text-gray-400 mb-6">Debug information for agent applications issue</p>

        {/* Authentication */}
        <div className="bg-gray-800 rounded-lg p-6 mb-4">
          <h2 className="text-xl font-semibold mb-3 flex items-center gap-2">
            {results.auth?.authenticated ? '✅' : '❌'} Authentication
          </h2>
          <pre className="bg-gray-900 p-4 rounded overflow-auto text-sm">
            {JSON.stringify(results.auth, null, 2)}
          </pre>
        </div>

        {/* Profile */}
        <div className="bg-gray-800 rounded-lg p-6 mb-4">
          <h2 className="text-xl font-semibold mb-3 flex items-center gap-2">
            {results.profile?.data?.is_admin ? '✅' : '❌'} Profile & Admin Status
          </h2>
          <pre className="bg-gray-900 p-4 rounded overflow-auto text-sm">
            {JSON.stringify(results.profile, null, 2)}
          </pre>
        </div>

        {/* Admin Email */}
        <div className="bg-gray-800 rounded-lg p-6 mb-4">
          <h2 className="text-xl font-semibold mb-3 flex items-center gap-2">
            {results.adminEmail?.data ? '✅' : '❌'} Admin Email Whitelist
          </h2>
          <pre className="bg-gray-900 p-4 rounded overflow-auto text-sm">
            {JSON.stringify(results.adminEmail, null, 2)}
          </pre>
        </div>

        {/* Agent Applications */}
        <div className="bg-gray-800 rounded-lg p-6 mb-4">
          <h2 className="text-xl font-semibold mb-3 flex items-center gap-2">
            {(results.agentApplications?.count ?? 0) > 0 ? '✅' : '❌'} Agent Applications Access
          </h2>
          <div className="space-y-2">
            <p className="text-gray-300">
              Found: <span className="font-bold">{results.agentApplications?.count ?? 0}</span> applications
            </p>
            {results.agentApplications?.error && (
              <div className="bg-red-900/30 border border-red-700 rounded p-3">
                <p className="text-red-300 font-semibold">Error:</p>
                <p className="text-red-200">{results.agentApplications.error}</p>
                <p className="text-red-200 text-sm mt-1">Code: {results.agentApplications.errorCode}</p>
              </div>
            )}
          </div>
          <pre className="bg-gray-900 p-4 rounded overflow-auto text-sm mt-4">
            {JSON.stringify(results.agentApplications, null, 2)}
          </pre>
        </div>

        {/* General Error */}
        {results.generalError && (
          <div className="bg-red-900/30 border border-red-700 rounded-lg p-6">
            <h2 className="text-xl font-semibold mb-3">❌ General Error</h2>
            <p className="text-red-200">{results.generalError}</p>
          </div>
        )}

        {/* Instructions */}
        <div className="bg-blue-900/30 border border-blue-700 rounded-lg p-6 mt-6">
          <h2 className="text-xl font-semibold mb-3">🔍 What to Check</h2>
          <ul className="space-y-2 text-gray-300">
            <li>✅ <strong>Authentication:</strong> Should show authenticated = true</li>
            <li>✅ <strong>Profile:</strong> is_admin should be true</li>
            <li>✅ <strong>Admin Email:</strong> Should find your email in admin_emails table</li>
            <li>✅ <strong>Agent Applications:</strong> Should show count &gt; 0 without errors</li>
            <li className="mt-4 text-yellow-300">
              ⚠️ If any show errors, run <code className="bg-gray-800 px-2 py-1 rounded">CLEAN_RLS_FIX.sql</code> in Supabase
            </li>
          </ul>
        </div>
      </div>
    </div>
  );
}
