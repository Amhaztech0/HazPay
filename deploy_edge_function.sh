#!/bin/bash

# Supabase Edge Function Deployment Script
# This script deploys the server deletion Edge Function to Supabase

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Supabase Edge Function Deployment${NC}"
echo -e "${BLUE}================================${NC}"

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo -e "${RED}❌ Supabase CLI is not installed${NC}"
    echo -e "${YELLOW}Install it with: npm install -g supabase${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Supabase CLI found${NC}"

# Check if we're in the right directory
if [ ! -f "supabase/config.toml" ]; then
    echo -e "${YELLOW}Creating supabase directory structure...${NC}"
    mkdir -p supabase/functions/execute_scheduled_server_deletions
else
    echo -e "${GREEN}✓ Supabase directory found${NC}"
fi

# Create the function directory if it doesn't exist
mkdir -p supabase/functions/execute_scheduled_server_deletions

# Copy the TypeScript file
echo -e "${YELLOW}Creating function file...${NC}"
cat > supabase/functions/execute_scheduled_server_deletions/index.ts << 'EOF'
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
EOF

echo -e "${GREEN}✓ Function file created${NC}"

# Login to Supabase
echo -e "${YELLOW}Please log in to Supabase (if not already logged in)...${NC}"
supabase link

# Deploy the function
echo -e "${YELLOW}Deploying function...${NC}"
supabase functions deploy execute_scheduled_server_deletions

# Check if deployment was successful
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Function deployed successfully!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "${YELLOW}1. Go to Supabase Dashboard → Edge Functions${NC}"
    echo -e "${YELLOW}2. Find 'execute_scheduled_server_deletions'${NC}"
    echo -e "${YELLOW}3. Set up a cron schedule: 0 * * * * (hourly)${NC}"
    echo -e "${YELLOW}4. Or use GitHub Actions / external service as shown in EDGE_FUNCTION_SETUP_GUIDE.md${NC}"
else
    echo -e "${RED}❌ Deployment failed${NC}"
    exit 1
fi
