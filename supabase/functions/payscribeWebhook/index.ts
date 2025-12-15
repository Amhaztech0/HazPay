// Payscribe Webhook Handler
// Receives deposit notifications and credits user balance
// deno-lint-ignore=no-unknown-variable
// @ts-ignore
import { serve } from "https://deno.land/std@0.191.0/http/server.ts";

interface PayscribeWebhook {
  event_id: string;
  event_type: string;
  trans_id: string;
  amount: number;
  fee: number;
  currency: string;
  transaction: {
    session_id: string;
    date: string;
    amount: number;
    currency: string;
    narration: string;
    bank_name: string;
    bank_code: string;
    sender_account: string;
    sender_name: string;
  };
  customer: {
    id: string;
    name: string;
    number: string;
    bank: string;
    account_id: string;
    account_type: string;
  };
  created_at: string;
  transaction_hash: string;
}

serve(async (req: Request) => {
  // Only accept POST
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ status: false, message: "POST only" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    console.log(`📥 Webhook received from PayScribe`);

    // Get webhook data
    const body = await req.json();
    const webhook = body as PayscribeWebhook;

    console.log(`📋 Event: ${webhook.event_type}`);
    console.log(`💰 Amount: ₦${webhook.amount}`);
    console.log(`📍 Trans ID: ${webhook.trans_id}`);

    // Verify IP address (optional but recommended)
    const clientIp = req.headers.get("x-forwarded-for") || req.headers.get("cf-connecting-ip");
    console.log(`🌐 Request IP: ${clientIp}`);
    const PAYSCRIBE_IP = "162.254.34.78";
    // In production, verify IP matches: if (clientIp !== PAYSCRIBE_IP) throw new Error("Invalid IP");

    // Verify transaction hash
    const secretKey = Deno.env.get("PAYSCRIBE_SECRET_KEY");
    if (!secretKey) {
      throw new Error("PAYSCRIBE_SECRET_KEY not configured");
    }

    const hashCombination =
      secretKey +
      webhook.transaction.sender_account +
      webhook.customer.number +
      webhook.customer.bank +
      webhook.amount +
      webhook.trans_id;

    const encoder = new TextEncoder();
    const data = encoder.encode(hashCombination);
    const hashBuffer = await crypto.subtle.digest("SHA-512", data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const calculatedHash = hashArray.map((b) => b.toString(16).padStart(2, "0")).join("").toUpperCase();

    console.log(`🔐 Hash Verification:`);
    console.log(`   Received:  ${webhook.transaction_hash}`);
    console.log(`   Calculated: ${calculatedHash}`);

    if (calculatedHash !== webhook.transaction_hash) {
      console.error(`❌ Hash mismatch! Rejecting webhook.`);
      return new Response(
        JSON.stringify({
          status: false,
          message: "Hash verification failed",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log(`✅ Hash verified successfully`);

    // Connect to Supabase
    const { createClient } = await import(
      "https://esm.sh/@supabase/supabase-js@2"
    );

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceRole) {
      throw new Error("Supabase credentials not configured");
    }

    const supabase = createClient(supabaseUrl, supabaseServiceRole);

    // Check for duplicate transaction
    console.log(`🔍 Checking for duplicate transaction...`);
    const { data: existingTx } = await supabase
      .from("deposit_transactions")
      .select("id")
      .eq("trans_id", webhook.trans_id)
      .single();

    if (existingTx) {
      console.log(`⚠️ Duplicate transaction detected. Skipping.`);
      return new Response(
        JSON.stringify({
          status: true,
          message: "Duplicate transaction (already processed)",
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Find user by virtual account number
    console.log(`👤 Finding user by virtual account...`);
    const { data: virtualAccount } = await supabase
      .from("virtual_accounts")
      .select("user_id, id, amount")
      .eq("account_number", webhook.customer.number)
      .single();

    if (!virtualAccount) {
      console.error(`❌ Virtual account not found: ${webhook.customer.number}`);
      return new Response(
        JSON.stringify({
          status: false,
          message: "Virtual account not found",
        }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    const userId = virtualAccount.user_id;
    console.log(`✅ Found user: ${userId}`);

    // Check if amount matches (if EXACT)
    const { data: accountType } = await supabase
      .from("virtual_accounts")
      .select("amount_type")
      .eq("id", virtualAccount.id)
      .single();

    if (accountType?.amount_type === "EXACT" && webhook.amount !== virtualAccount.amount) {
      console.error(`❌ Amount mismatch. Expected ₦${virtualAccount.amount}, got ₦${webhook.amount}`);
      return new Response(
        JSON.stringify({
          status: false,
          message: "Amount mismatch",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Store transaction record
    console.log(`💾 Storing transaction in database...`);
    const { data: transaction, error: txError } = await supabase
      .from("deposit_transactions")
      .insert({
        user_id: userId,
        virtual_account_id: virtualAccount.id,
        trans_id: webhook.trans_id,
        amount: webhook.amount,
        fee: webhook.fee,
        currency: webhook.currency,
        sender_account: webhook.transaction.sender_account,
        sender_name: webhook.transaction.sender_name,
        sender_bank: webhook.transaction.bank_name,
        status: "completed",
        webhook_verified: true,
        transaction_hash: webhook.transaction_hash,
        webhook_received_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (txError) {
      console.error(`❌ Failed to insert transaction: ${txError.message}`);
      throw txError;
    }

    // Credit user balance
    console.log(`💳 Crediting user balance...`);
    const { data: profile, error: fetchError } = await supabase
      .from("profiles")
      .select("wallet_balance")
      .eq("id", userId)
      .single();

    if (fetchError) {
      console.error(`❌ Failed to fetch user profile: ${fetchError.message}`);
      throw fetchError;
    }

    const newBalance = (profile.wallet_balance || 0) + webhook.amount;

    const { error: updateError } = await supabase
      .from("profiles")
      .update({
        wallet_balance: newBalance,
      })
      .eq("id", userId);

    if (updateError) {
      console.error(`❌ Failed to update balance: ${updateError.message}`);
      throw updateError;
    }

    console.log(`✅ User balance updated: ₦${newBalance}`);

    // Mark virtual account as completed
    await supabase
      .from("virtual_accounts")
      .update({ status: "completed" })
      .eq("id", virtualAccount.id);

    console.log(`✅ Webhook processed successfully`);

    return new Response(
      JSON.stringify({
        status: true,
        message: "Webhook processed successfully",
        trans_id: webhook.trans_id,
        amount_credited: webhook.amount,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error(`❌ Error processing webhook:`, error);
    return new Response(
      JSON.stringify({
        status: false,
        message: error instanceof Error ? error.message : "Unknown error",
      }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
