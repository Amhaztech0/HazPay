// deno-lint-ignore=no-unknown-variable
// @ts-ignore - std imports work with deno.json import map in Supabase
import { serve } from "https://deno.land/std@0.191.0/http/server.ts";

interface BuyDataRequest {
  network: number; // 1 = MTN, 2 = Glo
  mobile_number: string;
  plan: number;
  Ported_number: boolean;
  idempotency_key?: string;
  user_id?: string;
  transaction_id?: string;
}

interface PricingInfo {
  sell_price: number;
  cost_price: number;
  plan_name: string;
  amigo_plan_id: string;
}

interface AmigoResponse {
  success: boolean;
  reference?: string;
  message?: string;
  network?: number;
  plan?: number;
  amount_charged?: number;
  status?: string;
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

// Helper to get Amigo API key from secrets
async function getAmigoApiKey(): Promise<string> {
  const apiKey = (globalThis as any).Deno?.env?.get?.("AMIGO_API_KEY");
  if (!apiKey) {
    throw new Error("AMIGO_API_KEY not configured in Supabase secrets");
  }
  return apiKey;
}

// Helper to get pricing info from pricing table
async function getPricingInfo(planId: number, networkId: number): Promise<PricingInfo> {
  try {
    const supabaseUrl = (globalThis as any).Deno?.env?.get?.("SUPABASE_URL");
    const supabaseKey = (globalThis as any).Deno?.env?.get?.("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseKey) {
      throw new Error("Supabase configuration not found");
    }

    const url = `${supabaseUrl}/rest/v1/pricing?plan_id=eq.${planId}&network_id=eq.${networkId}&select=*`;
    console.log(`🔍 Fetching pricing from: ${url}`);
    console.log(`   Parameters: planId=${planId}, networkId=${networkId}`);

    const response = await fetch(url, {
      method: "GET",
      headers: {
        apikey: supabaseKey,
        Authorization: `Bearer ${supabaseKey}`,
        "Content-Type": "application/json",
      },
    });

    console.log(`📊 Pricing fetch response status: ${response.status}`);

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`❌ Pricing fetch failed: ${response.statusText} - ${errorText}`);
      throw new Error(`Failed to fetch pricing: ${response.statusText} - ${errorText}`);
    }

    const data = await response.json();
    console.log(`📋 Pricing query returned ${data.length} rows: ${JSON.stringify(data)}`);

    if (!data || data.length === 0) {
      console.error(`❌ No pricing found for plan_id=${planId}, network_id=${networkId}`);
      
      // Try to fetch ALL pricing to debug
      const allUrl = `${supabaseUrl}/rest/v1/pricing?select=*`;
      const allResponse = await fetch(allUrl, {
        method: "GET",
        headers: {
          apikey: supabaseKey,
          Authorization: `Bearer ${supabaseKey}`,
        },
      });
      const allData = await allResponse.json();
      console.log(`📊 All pricing records in database: ${JSON.stringify(allData)}`);
      
      throw new Error(`No pricing found for plan_id=${planId}, network_id=${networkId}`);
    }

    const pricing = data[0];
    console.log(`✅ Found pricing: sell_price=${pricing.sell_price}, cost_price=${pricing.cost_price}, amigo_plan_id=${pricing.amigo_plan_id}`);
    
    return {
      sell_price: parseFloat(pricing.sell_price),
      cost_price: parseFloat(pricing.cost_price),
      plan_name: pricing.plan_name,
      amigo_plan_id: pricing.amigo_plan_id,
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
    // Don't throw - this is auxiliary and shouldn't fail the main purchase
  }
}

// Helper to validate request payload
function validatePayload(body: unknown): BuyDataRequest {
  if (!body || typeof body !== "object") {
    throw new Error("Invalid request body");
  }

  const req = body as Record<string, unknown>;

  if (typeof req.network !== "number" || ![1, 2].includes(req.network)) {
    throw new Error("Invalid network: must be 1 (MTN) or 2 (Glo)");
  }

  if (typeof req.mobile_number !== "string" || !req.mobile_number.match(/^[0-9]{10,11}$/)) {
    throw new Error("Invalid mobile_number: must be 10-11 digits");
  }

  if (typeof req.plan !== "number" || req.plan <= 0) {
    throw new Error("Invalid plan: must be a positive number");
  }

  if (typeof req.Ported_number !== "boolean") {
    throw new Error("Invalid Ported_number: must be boolean");
  }

  if (req.user_id && typeof req.user_id !== "string") {
    throw new Error("Invalid user_id: must be a string");
  }

  if (req.transaction_id && typeof req.transaction_id !== "string") {
    throw new Error("Invalid transaction_id: must be a string");
  }

  return {
    network: req.network,
    mobile_number: req.mobile_number,
    plan: req.plan,
    Ported_number: req.Ported_number,
    idempotency_key: typeof req.idempotency_key === "string" ? req.idempotency_key : undefined,
    user_id: req.user_id,
    transaction_id: req.transaction_id,
  };
}

