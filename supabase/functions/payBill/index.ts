// Payscribe API - Bills Payment Edge Function
// Handles electricity and cable bill payments
// deno-lint-ignore=no-unknown-variable
// @ts-ignore - std imports work with deno.json import map in Supabase
import { serve } from "https://deno.land/std@0.191.0/http/server.ts";

interface PayBillRequest {
  bill_type: "electricity" | "cable" | "internet";
  provider: string; // e.g., "ikedc", "mtn_cable", "dstv"
  account_number: string;
  customer_name?: string;
  amount: number;
  phone: string; // Now required
  ref: string; // Now required with auto-generated default
  user_id?: string;
}

interface PayscribeResponse {
  status: boolean;
  description?: string;
  message?: {
    details?: {
      trans_id?: string;
      transaction_status?: string;
      service?: string;
      token?: string;
      amount?: number;
    };
  };
  error?: string;
}

interface ApiResponse {
  success: boolean;
  data?: {
    reference: string;
    message: string;
    status: string;
    amount: number;
    provider: string;
    account_number: string;
    customer_name?: string;
  };
  error?: {
    code: string;
    message: string;
    details?: string;
  };
}

// Helper to get Payscribe API key
async function getPayscribeApiKey(): Promise<string> {
  const apiKey = (globalThis as any).Deno?.env?.get?.("PAYSCRIBE_API_KEY");
  if (!apiKey) {
    throw new Error("PAYSCRIBE_API_KEY not configured");
  }
  return apiKey;
}

// Validate request
function validatePayload(body: unknown): PayBillRequest {
  console.log(`🔍 validatePayload received: ${JSON.stringify(body)}`);
  
  if (!body || typeof body !== "object") {
    throw new Error("Invalid request body");
  }

  const req = body as Record<string, unknown>;

  // Validate bill_type
  console.log(`  → bill_type=${req.bill_type} (type: ${typeof req.bill_type})`);
  if (!req.bill_type || !["electricity", "cable", "internet"].includes(req.bill_type as string)) {
    throw new Error(`Invalid bill_type: got "${req.bill_type}". Must be "electricity", "cable", or "internet"`);
  }

  // Validate provider
  console.log(`  → provider=${req.provider} (type: ${typeof req.provider})`);
  if (typeof req.provider !== "string" || req.provider.length === 0) {
    throw new Error(`Invalid provider: got "${req.provider}" (type: ${typeof req.provider}). Must be non-empty string (e.g., "ikedc", "dstv")`);
  }

  // Validate account_number
  console.log(`  → account_number=${req.account_number} (type: ${typeof req.account_number})`);
  if (typeof req.account_number !== "string" || req.account_number.length === 0) {
    throw new Error(`Invalid account_number: got "${req.account_number}" (type: ${typeof req.account_number}). Must be non-empty string`);
  }

  // Validate amount
  console.log(`  → amount=${req.amount} (type: ${typeof req.amount})`);
  if (typeof req.amount !== "number" || req.amount <= 0) {
    throw new Error(`Invalid amount: got ${req.amount} (type: ${typeof req.amount}). Must be number > 0`);
  }

  // Validate phone (required by Payscribe)
  console.log(`  → phone=${req.phone} (type: ${typeof req.phone})`);
  if (typeof req.phone !== "string" || req.phone.length === 0) {
    throw new Error(`Invalid phone: got "${req.phone}" (type: ${typeof req.phone}). Must be non-empty string (required by Payscribe)`);
  }

  return {
    bill_type: req.bill_type as "electricity" | "cable" | "internet",
    provider: req.provider as string,
    account_number: req.account_number as string,
    customer_name: typeof req.customer_name === "string" ? req.customer_name : undefined,
    amount: req.amount as number,
    phone: req.phone as string,
    ref: typeof req.ref === "string" ? req.ref : `bill-${Date.now()}`,
    user_id: typeof req.user_id === "string" ? req.user_id : undefined,
  };
}

