# Supabase Edge Function Deployment Script (PowerShell)
# This script deploys the server deletion Edge Function to Supabase

$ErrorActionPreference = "Stop"

Write-Host "================================" -ForegroundColor Blue
Write-Host "Supabase Edge Function Deployment" -ForegroundColor Blue
Write-Host "================================" -ForegroundColor Blue
Write-Host ""

# Check if Supabase CLI is installed
try {
    $supabaseVersion = supabase --version 2>&1
    Write-Host "✓ Supabase CLI found: $supabaseVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Supabase CLI is not installed" -ForegroundColor Red
    Write-Host "Install it with: npm install -g supabase" -ForegroundColor Yellow
    exit 1
}

# Create supabase directory structure
$supabaseDir = "supabase"
$functionDir = "supabase/functions/execute_scheduled_server_deletions"

if (Test-Path "$supabaseDir/config.toml") {
    Write-Host "✓ Supabase directory found" -ForegroundColor Green
} else {
    Write-Host "Creating supabase directory structure..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $supabaseDir -Force | Out-Null
}

# Create function directory
Write-Host "Creating function directory..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $functionDir -Force | Out-Null

# Create the index.ts file
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

Write-Host "Creating function file..." -ForegroundColor Yellow
$functionFile = "$functionDir/index.ts"
Set-Content -Path $functionFile -Value $functionCode -Encoding UTF8
Write-Host "✓ Function file created at $functionFile" -ForegroundColor Green

# Link to Supabase project
Write-Host ""
Write-Host "Linking to Supabase project..." -ForegroundColor Yellow
supabase link

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to link Supabase project" -ForegroundColor Red
    exit 1
}

# Deploy the function
Write-Host ""
Write-Host "Deploying function..." -ForegroundColor Yellow
supabase functions deploy execute_scheduled_server_deletions

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✓ Function deployed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Blue
    Write-Host "1. Go to Supabase Dashboard → Edge Functions" -ForegroundColor Yellow
    Write-Host "2. Find 'execute_scheduled_server_deletions'" -ForegroundColor Yellow
    Write-Host "3. Set up a cron schedule: 0 * * * * (runs every hour)" -ForegroundColor Yellow
    Write-Host "4. Or use GitHub Actions / external service (see EDGE_FUNCTION_SETUP_GUIDE.md)" -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "❌ Deployment failed" -ForegroundColor Red
    exit 1
}
