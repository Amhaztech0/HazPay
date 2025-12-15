// Payscribe API - Buy Data Edge Function
// Replaces Amigo API with Payscribe for secure data purchases
// deno-lint-ignore=no-unknown-variable
// @ts-ignore - std imports work with deno.json import map in Supabase
import { serve } from "https://deno.land/std@0.191.0/http/server.ts";

interface BuyDataRequest {
  network: number; // 1=MTN, 2=GLO, 3=Airtel, 4=9Mobile, 5=SMILE
  mobile_number: string;
  plan: string; // Payscribe plan ID (e.g., "PSPLAN_531")
  is_ported_number?: boolean;
  idempotency_key?: string;
  user_id?: string;
}

interface PricingInfo {
  sell_price: number;
  cost_price: number;
  plan_name: string;
  payscribe_plan_id: string;
}

interface PayscribeResponse {
  status: boolean;
  description?: string;
  message?: {
    details?: {
      trans_id?: string;
      transaction_status?: string;
      amount?: number;
      total_charge?: number;
    };
  };
  error?: string;
}

interface ApiResponse {
  success: boolean;
  data?: {
    reference: string;
    message: string;
    network: number;
    plan: number;
    amount_charged: number;
    status: string;
    sell_price?: number;
    cost_price?: number;
    profit?: number;
  };
  error?: {
    code: string;
    message: string;
    details?: string;
  };
}

// Helper to get Payscribe environment and API key
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
  
  if (!apiKey) {
    throw new Error(
      payscribeEnv === "production"
        ? "PAYSCRIBE_API_KEY_PROD not configured in Supabase secrets"
        : "PAYSCRIBE_API_KEY not configured in Supabase secrets"
    );
  }
  
  // Log the API key (masked for security - show first 10 and last 5 chars)
  const masked = apiKey.substring(0, 10) + "***" + apiKey.substring(apiKey.length - 5);
  console.log(`🔐 Using ${payscribeEnv.toUpperCase()} environment`);
  console.log(`🔐 API Key loaded from secrets: ${masked} (length: ${apiKey.length})`);
  console.log(`🔐 Base URL: ${baseUrl}`);
  
  return {
    env: payscribeEnv,
    url: baseUrl,
    key: apiKey,
  };
}

// Helper to get pricing info from pricing table by payscribe_plan_id
async function getPricingInfo(payscribePlanId: string, networkId: number): Promise<PricingInfo> {
  try {
    const supabaseUrl = (globalThis as any).Deno?.env?.get?.("SUPABASE_URL");
    const supabaseKey = (globalThis as any).Deno?.env?.get?.("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseKey) {
      throw new Error("Supabase configuration not found");
    }

    const url = `${supabaseUrl}/rest/v1/pricing?payscribe_plan_id=eq.${payscribePlanId}&network_id=eq.${networkId}&select=*`;
    console.log(`🔍 Fetching pricing from: ${url}`);

    const response = await fetch(url, {
      method: "GET",
      headers: {
        apikey: supabaseKey,
        Authorization: `Bearer ${supabaseKey}`,
        "Content-Type": "application/json",
      },
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Failed to fetch pricing: ${response.statusText} - ${errorText}`);
    }

    const data = await response.json();
    console.log(`📋 Pricing query returned: ${JSON.stringify(data)}`);

    if (!data || data.length === 0) {
      throw new Error(`No pricing found for payscribe_plan_id=${payscribePlanId}, network_id=${networkId}`);
    }

    const pricing = data[0];
    console.log(`✅ Found pricing: sell_price=${pricing.sell_price}, cost_price=${pricing.cost_price}, payscribe_plan_id=${pricing.payscribe_plan_id}`);
    
    return {
      sell_price: parseFloat(pricing.sell_price),
      cost_price: parseFloat(pricing.cost_price),
      plan_name: pricing.plan_name,
      payscribe_plan_id: pricing.payscribe_plan_id,
    };
  } catch (error) {
    console.error("❌ getPricingInfo error:", error);
    throw error;
  }
}

// Helper to update transaction with pricing info
async function updateTransactionPricing(
  transactionId: string,
  sellPrice: number,
  costPrice: number,
  profit: number
): Promise<void> {
  try {
    const supabaseUrl = (globalThis as any).Deno?.env?.get?.("SUPABASE_URL");
    const supabaseKey = (globalThis as any).Deno?.env?.get?.("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseKey) {
      throw new Error("Supabase configuration not found");
    }

    const response = await fetch(
      `${supabaseUrl}/rest/v1/hazpay_transactions?id=eq.${transactionId}`,
      {
        method: "PATCH",
        headers: {
          apikey: supabaseKey,
          Authorization: `Bearer ${supabaseKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          sell_price: sellPrice,
          cost_price: costPrice,
          profit: profit,
        }),
      }
    );

    if (!response.ok) {
      console.error(`Failed to update transaction pricing: ${response.statusText}`);
    }
  } catch (error) {
    console.error("updateTransactionPricing error:", error);
    // Don't throw - this is auxiliary
  }
}

