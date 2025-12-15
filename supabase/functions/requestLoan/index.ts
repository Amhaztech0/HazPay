import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

interface RequestBody {
  user_id: string;
  mobile_number?: string;
  network?: number;
}

interface LoanResponse {
  success: boolean;
  data?: {
    loan_id: string;
    status: string;
    message: string;
  };
  error?: {
    code: string;
    message: string;
  };
}

interface PricingRow {
  plan_id: string;
  network_id: number;
  data_size: string;
  sell_price: number;
  cost_price: number;
  payscribe_plan_id: string;
}

interface LoanRow {
  id: string;
  user_id: string;
  plan_id: string;
  loan_fee: number;
  status: string;
  created_at: string;
  issued_at: string | null;
  repaid_at: string | null;
  failure_reason: string | null;
}

// Get 1GB loan plan from pricing table
async function get1GBPlan(
  supabase: ReturnType<typeof createClient>,
  networkId?: number
): Promise<PricingRow | null> {
  try {
    console.log(`📊 Looking for 1GB plan for network: ${networkId || "any"}`);

    const query = supabase
      .from("pricing")
      .select("*")
      .ilike("data_size", "%1GB%");

    if (networkId) {
      query.eq("network_id", networkId);
    }

    const { data, error } = await query.limit(1).single();

    if (error) {
      console.log("⚠️ Error fetching 1GB plan:", error.message);
      return null;
    }

    console.log("✅ Found 1GB plan:", data);
    return data as PricingRow;
  } catch (e) {
    console.error("❌ Error getting 1GB plan:", e);
    return null;
  }
}

// Get user's wallet balance
async function getUserWallet(
  supabase: ReturnType<typeof createClient>,
  userId: string
): Promise<number> {
  try {
    const { data, error } = await supabase
      .from("hazpay_wallets")
      .select("balance")
      .eq("user_id", userId)
      .single();

    if (error) {
      console.log("⚠️ No wallet found, balance = 0");
      return 0;
    }

    return (data?.balance || 0) as number;
  } catch (e) {
    console.error("❌ Error getting wallet:", e);
    return 0;
  }
}

// Check if user has active loan
async function hasActiveLoan(
  supabase: ReturnType<typeof createClient>,
  userId: string
): Promise<boolean> {
  try {
    const { data, error } = await supabase
      .from("loans")
      .select("id")
      .eq("user_id", userId)
      .in("status", ["pending", "issued"])
      .limit(1);

    if (error) {
      console.log("⚠️ Error checking active loans:", error.message);
      return false;
    }

    return (data?.length || 0) > 0;
  } catch (e) {
    console.error("❌ Error checking active loan:", e);
    return false;
  }
}

// Issue loan via Payscribe
async function issueLoanViaPayscribe(
  planId: string,
  mobileNumber: string,
  networkId: number,
  loanFee: number,
  userId: string,
  loanId: string
): Promise<{ success: boolean; reference?: string; message: string }> {
  try {
    const apiKey = Deno.env.get("PAYSCRIBE_API_KEY");
    if (!apiKey) {
      throw new Error("PAYSCRIBE_API_KEY not configured");
    }

    const providerMap: Record<number, string> = {
      1: "mtn",
      2: "glo",
      3: "airtel",
      4: "9mobile",
      5: "smile",
    };

    const provider = providerMap[networkId];
    if (!provider) {
      throw new Error(`Invalid network ID: ${networkId}`);
    }

    console.log(
      `🔐 Calling Payscribe to issue 1GB loan (${provider})...`
    );

    const requestBody = {
      provider: provider,
      mobile_number: mobileNumber,
      plan: parseInt(planId), // Convert to integer - Payscribe API expects number
      idempotency_key: loanId,
      metadata: {
        user_id: userId,
        is_loan: true,
        loan_fee: loanFee,
      },
    };

    console.log(`📤 Sending to Payscribe:`, JSON.stringify(requestBody));

    const response = await fetch(
      "https://sandbox.payscribe.ng/api/v1/airtime/vend",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify(requestBody),
      }
    );

    const responseText = await response.text();
    console.log(`📥 Payscribe response status: ${response.status}, body: ${responseText}`);

    let result: { success?: boolean; data?: { reference?: string }; error?: { message?: string } };
    try {
      result = JSON.parse(responseText) as {
        success?: boolean;
        data?: { reference?: string };
        error?: { message?: string };
      };
    } catch (e) {
      console.error(`❌ Failed to parse Payscribe response: ${e}`);
      return {
        success: false,
        message: `Payscribe returned invalid response: ${responseText.substring(0, 200)}`,
      };
    }

    if (result.success && result.data?.reference) {
      console.log(`✅ Loan issued: ${result.data.reference}`);
      return {
        success: true,
        reference: result.data.reference,
        message: "1GB data loan issued successfully",
      };
    } else {
      const errorMsg = result.error?.message || "Payscribe loan issuance failed";
      console.log(`❌ Payscribe error: ${errorMsg}`);
      return {
        success: false,
        message: errorMsg,
      };
    }
  } catch (e) {
    console.error("❌ Error calling Payscribe:", e);
    return {
      success: false,
      message: `Failed to issue loan: ${e instanceof Error ? e.message : String(e)}`,
    };
  }
}