// Handle electricity bills (validate and vend)
async function handleElectricityBill(
  payload: PayBillRequest,
  apiKey: string
): Promise<PayscribeResponse> {
  // Map disco code to service name
  const discoServiceMap: Record<string, string> = {
    ikedc: "IKEDC",
    ekedc: "EKEDC",
    eedc: "EEDC",
    phedc: "PHEDC",
    aedc: "AEDC",
    ibedc: "IBEDC",
    kedco: "KEDCO",
    jed: "JED",
    kano: "KANO",
    kaduna: "KADUNA",
  };

  const service = discoServiceMap[payload.provider];
  if (!service) {
    throw new Error(`Unknown electricity provider: ${payload.provider}`);
  }

  // Determine meter type (prepaid or postpaid)
  // Simple heuristic: if meter starts with 0, it's prepaid
  const meterType = payload.account_number.startsWith("0") ? "prepaid" : "postpaid";

  console.log(`⚡ Processing electricity bill: ${service}, meter=${payload.account_number}, type=${meterType}, amount=${payload.amount}`);

  // Call Payscribe electricity vend endpoint
  const response = await fetch("https://sandbox.payscribe.ng/api/v1/electricity/vend", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      meter_number: payload.account_number,
      meter_type: meterType,
      amount: payload.amount,
      service: payload.provider, // Use provider code directly
      customer_name: payload.customer_name || "CUSTOMER",
      phone: payload.phone,
      ref: payload.ref,
    }),
  });

  return await response.json();
}

// Handle cable bills (DSTV, GOTV, Startimes)
async function handleCableBill(
  payload: PayBillRequest,
  apiKey: string
): Promise<PayscribeResponse> {
  // For cable, we need to use the plan_id from the account_number
  // This should be the cable package code (e.g., "ng_dstv_hdprme36")

  console.log(`📺 Processing cable bill: ${payload.provider}, plan=${payload.account_number}, amount=${payload.amount}`);

  // Call Payscribe cable subscription endpoint
  const response = await fetch("https://sandbox.payscribe.ng/api/v1/cable/vend", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      plan_id: payload.account_number, // Cable package ID
      smartcard_number: payload.customer_name || "", // Optional smart card
      amount: payload.amount,
      ref: payload.ref,
    }),
  });

  return await response.json();
}

// Map errors to user-friendly messages
function mapError(error: string, description: string): { code: string; message: string } {
  const errorMap: Record<string, { code: string; message: string }> = {
    invalid_meter: {
      code: "INVALID_ACCOUNT",
      message: "Invalid meter/account number provided.",
    },
    insufficient_balance: {
      code: "INSUFFICIENT_BALANCE",
      message: "Insufficient balance in Payscribe account.",
    },
    meter_not_found: {
      code: "ACCOUNT_NOT_FOUND",
      message: "Meter/Account number not found.",
    },
    invalid_plan: {
      code: "PLAN_NOT_AVAILABLE",
      message: "Selected plan is not available.",
    },
  };

  if (errorMap[error]) {
    return errorMap[error];
  }

  return {
    code: "BILL_PAYMENT_FAILED",
    message: description || "Bill payment failed. Please try again.",
  };
}

// Main handler
serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({
        success: false,
        error: { code: "METHOD_NOT_ALLOWED", message: "Only POST requests are allowed" },
      }),
      { status: 405, headers: { "Content-Type": "application/json" } }
    );
  }

  try {
    // Parse and validate
    let payload: PayBillRequest;
    try {
      const body = await req.json();
      payload = validatePayload(body);
    } catch (e) {
      const errorMessage = e instanceof Error ? e.message : String(e);
      console.error(`❌ Validation error: ${errorMessage}`);
      return new Response(
        JSON.stringify({
          success: false,
          error: {
            code: "INVALID_REQUEST",
            message: errorMessage,
          },
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const apiKey = await getPayscribeApiKey();
    let payscribeResponse: PayscribeResponse;

    // Route to appropriate handler
    if (payload.bill_type === "electricity") {
      payscribeResponse = await handleElectricityBill(payload, apiKey);
    } else if (payload.bill_type === "cable") {
      payscribeResponse = await handleCableBill(payload, apiKey);
    } else {
      throw new Error(`Unsupported bill type: ${payload.bill_type}`);
    }

    console.log(`📡 Payscribe response: ${JSON.stringify(payscribeResponse)}`);

    if (payscribeResponse.status === true) {
      const successResponse: ApiResponse = {
        success: true,
        data: {
          reference: payscribeResponse.message?.details?.trans_id || payload.ref || "",
          message: payscribeResponse.description || "Bill payment successful",
          status: payscribeResponse.message?.details?.transaction_status || "success",
          amount: payload.amount,
          provider: payload.provider,
          account_number: payload.account_number,
          customer_name: payload.customer_name,
        },
      };

      return new Response(JSON.stringify(successResponse), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    } else {
      const mappedError = mapError(payscribeResponse.error || "unknown", payscribeResponse.description || "");

      return new Response(
        JSON.stringify({
          success: false,
          error: mappedError,
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }
  } catch (error) {
    console.error("payBill error:", error);

    return new Response(
      JSON.stringify({
        success: false,
        error: {
          code: "INTERNAL_ERROR",
          message: "An unexpected error occurred.",
          details: error instanceof Error ? error.message : "Unknown error",
        },
      }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
