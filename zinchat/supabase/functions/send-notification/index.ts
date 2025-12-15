// Supabase Edge Function: send-notification
// Location: supabase/functions/send-notification/index.ts
// Sends push notifications via Firebase Cloud Messaging V1 API

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create } from "https://deno.land/x/djwt@v2.8/mod.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface SendNotificationRequest {
  type: "direct_message" | "server_message";
  userId: string; // Recipient user ID
  messageId: string;
  senderId: string;
  senderName: string;
  content: string;
  chatId?: string; // For direct messages
  serverId?: string; // For server messages
}

// Generate Firebase access token from service account
async function getAccessToken() {
  const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!);
  
  const now = Math.floor(Date.now() / 1000);
  const expiry = now + 3600;

  const header = {
    alg: "RS256",
    typ: "JWT",
  };

  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: expiry,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  };

  // Import the private key - properly decode the base64 PEM format
  const privateKeyPem = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\\n/g, "") // Handle escaped newlines from JSON
    .replace(/\n/g, "")  // Handle actual newlines
    .replace(/\s/g, ""); // Remove any whitespace

  // Decode base64 to binary
  const binaryDer = Uint8Array.from(atob(privateKeyPem), c => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"]
  );

  const jwt = await create(header, payload, key);

  // Exchange JWT for access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Initialize Supabase client
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!);
    const projectId = serviceAccount.project_id;

    // Parse request
    const payload: SendNotificationRequest = await req.json();
    
    console.log('Sending notification to user:', payload.userId)

    // Get recipient's FCM tokens
    const { data: tokens, error } = await supabase
      .from("user_tokens")
      .select("fcm_token, platform")
      .eq("user_id", payload.userId);

    if (error || !tokens || tokens.length === 0) {
      console.log('No FCM tokens found for user:', payload.userId)
      return new Response(
        JSON.stringify({ success: false, error: "No FCM tokens found" }),
        { 
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    console.log(`Found ${tokens.length} token(s) for user`)

    // Get Firebase access token
    const accessToken = await getAccessToken();

    // Send to all FCM tokens
    const results = [];
    for (const token of tokens) {
      try {
        const response = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${accessToken}`
            },
            body: JSON.stringify({
              message: {
                token: token.fcm_token,
                notification: {
                  title: payload.senderName,
                  body: payload.content,
                },
                android: {
                  priority: 'high',
                  notification: {
                    sound: 'default',
                    channel_id: 'zinchat_messages',
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                  }
                },
                data: {
                  type: payload.type,
                  message_id: payload.messageId,
                  sender_id: payload.senderId,
                  sender_name: payload.senderName,
                  content: payload.content,
                  chat_id: payload.chatId || "",
                  server_id: payload.serverId || "",
                }
              }
            })
          }
        )

        const result = await response.json()
        console.log('FCM response:', result)

        results.push({
          token: token.fcm_token.substring(0, 20) + '...',
          success: response.ok,
          result
        });
      } catch (err) {
        console.error(`Failed to send to ${token.fcm_token}:`, err);
        results.push({
          token: token.fcm_token.substring(0, 20) + '...',
          success: false,
          error: (err as Error).message,
        });
      }
    }

    const successCount = results.filter((r) => r.success).length

    return new Response(
      JSON.stringify({
        success: true,
        message: `Sent to ${successCount}/${results.length} device(s)`,
        sent: successCount,
        failed: results.length - successCount,
        results,
      }),
      { 
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );
  } catch (err) {
    console.error("Error in send-notification function:", err);
    return new Response(
      JSON.stringify({ success: false, error: (err as Error).message }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );
  }
});

/* SETUP INSTRUCTIONS (Firebase V1 API):

1. Set Firebase Service Account as environment variable:
   
   Go to Supabase Dashboard → Edge Functions → Configuration → Secrets
   Add secret: FIREBASE_SERVICE_ACCOUNT
   
   Value should be the ENTIRE JSON content of your Firebase service account file:
   {
     "type": "service_account",
     "project_id": "your-project-id",
     "private_key_id": "...",
     "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
     "client_email": "...",
     ...
   }
   
   To get Firebase Service Account JSON:
   - Go to Firebase Console → Project Settings → Service Accounts
   - Click "Generate new private key"
   - Save the JSON file
   - Copy the ENTIRE contents and paste as the secret value

2. Deploy function:
   npx supabase functions deploy send-notification --no-verify-jwt

3. Test function:
   curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/send-notification \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_ANON_KEY" \
     -d '{
       "type": "direct_message",
       "userId": "recipient-user-id",
       "messageId": "msg-123",
       "senderId": "sender-user-id",
       "senderName": "John Doe",
       "content": "Hello! This is a test message",
       "chatId": "chat-123"
     }'

4. Call from Flutter app when sending a message:

   // In chat_service.dart or message_service.dart
   import 'package:supabase_flutter/supabase_flutter.dart';
   
   Future<void> sendMessageWithNotification({
     required String recipientId,
     required String messageId,
     required String content,
     String? chatId,
     String? serverId,
   }) async {
     final currentUser = supabase.auth.currentUser;
     final profile = await supabase
       .from('profiles')
       .select('full_name')
       .eq('id', currentUser!.id)
       .single();

     // Send notification via Edge Function
     await supabase.functions.invoke('send-notification', body: {
       'type': chatId != null ? 'direct_message' : 'server_message',
       'userId': recipientId,
       'messageId': messageId,
       'senderId': currentUser.id,
       'senderName': profile['full_name'] ?? 'Someone',
       'content': content,
       if (chatId != null) 'chatId': chatId,
       if (serverId != null) 'serverId': serverId,
     });
   }

*/
