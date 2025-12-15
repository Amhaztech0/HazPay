// Payscribe Virtual Account Generator
// Creates a temporary virtual account for users to deposit money
// deno-lint-ignore=no-unknown-variable
// @ts-ignore
import { serve } from "https://deno.land/std@0.191.0/http/server.ts";

interface CreateVirtualAccountRequest {
  user_id: string;
  amount: number;
  amount_type?: "EXACT" | "ANY";
  description?: string;
  expiry_hours?: number;
}

interface ApiResponse {
  success: boolean;
  data?: {
    account_number: string;
    account_name: string;
    bank_name: string;
    bank_code: string;
    amount: number;
    expires_at: string;
    order_ref: string;
  };
  error?: {
    code: string;
    message: string;
  };
}

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({
        success: false,
        error: { code: "METHOD_NOT_ALLOWED", message: "POST only" },
      }),
      { status: 405, headers: { "Content-Type": "application/json" } }
    );
  }

  try {
    const body = await req.json();
    console.log(`📥 Request: ${JSON.stringify(body)}`);

    const payload = body as CreateVirtualAccountRequest;

    // Validate input
    if (!payload.user_id || !payload.amount) {
      throw new Error("user_id and amount are required");
    }

    if (payload.amount <= 0) {
      throw new Error("amount must be greater than 0");
    }

    // Generate order reference
    const orderRef = crypto.randomUUID();
    const expiryHours = payload.expiry_hours || 1;
    const amountType = payload.amount_type || "EXACT";

    // Get PayScribe API key
    const payscribeEnv = Deno.env.get("PAYSCRIBE_ENV") || "sandbox";
    const payscribeKey =
      payscribeEnv === "production"
        ? Deno.env.get("PAYSCRIBE_API_KEY_PROD")
        : Deno.env.get("PAYSCRIBE_API_KEY");

    if (!payscribeKey) throw new Error("PayScribe API key not configured");

    const baseUrl =
      payscribeEnv === "production"
        ? "https://api.payscribe.ng/api/v1"
        : "https://sandbox.payscribe.ng/api/v1";

    // Call PayScribe to create virtual account
    const headers = {
      Authorization: `Bearer ${payscribeKey}`,
      "Content-Type": "application/json",
    };

    const payscribePayload = {
      account_type: "dynamic",
      ref: orderRef,
      currency: "NGN",
      order: {
        amount: payload.amount,
        amount_type: amountType,
        description:
          payload.description || `Deposit for user ${payload.user_id}`,
        expiry: {
          duration: expiryHours,
          duration_type: "hours",
        },
      },
      customer: {
        name: `User ${payload.user_id}`,
        email: `user-${payload.user_id}@hazpay.local`,
        phone: "08012345678", // Dummy phone - not used for virtual accounts
      },
    };

    console.log(`🌐 Creating virtual account on PayScribe...`);
    const payscribeResponse = await fetch(
      `${baseUrl}/collections/virtual-accounts/create`,
      {
        method: "POST",
        headers,
        body: JSON.stringify(payscribePayload),
      }
    );

    const responseText = await payscribeResponse.text();
    console.log(`📡 PayScribe Response: ${responseText.substring(0, 300)}`);

    const payscribeData = JSON.parse(responseText);

    if (!payscribeData.status) {
      throw new Error(
        `PayScribe API Error: ${payscribeData.description || "Unknown error"}`
      );
    }

    const accountDetails = payscribeData.message.details;
    const account = accountDetails.account[0];

    // Store in database
    console.log(`💾 Storing virtual account in database...`);
    const { createClient } = await import(
      "https://esm.sh/@supabase/supabase-js@2"
    );

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceRole) {
      throw new Error("Supabase credentials not configured");
    }

    const supabase = createClient(supabaseUrl, supabaseServiceRole);

    const { error: insertError } = await supabase
      .from("virtual_accounts")
      .insert({
        user_id: payload.user_id,
        account_number: account.account_number,
        account_name: account.account_name,
        bank_name: account.bank_name,
        bank_code: account.bank_code,
        order_ref: orderRef,
        amount: payload.amount,
        amount_type: amountType,
        description: payload.description,
        expires_at: new Date(
          Date.now() + expiryHours * 60 * 60 * 1000
        ).toISOString(),
        status: "active",
      });

    if (insertError) {
      console.error(`❌ Database error: ${insertError.message}`);
      throw new Error(`Failed to store virtual account: ${insertError.message}`);
    }

    console.log(`✅ Virtual account created successfully`);

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          account_number: account.account_number,
          account_name: account.account_name,
          bank_name: account.bank_name,
          bank_code: account.bank_code,
          amount: payload.amount,
          expires_at: accountDetails.expiry_date,
          order_ref: orderRef,
        },
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: {
          code: "ERROR",
          message: error instanceof Error ? error.message : "Unknown error",
        },
      }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