// Validate request payload
function validatePayload(body: unknown): BuyDataRequest {
  console.log(`🔍 validatePayload received: ${JSON.stringify(body)}`);
  
  if (!body || typeof body !== "object") {
    throw new Error("Invalid request body");
  }

  const req = body as Record<string, unknown>;

  // Validate network
  console.log(`  → network=${req.network} (type: ${typeof req.network})`);
  if (typeof req.network !== "number" || ![1, 2, 3, 4, 5].includes(req.network)) {
    throw new Error(`Invalid network: got ${req.network} (type: ${typeof req.network}). Must be 1 (MTN), 2 (GLO), 3 (Airtel), 4 (9Mobile), or 5 (SMILE)`);
  }

  // Validate mobile_number
  console.log(`  → mobile_number=${req.mobile_number} (type: ${typeof req.mobile_number}, length: ${String(req.mobile_number).length})`);
  // Accept both local (10-11 digits) and international (12-13 digits with 234 prefix) formats
  const phoneRegex = /^(?:\d{10,11}|234\d{10})$/;
  if (typeof req.mobile_number !== "string" || !phoneRegex.test(req.mobile_number)) {
    throw new Error(`Invalid mobile_number: got "${req.mobile_number}" (type: ${typeof req.mobile_number}). Must be 10-11 digits (local: 08012345678) or 12 digits (international: 2348012345678)`);
  }

  // Validate plan
  console.log(`  → plan=${req.plan} (type: ${typeof req.plan})`);
  if (typeof req.plan !== "string" || req.plan.trim().length === 0) {
    throw new Error(`Invalid plan: got "${req.plan}" (type: ${typeof req.plan}). Must be a non-empty string (e.g., 'PSPLAN_531')`);
  }

  return {
    network: req.network,
    mobile_number: req.mobile_number,
    plan: req.plan,
    is_ported_number: typeof req.is_ported_number === "boolean" ? req.is_ported_number : false,
    idempotency_key: typeof req.idempotency_key === "string" ? req.idempotency_key : undefined,
    user_id: typeof req.user_id === "string" ? req.user_id : undefined,
  };
}

// Map Payscribe errors to user-friendly messages
function mapPayscribeError(error: string, description: string): { code: string; message: string; details?: string } {
  const errorMap: Record<string, { code: string; message: string }> = {
    invalid_number: {
      code: "INVALID_NUMBER",
      message: "The mobile number provided is invalid.",
    },
    insufficient_balance: {
      code: "INSUFFICIENT_BALANCE",
      message: "Insufficient balance in Payscribe account.",
    },
    invalid_plan: {
      code: "PLAN_NOT_AVAILABLE",
      message: "Selected plan is not available for this network.",
    },
    network_error: {
      code: "NETWORK_ERROR",
      message: "Unable to process request. Please try again.",
    },
  };

  if (errorMap[error]) {
    return { ...errorMap[error], details: description };
  }

  return {
    code: "PURCHASE_FAILED",
    message: description || "Data purchase failed. Please try again.",
  };
}

