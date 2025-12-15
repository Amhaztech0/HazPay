// functions/send-reply-mention-notification/index.ts
import { serve } from "https://deno.land/std@0.191.0/http/server.ts";

const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID")!;
const FIREBASE_PRIVATE_KEY = Deno.env.get("FIREBASE_PRIVATE_KEY")!;
const FIREBASE_CLIENT_EMAIL = Deno.env.get("FIREBASE_CLIENT_EMAIL")!;

interface NotificationPayload {
  fcm_token: string;
  status_id: string;
  mentioner_name: string;
  content: string;
}

// Get Firebase access token
async function getFirebaseAccessToken(): Promise<string> {
  try {
    const jwtPayload = {
      iss: FIREBASE_CLIENT_EMAIL,
      sub: FIREBASE_CLIENT_EMAIL,
      aud: "https://oauth2.googleapis.com/token",
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 3600,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
    };

    const header = {
      alg: "RS256",
      typ: "JWT",
    };

    // Import the private key
    const key = await crypto.subtle.importKey(
      "pkcs8",
      new TextEncoder().encode(
        FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n")
      ),
      {
        name: "RSASSA-PKCS1-v1_5",
        hash: "SHA-256",
      },
      false,
      ["sign"]
    );

    // Create JWT
    const headerEncoded = btoa(JSON.stringify(header));
    const payloadEncoded = btoa(JSON.stringify(jwtPayload));
    const signatureData = new TextEncoder().encode(
      `${headerEncoded}.${payloadEncoded}`
    );

    const signature = await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      signatureData
    );

    const signatureEncoded = btoa(
      String.fromCharCode(...new Uint8Array(signature))
    );

    const jwt = `${headerEncoded}.${payloadEncoded}.${signatureEncoded}`;

    // Exchange JWT for access token
    const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
    });

    const tokenData = await tokenResponse.json();
    return tokenData.access_token;
  } catch (error) {
    console.error("Error getting Firebase access token:", error);
    throw error;
  }
}

// Send FCM notification
async function sendFCMNotification(
  fcmToken: string,
  statusId: string,
  mentionerName: string,
  content: string
): Promise<boolean> {
  try {
    const accessToken = await getFirebaseAccessToken();

    const message = {
      message: {
        token: fcmToken,
        data: {
          type: "status_reply",
          status_id: statusId,
          mentioner_name: mentionerName,
          content: content,
          notification_type: "status_reply_mention",
        },
        notification: {
          title: `${mentionerName} mentioned you in a reply`,
          body: content,
        },
      },
    };

    console.log("📤 Sending FCM message...");
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify(message),
      }
    );

    console.log(`📊 FCM Response status: ${response.status}`);

    if (!response.ok) {
      const errorData = await response.text();
      console.error("❌ FCM send error:", response.status, errorData);
      return false;
    }

    console.log("✅ FCM mention notification sent successfully");
    return true;
  } catch (error) {
    console.error("❌ Error sending FCM notification:", error);
    return false;
  }
}

serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    const payload: NotificationPayload = await req.json();

    const { fcm_token, status_id, mentioner_name, content } = payload;

    console.log("📤 Received mention notification request:");
    console.log(`   - statusId: ${status_id}`);
    console.log(`   - mentionerName: ${mentioner_name}`);
    console.log(`   - fcmToken: ${fcm_token?.substring(0, 20)}...`);

    if (!fcm_token || !status_id || !mentioner_name) {
      console.error("❌ Missing required fields:", {
        fcm_token: !!fcm_token,
        status_id: !!status_id,
        mentioner_name: !!mentioner_name,
      });
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400 }
      );
    }

    console.log("🔐 Getting Firebase access token...");
    const success = await sendFCMNotification(
      fcm_token,
      status_id,
      mentioner_name,
      content
    );

    if (success) {
      console.log("✅ FCM mention notification sent successfully");
      return new Response(
        JSON.stringify({
          success: true,
          message: "Notification sent successfully",
        }),
        { status: 200 }
      );
    } else {
      console.error("❌ Failed to send FCM mention notification");
      return new Response(
        JSON.stringify({
          success: false,
          message: "Failed to send notification",
        }),
        { status: 500 }
      );
    }
  } catch (error) {
    console.error("❌ Error in send-reply-mention-notification:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500 }
    );
  }
});
