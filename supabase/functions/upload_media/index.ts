// functions/upload_media/index.ts
import { serve } from "https://deno.land/std@0.191.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

if (!SUPABASE_URL || !SERVICE_ROLE) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY env vars");
}

const supabase = createClient(SUPABASE_URL!, SERVICE_ROLE!, {
  auth: { persistSession: false },
});

serve(async (req: Request) => {
  try {
    const payload = await req.json();
    const fileBase64 = payload.fileBase64;
    const bucket = payload.bucket ?? "chat-media";
    const path = payload.path ?? payload.fileName ?? `uploads/${Date.now()}`;

    if (!fileBase64) {
      return new Response(JSON.stringify({ error: "fileBase64 is required" }), { status: 400 });
    }

    // Decode base64 into Uint8Array
    const binaryString = atob(fileBase64);
    const len = binaryString.length;
    const bytes = new Uint8Array(len);
    for (let i = 0; i < len; i++) bytes[i] = binaryString.charCodeAt(i);

    // Upload
    const { error: uploadErr } = await supabase.storage.from(bucket).upload(path, bytes, {
      cacheControl: "3600",
      upsert: true,
    });

    if (uploadErr) {
      console.error("storage.upload error:", uploadErr);
      return new Response(JSON.stringify({ error: uploadErr.message }), { status: 500 });
    }

    // Get public URL (works if bucket is public); otherwise create signed URL
    // Try getPublicUrl first
    const { data: publicData } = supabase.storage.from(bucket).getPublicUrl(path);
    let publicUrl = publicData?.publicUrl;

    if (!publicUrl) {
      // fallback: signed url (1 hour)
      const { data: signedData, error: signedErr } = await supabase.storage
        .from(bucket)
        .createSignedUrl(path, 60 * 60);
      if (signedErr) {
        console.error("createSignedUrl error:", signedErr);
        return new Response(JSON.stringify({ error: signedErr.message }), { status: 500 });
      }
      publicUrl = signedData?.signedUrl;
    }

    return new Response(JSON.stringify({ publicUrl }), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  } catch (err) {
    console.error("upload_media error:", err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});