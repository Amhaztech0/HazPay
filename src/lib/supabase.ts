import { createClient, SupabaseClient } from '@supabase/supabase-js';

// Read env vars (may be undefined during server-side build)
export const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || '';
export const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || '';

// Lazily create the client only in the browser to avoid prerender/build-time errors
let _supabase: SupabaseClient | null = null;
if (typeof window !== 'undefined' && SUPABASE_URL && SUPABASE_ANON_KEY) {
	_supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
}

export const supabase = _supabase as unknown as ReturnType<typeof createClient>;
