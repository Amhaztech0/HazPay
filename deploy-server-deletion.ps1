# Supabase Edge Function Deployment - Server Deletion
# This script deploys the execute_scheduled_server_deletions function

Write-Host "========================================" -ForegroundColor Blue
Write-Host "Server Deletion Edge Function Deployment" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# Step 1: Create supabase directory structure
Write-Host "[1/4] Creating function directory..." -ForegroundColor Cyan
$functionDir = "supabase/functions/execute_scheduled_server_deletions"

if (Test-Path $functionDir) {
    Write-Host "✓ Function directory already exists" -ForegroundColor Green
} else {
    New-Item -ItemType Directory -Path $functionDir -Force | Out-Null
    Write-Host "✓ Created function directory" -ForegroundColor Green
}

# Step 2: Create the index.ts file with the Edge Function code
Write-Host "[2/4] Creating Edge Function code..." -ForegroundColor Cyan

$functionCode = @'
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    // Get environment variables
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    if (!supabaseUrl || !serviceRoleKey) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Missing Supabase credentials'
        }),
        { 
          status: 500,
          headers: { "Content-Type": "application/json" }
        }
      )
    }

    // Create Supabase client with service role (bypass RLS)
    const supabase = createClient(supabaseUrl, serviceRoleKey)

    // Call the RPC function to execute deletions
    const { data, error } = await supabase.rpc('execute_scheduled_server_deletions')

    if (error) {
      console.error('RPC Error:', error)
      return new Response(
        JSON.stringify({
          success: false,
          error: error.message
        }),
        { 
          status: 500,
          headers: { "Content-Type": "application/json" }
        }
      )
    }

    console.log('Deletion Result:', data)

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Scheduled server deletions executed',
        deleted_count: data?.deleted_count || 0
      }),
      { 
        status: 200,
        headers: { "Content-Type": "application/json" }
      }
    )

  } catch (err) {
    console.error('Function Error:', err)
    return new Response(
      JSON.stringify({
        success: false,
        error: err.message
      }),
      { 
        status: 500,
        headers: { "Content-Type": "application/json" }
      }
    )
  }
})
'@

$indexFile = "$functionDir/index.ts"
Set-Content -Path $indexFile -Value $functionCode -Encoding UTF8
Write-Host "✓ Created $indexFile" -ForegroundColor Green

# Step 3: Deploy the function
Write-Host "[3/4] Deploying function to Supabase..." -ForegroundColor Cyan

supabase functions deploy execute_scheduled_server_deletions

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Function deployed successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Deployment failed" -ForegroundColor Red
    exit 1
}

# Step 4: Get project info and show next steps
Write-Host "[4/4] Getting deployment info..." -ForegroundColor Cyan

$functions = supabase functions list --json | ConvertFrom-Json
$executionFunc = $functions | Where-Object { $_.name -eq "execute_scheduled_server_deletions" }

if ($executionFunc) {
    Write-Host "✓ Function is active and ready" -ForegroundColor Green
} else {
    Write-Host "⚠ Function deployment may still be processing" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✓ Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Blue
Write-Host ""
Write-Host "1. Go to: https://supabase.com/dashboard/project/YOUR_PROJECT_ID/functions" -ForegroundColor Yellow
Write-Host "   (Replace YOUR_PROJECT_ID with your actual project ID)" -ForegroundColor Yellow
Write-Host ""
Write-Host "2. Find 'execute_scheduled_server_deletions' in the list" -ForegroundColor Yellow
Write-Host ""
Write-Host "3. Click on it to open the function details" -ForegroundColor Yellow
Write-Host ""
Write-Host "4. Scroll down and look for 'Cron' or 'Schedule' section" -ForegroundColor Yellow
Write-Host ""
Write-Host "5. Set the cron schedule to: 0 * * * *" -ForegroundColor Yellow
Write-Host "   (This runs the function every hour)" -ForegroundColor Yellow
Write-Host ""
Write-Host "6. Click 'Deploy' or 'Save'" -ForegroundColor Yellow
Write-Host ""
Write-Host "That's it! Your server deletion will run automatically every hour." -ForegroundColor Green
Write-Host ""
