import { createClient, SupabaseClient } from '@supabase/supabase-js';

// Read env vars (may be undefined during server-side build)
export const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || '';
export const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || '';

// Create a singleton instance that's safely initialized
let _supabase: SupabaseClient | null = null;

/**
 * Get or create the Supabase client instance.
 * This ensures the client is only created once and only in the browser.
 */
function getSupabaseClient(): SupabaseClient | null {
  // Only create client in browser environment
  if (typeof window === 'undefined') {
    return null;
  }
  
  // Return existing instance if available
  if (_supabase) {
    return _supabase;
  }
  
  // Check for required env vars
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    console.warn('Supabase URL or Anon Key not configured');
    return null;
  }
  
  // Create and cache the client
  _supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
    },
  });
  
  return _supabase;
}

// Export the client getter - components should check for null
// Export as `any` to avoid strict table-payload typings (prevents TS `never` on .update())
// TODO: Replace `any` with a generated `Database` type and use `createClient<Database>(...)`.
export const supabase: any = {
  get auth() {
    const client = getSupabaseClient();
    if (!client) {
      // Return a mock auth object that returns empty/null values
      return {
        getSession: async () => ({ data: { session: null }, error: null }),
        onAuthStateChange: () => ({ data: { subscription: { unsubscribe: () => {} } } }),
        signInWithOtp: async () => ({ error: new Error('Supabase not initialized') }),
        verifyOtp: async () => ({ data: null, error: new Error('Supabase not initialized') }),
        signOut: async () => ({ error: null }),
      };
    }
    return client.auth;
  },
  from: (table: string) => {
    const client = getSupabaseClient();
    if (!client) {
      // Return a mock query builder that returns empty results
      return {
        select: () => ({
          eq: () => ({
            eq: () => ({
              order: () => ({
                limit: () => Promise.resolve({ data: [], error: null }),
              }),
              single: () => Promise.resolve({ data: null, error: null }),
              limit: () => Promise.resolve({ data: [], error: null }),
            }),
            order: () => ({
              limit: () => Promise.resolve({ data: [], error: null }),
            }),
            single: () => Promise.resolve({ data: null, error: null }),
            limit: () => Promise.resolve({ data: [], error: null }),
          }),
          order: () => ({
            limit: () => Promise.resolve({ data: [], error: null }),
          }),
          single: () => Promise.resolve({ data: null, error: null }),
          limit: () => Promise.resolve({ data: [], error: null }),
        }),
        insert: () => Promise.resolve({ data: null, error: null }),
        update: () => ({
          eq: () => Promise.resolve({ data: null, error: null }),
        }),
        delete: () => ({
          eq: () => Promise.resolve({ data: null, error: null }),
        }),
      };
    }
    return client.from(table);
  },
  rpc: (fn: string, params?: any) => {
    const client = getSupabaseClient();
    if (!client) {
      return Promise.resolve({ data: null, error: new Error('Supabase not initialized') });
    }
    return client.rpc(fn, params);
  },
};

// Export a function to check if Supabase is properly initialized
export function isSupabaseReady(): boolean {
  return getSupabaseClient() !== null;
}