// Main handler
serve(async (req: Request) => {
  try {
    // Initialize Supabase
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseKey) {
      throw new Error("Supabase environment variables not configured");
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    // Parse request body
    const body = (await req.json()) as RequestBody;
    const { user_id, mobile_number, network } = body;

    if (!user_id) {
      return new Response(
        JSON.stringify({
          success: false,
          error: {
            code: "missing_user_id",
            message: "user_id is required",
          },
        } as LoanResponse),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log(`📱 Loan request from user: ${user_id}`);

    // Check if user already has active loan
    const hasLoan = await hasActiveLoan(supabase, user_id);
    if (hasLoan) {
      return new Response(
        JSON.stringify({
          success: false,
          error: {
            code: "active_loan_exists",
            message: "User already has an active loan",
          },
        } as LoanResponse),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Get 1GB plan
    const plan = await get1GBPlan(supabase, network);
    if (!plan) {
      return new Response(
        JSON.stringify({
          success: false,
          error: {
            code: "plan_not_found",
            message: "1GB data plan not available",
          },
        } as LoanResponse),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Calculate loan fee (20% of plan cost)
    const loanFee = Math.round(plan.cost_price * 0.2 * 100) / 100;
    console.log(
      `💰 Loan fee calculated: ₦${loanFee} (20% of ₦${plan.cost_price})`
    );

    // Create loan record (pending) - don't specify ID, let PostgreSQL generate UUID
    const { error: insertError, data: loanData } = await supabase
      .from("loans")
      .insert({
        user_id,
        plan_id: parseInt(plan.plan_id),
        loan_fee: loanFee,
        status: "pending",
        created_at: new Date().toISOString(),
      } as unknown as LoanRow)
      .select("*")
      .single();

    if (insertError) {
      console.error("❌ Error inserting loan record:", JSON.stringify(insertError));
      return new Response(
        JSON.stringify({
          success: false,
          error: {
            code: "db_error",
            message: `Failed to create loan record: ${insertError.message || JSON.stringify(insertError)}`,
          },
        } as LoanResponse),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    const loanId = (loanData as LoanRow).id;

    // Determine mobile number for data issuance
    let targetMobileNumber = mobile_number;
    if (!targetMobileNumber) {
      const { data: userData, error: userError } = await supabase
        .from("profiles")
        .select("phone_number")
        .eq("id", user_id)
        .single();

      if (!userError && userData?.phone_number) {
        targetMobileNumber = userData.phone_number as string;
      }
    }

    if (!targetMobileNumber) {
      await supabase
        .from("loans")
        .update({ status: "failed", failure_reason: "No mobile number provided" })
        .eq("id", loanId);

      return new Response(
        JSON.stringify({
          success: false,
          error: {
            code: "no_mobile_number",
            message: "Mobile number is required to issue loan",
          },
        } as LoanResponse),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Issue data via Payscribe
    const networkId = network || plan.network_id;
    const payscribeResult = await issueLoanViaPayscribe(
      plan.plan_id, // Use plan_id, NOT payscribe_plan_id - let the function handle the conversion
      targetMobileNumber,
      networkId,
      loanFee,
      user_id,
      loanId
    );

    if (payscribeResult.success) {
      // Update loan to issued
      const { error: updateError } = await supabase
        .from("loans")
        .update({
          status: "issued",
          issued_at: new Date().toISOString(),
        })
        .eq("id", loanId);

      if (updateError) {
        console.error("⚠️ Warning: Loan issued but failed to update status:", updateError);
      }

      // Record transaction
      const transactionId = `trans_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      await supabase.from("hazpay_transactions").insert({
        id: transactionId,
        user_id,
        type: "loan",
        amount: loanFee,
        network_name: plan.data_size,
        data_capacity: "1GB",
        mobile_number: targetMobileNumber,
        reference: payscribeResult.reference,
        status: "success",
        created_at: new Date().toISOString(),
      });

      console.log(`✅ Loan issued successfully: ${loanId}`);

      return new Response(
        JSON.stringify({
          success: true,
          data: {
            loan_id: loanId,
            status: "issued",
            message: `1GB data loan issued. Repay ₦${loanFee} to complete.`,
          },
        } as LoanResponse),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    } else {
      // Update loan to failed
      await supabase
        .from("loans")
        .update({
          status: "failed",
          failure_reason: payscribeResult.message,
        })
        .eq("id", loanId);

      console.log(`❌ Loan issuance failed: ${payscribeResult.message}`);

      return new Response(
        JSON.stringify({
          success: false,
          error: {
            code: "issuance_failed",
            message: payscribeResult.message,
          },
        } as LoanResponse),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }
  } catch (e) {
    console.error("❌ Unexpected error:", e);
    return new Response(
      JSON.stringify({
        success: false,
        error: {
          code: "server_error",
          message: `Server error: ${e instanceof Error ? e.message : String(e)}`,
        },
      } as LoanResponse),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
