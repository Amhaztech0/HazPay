import { serve } from "https://deno.land/std@0.191.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Function to generate Google access token from service account
async function generateAccessToken(serviceAccount: any): Promise<string> {
  const header = {
    alg: "RS256",
    typ: "JWT",
  };

  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  // Encode header and payload
  const headerEncoded = btoa(JSON.stringify(header));
  const payloadEncoded = btoa(JSON.stringify(payload));
  const signatureInput = `${headerEncoded}.${payloadEncoded}`;

  // Sign with private key
  const encoder = new TextEncoder();
  const keyData = encoder.encode(serviceAccount.private_key);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    encoder.encode(signatureInput)
  );
  const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)));
  const jwtToken = `${signatureInput}.${signatureB64}`;

  // Exchange JWT for access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwtToken}`,
  });

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

interface ReplyMentionNotificationPayload {
  fcm_token: string;
  status_id: string;
  mentioner_name: string;
  content: string;
}

serve(async (req) => {
  try {
    // Get the request body
    const payload: ReplyMentionNotificationPayload = await req.json();
    const { fcm_token, status_id, mentioner_name, content } = payload;

    if (!fcm_token || !status_id || !mentioner_name) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Create the notification
    const title = `${mentioner_name} replied to your reply`;
    const body = content.substring(0, 100);

    // Create FCM message
    const fcmMessage = {
      message: {
        token: fcm_token,
        notification: {
          title,
          body,
        },
        data: {
          type: "status_reply",
          status_id,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            sound: "default",
            channel_id: "status_replies",
          },
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      },
    };

    // Get Firebase credentials from environment
    const firebaseServiceAccount = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");

    if (!firebaseServiceAccount) {
      console.error("Missing Firebase service account");
      return new Response(
        JSON.stringify({ error: "Firebase not configured" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // Parse service account
    let serviceAccount: any;
    try {
      serviceAccount = JSON.parse(firebaseServiceAccount);
    } catch (e) {
      console.error("Invalid Firebase service account JSON");
      return new Response(
        JSON.stringify({ error: "Invalid Firebase configuration" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // Generate access token from service account
    const accessToken = await generateAccessToken(serviceAccount);
    const projectId = serviceAccount.project_id;

    // Send to FCM
    const response = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify(fcmMessage),
    });

    if (!response.ok) {
      const error = await response.text();
      console.error("FCM Error:", error);
      return new Response(
        JSON.stringify({ error: "Failed to send FCM notification", details: error }),
        { status: response.status, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ success: true, message: "Notification sent" }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: String(error) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
