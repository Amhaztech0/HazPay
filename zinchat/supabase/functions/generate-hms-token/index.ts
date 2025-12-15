// ===========================================================
// SUPABASE EDGE FUNCTION: generate-hms-token
// ===========================================================
// This function generates 100ms authentication tokens for users
// Deploy to: supabase/functions/generate-hms-token/index.ts
// ===========================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const HMS_APP_ACCESS_KEY = Deno.env.get('HMS_APP_ACCESS_KEY') || '69171bc9145cb4e8449b1a6e'
const HMS_APP_SECRET = Deno.env.get('HMS_APP_SECRET') || 'ibgzGtbFbko5Fkn8MV0rZ0e3oyU46hvZpG-_PEPH75-f40D2zewJo4foqslX1ILrdRed5mOnricZd7fjKBsenQXxNPBX1Xx2RCJZ8FSNuIRu609wE9bDXW_n2VpqO127HqUT2jF_B848MQNzMzKVHBsrzm0UhYlCla_aw6YOgoU='
const HMS_TEMPLATE_ID = Deno.env.get('HMS_TEMPLATE_ID')! // Your 100ms template ID

serve(async (req) => {
  try {
    // Verify user is authenticated
    const authHeader = req.headers.get('Authorization')!
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: userError } = await supabase.auth.getUser()
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // Get request body
    const { room_id, user_name } = await req.json()

    if (!room_id || !user_name) {
      return new Response(
        JSON.stringify({ error: 'room_id and user_name are required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Generate HMS auth token using management API
    // https://www.100ms.live/docs/server-side/v2/foundation/authentication-and-tokens
    const tokenPayload = {
      access_key: HMS_APP_ACCESS_KEY,
      room_id: room_id,
      user_id: user.id,
      role: 'guest', // or 'host', 'moderator' based on your needs
      type: 'app',
      version: 2,
      iat: Math.floor(Date.now() / 1000),
      nbf: Math.floor(Date.now() / 1000),
    }

    // Sign the JWT token with HMS secret
    const token = await generateHMSToken(tokenPayload, HMS_APP_SECRET)

    return new Response(
      JSON.stringify({ 
        token,
        room_id,
        user_id: user.id,
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      }
    )
  }
})

async function generateHMSToken(payload: any, secret: string): Promise<string> {
  // Simple JWT implementation for 100ms
  const encoder = new TextEncoder()
  
  const header = {
    alg: 'HS256',
    typ: 'JWT',
  }

  const base64urlHeader = btoa(JSON.stringify(header))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '')

  const base64urlPayload = btoa(JSON.stringify(payload))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '')

  const data = `${base64urlHeader}.${base64urlPayload}`
  
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  )

  const signature = await crypto.subtle.sign(
    'HMAC',
    key,
    encoder.encode(data)
  )

  const base64urlSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '')

  return `${data}.${base64urlSignature}`
}

// ===========================================================
// TO DEPLOY:
// ===========================================================
// 1. Install Supabase CLI: npm install -g supabase
// 2. Create the function: 
//    supabase functions new generate-hms-token
// 3. Copy this code to: supabase/functions/generate-hms-token/index.ts
// 4. Set secrets:
//    supabase secrets set HMS_APP_ACCESS_KEY=your_access_key
//    supabase secrets set HMS_APP_SECRET=your_secret
//    supabase secrets set HMS_TEMPLATE_ID=your_template_id
// 5. Deploy: 
//    supabase functions deploy generate-hms-token
// ===========================================================