// Helper to map Amigo errors to user-friendly messages
function mapAmigoError(error: string, details: string): { code: string; message: string; details?: string } {
  const errorMap: Record<string, { code: string; message: string }> = {
    invalid_token: {
      code: "INVALID_API_KEY",
      message: "API authentication failed. Contact support.",
    },
    plan_not_found: {
      code: "PLAN_NOT_AVAILABLE",
      message: "Selected plan is not available for this network.",
    },
    coming_soon: {
      code: "NETWORK_NOT_AVAILABLE",
      message: "This network is not yet supported.",
    },
    insufficient_balance: {
      code: "INSUFFICIENT_BALANCE",
      message: "Insufficient balance to complete this purchase.",
    },
    invalid_number: {
      code: "INVALID_NUMBER",
      message: "The mobile number provided is invalid.",
    },
  };

  if (errorMap[error]) {
    return { ...errorMap[error], details };
  }

  return {
    code: "PURCHASE_FAILED",
    message: details || "Data purchase failed. Please try again.",
  };
}

// Main handler
serve(async (req: Request) => {
  // Only allow POST requests
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
    // Parse request body
    let payload: BuyDataRequest;
    try {
      const body = await req.json();
      payload = validatePayload(body);
    } catch (e) {
      return new Response(
        JSON.stringify({
          success: false,
          error: {
            code: "INVALID_REQUEST",
            message: e instanceof Error ? e.message : "Invalid request payload",
          },
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Get API key from secrets
    const amigoApiKey = await getAmigoApiKey();

    // Get pricing info from pricing table (this is what user is charged)
    let pricingInfo: PricingInfo;
    try {
      pricingInfo = await getPricingInfo(payload.plan, payload.network);
      console.log(`Pricing info for plan ${payload.plan}: sell_price=${pricingInfo.sell_price}, cost_price=${pricingInfo.cost_price}`);
    } catch (e) {
      // Log detailed error for debugging
      const errorMsg = e instanceof Error ? e.message : String(e);
      console.error(`Failed to get pricing for plan=${payload.plan}, network=${payload.network}: ${errorMsg}`);
      
      return new Response(
        JSON.stringify({
          success: false,
          error: {
            code: "PRICING_NOT_FOUND",
            message: "Pricing not configured for this plan. Please check Supabase pricing table.",
            details: errorMsg,
          },
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Build headers for Amigo API
    const amigoHeaders: Record<string, string> = {
      "X-API-Key": amigoApiKey,
      "Content-Type": "application/json",
    };

    // Add idempotency key if provided (recommended by Amigo docs)
    if (payload.idempotency_key) {
      amigoHeaders["Idempotency-Key"] = payload.idempotency_key;
    }

    // Call Amigo API with the amigo_plan_id (what Amigo recognizes)
    console.log(`📞 Calling Amigo API with: network=${payload.network}, plan=${pricingInfo.amigo_plan_id}, mobile=${payload.mobile_number}`);
    
    const amigoResponse = await fetch("https://amigo.ng/api/data/", {
      method: "POST",
      headers: amigoHeaders,
      body: JSON.stringify({
        network: payload.network,
        mobile_number: payload.mobile_number,
        plan: pricingInfo.amigo_plan_id, // Use Amigo's plan ID, not our custom one
        Ported_number: payload.Ported_number,
      }),
    });

    const amigoData: AmigoResponse = await amigoResponse.json();
    console.log(`📡 Amigo API response: ${JSON.stringify(amigoData)}`);

    // Handle Amigo API response
    if (amigoResponse.ok && amigoData.success) {
      // Calculate profit (what we make from this transaction)
      const profit = pricingInfo.sell_price - pricingInfo.cost_price;
      console.log(`💰 Profit calculated: sell_price=${pricingInfo.sell_price}, cost_price=${pricingInfo.cost_price}, profit=${profit}`);

      // Update transaction with pricing info if transaction_id provided
      if (payload.transaction_id) {
        await updateTransactionPricing(
          payload.transaction_id,
          pricingInfo.sell_price,
          pricingInfo.cost_price,
          profit
        );
      }

      // Success response
      const successResponse: ApiResponse = {
        success: true,
        data: {
          reference: amigoData.reference || "",
          message: amigoData.message || "Data purchase successful",
          network: amigoData.network || payload.network,
          plan: amigoData.plan || payload.plan,
          amount_charged: pricingInfo.sell_price, // Charge user the sell_price
          status: amigoData.status || "delivered",
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
      // Error response from Amigo
      const errorCode = amigoData.error || "unknown_error";
      const errorMessage = amigoData.message || "Purchase failed";

      const mappedError = mapAmigoError(errorCode, errorMessage);

      const errorResponse: ApiResponse = {
        success: false,
        error: mappedError,
      };

      return new Response(JSON.stringify(errorResponse), {
        status: amigoResponse.status === 200 ? 400 : amigoResponse.status,
        headers: { "Content-Type": "application/json" },
      });
    }
  } catch (error) {
    // Handle unexpected errors
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
