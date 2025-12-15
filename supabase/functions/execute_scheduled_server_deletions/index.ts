import { serve } from "https://deno.land/std@0.191.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  try {
    // Get environment variables
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    if (!supabaseUrl || !serviceRoleKey) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Missing Supabase credentials'
        }),
        { 
          status: 500,
          headers: { "Content-Type": "application/json" }
        }
      )
    }

    // Create Supabase client with service role (bypass RLS)
    const supabase = createClient(supabaseUrl, serviceRoleKey)

    // Call the RPC function to execute deletions
    const { data, error } = await supabase.rpc('execute_scheduled_server_deletions')

    if (error) {
      console.error('RPC Error:', error)
      return new Response(
        JSON.stringify({
          success: false,
          error: error.message
        }),
        { 
          status: 500,
          headers: { "Content-Type": "application/json" }
        }
      )
    }

    console.log('Deletion Result:', data)

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Scheduled server deletions executed',
        deleted_count: data?.deleted_count || 0
      }),
      { 
        status: 200,
        headers: { "Content-Type": "application/json" }
      }
    )

  } catch (err) {
    console.error('Function Error:', err)
    return new Response(
      JSON.stringify({
        success: false,
        error: err.message
      }),
      { 
        status: 500,
        headers: { "Content-Type": "application/json" }
      }
    )
  }
})
