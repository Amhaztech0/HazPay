#!/usr/bin/env pwsh

# Deploy 100ms Edge Function to Supabase
# This script deploys the generate-hms-token function

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "100ms Edge Function Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check Supabase CLI
Write-Host "[1/5] Checking Supabase CLI..." -ForegroundColor Yellow
try {
    $version = npx supabase --version 2>&1
    Write-Host "✓ Supabase CLI ready (v$version)" -ForegroundColor Green
} catch {
    Write-Host "✗ Supabase CLI not found" -ForegroundColor Red
    Write-Host "Install: npm install -g @supabase/cli" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# Step 2: Login to Supabase
Write-Host "[2/5] Login to Supabase..." -ForegroundColor Yellow
Write-Host "Please login to your Supabase account (browser will open)" -ForegroundColor Gray
npx supabase login
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to login" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Logged in successfully" -ForegroundColor Green
Write-Host ""

# Step 3: Set secrets
Write-Host "[3/5] Setting Edge Function secrets..." -ForegroundColor Yellow

Write-Host "Setting HMS_APP_ACCESS_KEY..." -ForegroundColor Gray
npx supabase secrets set HMS_APP_ACCESS_KEY=69171bc9145cb4e8449b1a6e | Out-Null

Write-Host "Setting HMS_APP_SECRET..." -ForegroundColor Gray
npx supabase secrets set HMS_APP_SECRET="ibgzGtbFbko5Fkn8MV0rZ0e3oyU46hvZpG-_PEPH75-f40D2zewJo4foqslX1ILrdRed5mOnricZd7fjKBsenQXxNPBX1Xx2RCJZ8FSNuIRu609wE9bDXW_n2VpqO127HqUT2jF_B848MQNzMzKVHBsrzm0UhYlCla_aw6YOgoU=" | Out-Null

Write-Host "✓ Secrets set" -ForegroundColor Green
Write-Host ""

# Step 4: Deploy edge function
Write-Host "[4/5] Deploying generate-hms-token function..." -ForegroundColor Yellow
npx supabase functions deploy generate-hms-token
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to deploy function" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Function deployed successfully" -ForegroundColor Green
Write-Host ""

# Step 5: Verify deployment
Write-Host "[5/5] Verifying deployment..." -ForegroundColor Yellow
npx supabase functions list
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✓ Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Your function is now live at:" -ForegroundColor Gray
Write-Host "https://YOUR_PROJECT.supabase.co/functions/v1/generate-hms-token" -ForegroundColor Cyan
Write-Host ""

Write-Host "To test the function, run:" -ForegroundColor Gray
Write-Host @"
curl -X POST `
  'https://YOUR_PROJECT.supabase.co/functions/v1/generate-hms-token' `
  -H 'Authorization: Bearer YOUR_ANON_KEY' `
  -H 'Content-Type: application/json' `
  -d '{
    "room_id": "test-room",
    "user_name": "Test User"
  }'
"@ -ForegroundColor Yellow
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Gray
Write-Host "1. Get your Supabase project URL and anon key" -ForegroundColor White
Write-Host "2. Test the edge function with curl" -ForegroundColor White
Write-Host "3. Update HMS service in Flutter app" -ForegroundColor White
Write-Host "4. Run: flutter run" -ForegroundColor White
Write-Host ""
