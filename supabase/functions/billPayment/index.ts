// Payscribe API - Bill Payment Edge Function v3-FIXED
// Handles electricity bills, cable subscriptions (GOTV, DSTV, Startimes)
// deno-lint-ignore=no-unknown-variable
// @ts-ignore - std imports work with deno.json import map in Supabase
import { serve } from "https://deno.land/std@0.191.0/http/server.ts";

interface BillPaymentRequest {
  bill_type: "electricity" | "cable";
  provider: string;
  meter_number?: string;
  meter_type?: string;
  account?: string;
  amount?: number;
  plan_id?: string;
  customer_name?: string;
  phone: string;
  email?: string;
  ref: string;
  month?: number;
}

interface ApiResponse {
  success: boolean;
  data?: {
    reference: string;
    message: string;
    bill_type: string;
    provider: string;
    amount_charged: number;
    status: string;
  };
  error?: {
    code: string;
    message: string;
    details?: string;
  };
}

function getPayscribeEnvironment(): { env: string; url: string; key: string } {
  const payscribeEnv = (globalThis as any).Deno?.env?.get?.("PAYSCRIBE_ENV") || "sandbox";
  let apiKey: string;
  let baseUrl: string;
  
  if (payscribeEnv === "production") {
    apiKey = (globalThis as any).Deno?.env?.get?.("PAYSCRIBE_API_KEY_PROD");
    baseUrl = "https://api.payscribe.ng/api/v1";
  } else {
    apiKey = (globalThis as any).Deno?.env?.get?.("PAYSCRIBE_API_KEY");
    baseUrl = "https://sandbox.payscribe.ng/api/v1";
  }
  
  if (!apiKey) throw new Error("API key not configured");
  const masked = apiKey.substring(0, 10) + "***" + apiKey.substring(apiKey.length - 5);
  console.log(`🔐 ${payscribeEnv.toUpperCase()}: ${masked}`);
  
  return { env: payscribeEnv, url: baseUrl, key: apiKey };
}

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ success: false, error: { code: "METHOD_NOT_ALLOWED", message: "POST only" } }), { status: 405, headers: { "Content-Type": "application/json" } });
  }

  try {
    const body = await req.json();
    console.log(`📥 Request: ${JSON.stringify(body)}`);
    
    const payload = body as BillPaymentRequest;

    if (!["electricity", "cable"].includes(payload.bill_type)) throw new Error("bill_type must be 'electricity' or 'cable'");
    if (!payload.phone || !payload.ref) throw new Error("phone and ref required");

    const config = getPayscribeEnvironment();
    const headers = { "Authorization": `Bearer ${config.key}`, "Content-Type": "application/json" };

    let url: string;
    let requestBody: any;

    if (payload.bill_type === "electricity") {
      console.log(`⚡ Electricity: ${payload.provider}, meter: ${payload.meter_number}`);
      url = `${config.url}/electricity/vend`;
      requestBody = {
        service: payload.provider,
        meter_number: payload.meter_number,
        meter_type: payload.meter_type || "prepaid",
        customer_name: payload.customer_name,
        amount: payload.amount || 1000,
        phone: payload.phone,
        email: payload.email,
        ref: payload.ref,
      };
    } else {
      console.log(`📺 Cable: ${payload.provider}, account: ${payload.account}`);
      
      if (!payload.plan_id) {
        throw new Error("plan_id is required for cable payments. Get it from PayScribe dashboard or documentation.");
      }
      
      url = `${config.url}/multichoice/vend`;
      requestBody = {
        service: payload.provider,
        account: payload.account,
        plan_id: payload.plan_id,
        customer_name: payload.customer_name,
        phone: payload.phone,
        email: payload.email,
        ref: payload.ref,
        month: payload.month || 1,
      };
    }

    console.log(`🌐 POST ${url}`);
    const payscribeResponse = await fetch(url, { method: "POST", headers, body: JSON.stringify(requestBody) });
    const responseText = await payscribeResponse.text();
    console.log(`📡 Response (${payscribeResponse.status}): ${responseText.substring(0, 200)}`);

    let payscribeData;
    try {
      payscribeData = JSON.parse(responseText);
    } catch (parseError) {
      console.error(`❌ Non-JSON response (likely 404): ${responseText.substring(0, 100)}`);
      throw new Error(`PayScribe API returned non-JSON (${payscribeResponse.status}). Endpoint may not exist or API key issue.`);
    }

    if (payscribeData.status === true) {
      return new Response(JSON.stringify({
        success: true,
        data: {
          reference: payscribeData.message?.details?.trans_id || payload.ref,
          message: payscribeData.description || "Success",
          bill_type: payload.bill_type,
          provider: payload.provider,
          amount_charged: payscribeData.message?.details?.amount || payload.amount || 0,
          status: "success",
        },
      }), { status: 200, headers: { "Content-Type": "application/json" } });
    } else {
      return new Response(JSON.stringify({
        success: false,
        error: { code: "PAYMENT_FAILED", message: payscribeData.description || "Failed" },
      }), { status: 400, headers: { "Content-Type": "application/json" } });
    }
  } catch (error) {
    console.error("Error:", error);
    return new Response(JSON.stringify({
      success: false,
      error: { code: "ERROR", message: error instanceof Error ? error.message : "Unknown error" },
    }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