// Main handler
serve(async (req: Request) => {
  // Check if this is an IP detection request
  const url = new URL(req.url);
  if (url.searchParams.has("check-ip")) {
    try {
      const ipResponse = await fetch("https://ifconfig.me");
      const ip = await ipResponse.text();
      console.log(`🌐 Supabase outbound IP: ${ip}`);
      return new Response(
        JSON.stringify({
          success: true,
          message: "Found Supabase outbound IP",
          ip: ip.trim(),
          note: "Whitelist this IP in Payscribe dashboard",
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    } catch (error) {
      console.error("IP detection error:", error);
      return new Response(
        JSON.stringify({
          success: false,
          error: "Could not determine IP",
          details: error instanceof Error ? error.message : "Unknown error",
        }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }
  }

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
    // Parse and validate request
    let payload: BuyDataRequest;
    try {
      const body = await req.json();
      console.log(`📥 Raw request body: ${JSON.stringify(body)}`);
      payload = validatePayload(body);
    } catch (e) {
      const errorMessage = e instanceof Error ? e.message : String(e);
      console.error(`❌ Validation error: ${errorMessage}`);
      console.error(`❌ Raw request text: ${await req.text().catch(() => "unable to read")}`);
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

    // Get API keys and environment config
    const payscribeConfig = getPayscribeEnvironment();
    const payscribeApiKey = payscribeConfig.key;
    const payscribeBaseUrl = payscribeConfig.url;

    // Get pricing info
    let pricingInfo: PricingInfo;
    try {
      pricingInfo = await getPricingInfo(payload.plan, payload.network);
    } catch (e) {
      const errorMsg = e instanceof Error ? e.message : String(e);
      return new Response(
        JSON.stringify({
          success: false,
          error: {
            code: "PRICING_NOT_FOUND",
            message: "Pricing not configured for this plan.",
            details: errorMsg,
          },
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Build headers for Payscribe API
    const payscribeHeaders: Record<string, string> = {
      "Authorization": `Bearer ${payscribeApiKey}`, // Payscribe requires Bearer prefix
      "Content-Type": "application/json",
    };

    // Map network to provider code
    const providerCodeMap: Record<number, string> = {
      1: "mtn", // MTN
      2: "glo", // GLO
      3: "airtel", // Airtel
      4: "9mobile", // 9Mobile
      5: "smile", // SMILE
    };

    const providerCode = providerCodeMap[payload.network];
    if (!providerCode) {
      throw new Error(`Unknown network: ${payload.network}`);
    }

    // Convert international format (2348012345678) to local format (08012345678) if needed
    let localNumber = payload.mobile_number;
    if (payload.mobile_number.startsWith("234")) {
      // Remove "234" prefix and add "0"
      localNumber = "0" + payload.mobile_number.slice(3);
      console.log(`📞 Converted international number ${payload.mobile_number} to local format ${localNumber}`);
    }

    console.log(`📞 Calling Payscribe API with: network=${providerCode}, plan=${pricingInfo.payscribe_plan_id}, recipient=${localNumber}`);

    // Log headers being sent (mask the token)
    const maskedAuth = payscribeHeaders.Authorization?.substring(0, 15) + "***" + payscribeHeaders.Authorization?.substring(payscribeHeaders.Authorization.length - 5);
    console.log(`🔐 Request headers: Authorization=${maskedAuth}, Content-Type=${payscribeHeaders["Content-Type"]}`);

    // Call Payscribe API - Data Vending endpoint
    const payscribeUrl = `${payscribeBaseUrl}/data/vend`;
    console.log(`🌐 Calling: ${payscribeUrl}`);
    
    const payscribeResponse = await fetch(payscribeUrl, {
      method: "POST",
      headers: payscribeHeaders,
      body: JSON.stringify({
        network: providerCode,
        recipient: localNumber,
        plan: pricingInfo.payscribe_plan_id,
        ref: payload.idempotency_key || payload.user_id || "auto-generated",
      }),
    });

    // Log raw response for debugging
    const responseText = await payscribeResponse.text();
    console.log(`📡 Raw Payscribe API response (${payscribeResponse.status}): ${responseText}`);
    
    let payscribeData: PayscribeResponse;
    try {
      payscribeData = JSON.parse(responseText);
    } catch (parseError) {
      console.error(`❌ Failed to parse Payscribe response as JSON. Raw response:\n${responseText}`);
      throw new Error(`Payscribe API returned invalid JSON. This might indicate IP blocking or authentication failure.`);
    }

    // Handle Payscribe response
    if (payscribeResponse.ok && payscribeData.status === true) {
      // Calculate profit
      const profit = pricingInfo.sell_price - pricingInfo.cost_price;
      console.log(`💰 Profit calculated: sell_price=${pricingInfo.sell_price}, cost_price=${pricingInfo.cost_price}, profit=${profit}`);

      // Update transaction with pricing if provided
      if (payload.transaction_id) {
        await updateTransactionPricing(
          payload.transaction_id,
          pricingInfo.sell_price,
          pricingInfo.cost_price,
          profit
        );
      }

      const successResponse: ApiResponse = {
        success: true,
        data: {
          reference: payscribeData.message?.details?.trans_id || payload.idempotency_key || "",
          message: payscribeData.description || "Data purchase successful",
          network: payload.network,
          plan: payload.plan,
          amount_charged: pricingInfo.sell_price,
          status: payscribeData.message?.details?.transaction_status || "success",
          sell_price: pricingInfo.sell_price,
          cost_price: pricingInfo.cost_price,
          profit: profit,
        },
      };

      return new Response(JSON.stringify(successResponse), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    } else {
      // Error response
      const errorCode = payscribeData.error || "unknown_error";
      const errorDescription = payscribeData.description || "Purchase failed";
      const errorDetails = (payscribeData as any).errors ? JSON.stringify((payscribeData as any).errors) : undefined;

      console.error(`❌ Payscribe error: ${errorCode} - ${errorDescription}${errorDetails ? ` - Details: ${errorDetails}` : ""}`);

      const mappedError = mapPayscribeError(errorCode, errorDescription);

      const errorResponse: ApiResponse = {
        success: false,
        error: {
          ...mappedError,
          details: errorDetails || mappedError.details,
        },
      };

      return new Response(JSON.stringify(errorResponse), {
        status: payscribeResponse.status === 200 ? 400 : payscribeResponse.status,
        headers: { "Content-Type": "application/json" },
      });
    }
  } catch (error) {
    console.error("buyData function error:", error);

    const errorResponse: ApiResponse = {
      success: false,
      error: {
        code: "INTERNAL_ERROR",
        message: "An unexpected error occurred. Please try again later.",
        details: error instanceof Error ? error.message : "Unknown error",
      },
    };

    return new Response(JSON.stringify(errorResponse), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
