import { createClient } from '@supabase/supabase-js';

// Read env vars (may be undefined during server-side build)
export const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || '';
export const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || '';

// Lazily create the client only in the browser to avoid prerender/build-time errors
let _supabase: any = null;
if (typeof window !== 'undefined' && SUPABASE_URL && SUPABASE_ANON_KEY) {
	_supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
}

// Export as `any` to avoid strict table-payload typings (prevents TS `never` on .update())
// TODO: Replace `any` with a generated `Database` type and use `createClient<Database>(...)`.
export const supabase: any = _supabase;
