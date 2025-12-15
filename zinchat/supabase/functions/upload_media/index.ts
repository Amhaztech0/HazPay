import { serve } from "https://deno.land/std@0.201.0/http/server.ts";
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  console.error('SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is not set');
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response('Method not allowed', { status: 405 });
  }

  const contentType = req.headers.get('content-type') || '';
  let bucket = 'chat-media';
  let path = `${Date.now()}`;
  let bytes: Uint8Array | null = null;

  try {
    if (contentType.includes('application/json')) {
      const body = await req.json();
      const fileBase64 = body.fileBase64;
      if (!fileBase64) {
        return new Response(JSON.stringify({ error: 'fileBase64 is required' }), { status: 400, headers: { 'content-type': 'application/json' } });
      }
      // Decode base64 to bytes
      const binaryString = atob(fileBase64);
      const len = binaryString.length;
      const u8 = new Uint8Array(len);
      for (let i = 0; i < len; i++) u8[i] = binaryString.charCodeAt(i);
      bytes = u8;
      const fileName = body.fileName || path;
      bucket = body.bucket || bucket;
      path = body.path || fileName;
    } else {
      // Support multipart/form-data as well
      const form = await req.formData();
      const file = form.get('file') as File | null;
      if (!file) {
        return new Response(JSON.stringify({ error: 'file is required' }), { status: 400, headers: { 'content-type': 'application/json' } });
      }
      const arrayBuffer = await file.arrayBuffer();
      bytes = new Uint8Array(arrayBuffer);
      const fileName = (form.get('fileName') as string) || path;
      bucket = (form.get('bucket') as string) || bucket;
      path = (form.get('path') as string) || fileName;
    }

    if (!bytes) {
      return new Response(JSON.stringify({ error: 'No file bytes to upload' }), { status: 400, headers: { 'content-type': 'application/json' } });
    }

    // Upload using service role (bypasses RLS)
    const { data, error } = await supabase.storage.from(bucket).upload(path, bytes, { upsert: true });
    if (error) {
      console.error('Supabase storage upload error', error);
      return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { 'content-type': 'application/json' } });
    }

    const { data: urlData } = supabase.storage.from(bucket).getPublicUrl(path);
    const publicUrl = urlData?.publicUrl || null;

    return new Response(JSON.stringify({ publicUrl }), { status: 200, headers: { 'content-type': 'application/json' } });
  } catch (err: any) {
    console.error('Function error', err);
    return new Response(JSON.stringify({ error: err?.message || String(err) }), { status: 500, headers: { 'content-type': 'application/json' } });
  }
});
