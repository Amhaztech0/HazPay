@echo off
REM Deploy 100ms Edge Function to Supabase
REM This script deploys the generate-hms-token function

echo ========================================
echo 100ms Edge Function Deployment
echo ========================================
echo.

REM Check if Supabase CLI is available
echo [1/5] Checking Supabase CLI...
npx supabase --version
if %ERRORLEVEL% NEQ 0 (
    echo Error: Supabase CLI not found
    echo Install: npm install -g @supabase/cli
    exit /b 1
)
echo ✓ Supabase CLI ready
echo.

REM Login to Supabase
echo [2/5] Login to Supabase...
echo Please login to your Supabase account:
npx supabase login
if %ERRORLEVEL% NEQ 0 (
    echo Error: Failed to login
    exit /b 1
)
echo ✓ Logged in successfully
echo.

REM Set secrets
echo [3/5] Setting Edge Function secrets...
echo Setting HMS_APP_ACCESS_KEY...
npx supabase secrets set HMS_APP_ACCESS_KEY=69171bc9145cb4e8449b1a6e
echo.
echo Setting HMS_APP_SECRET...
npx supabase secrets set HMS_APP_SECRET=ibgzGtbFbko5Fkn8MV0rZ0e3oyU46hvZpG-_PEPH75-f40D2zewJo4foqslX1ILrdRed5mOnricZd7fjKBsenQXxNPBX1Xx2RCJZ8FSNuIRu609wE9bDXW_n2VpqO127HqUT2jF_B848MQNzMzKVHBsrzm0UhYlCla_aw6YOgoU=
if %ERRORLEVEL% NEQ 0 (
    echo Warning: Failed to set secrets (may already be set)
)
echo ✓ Secrets set
echo.

REM Deploy edge function
echo [4/5] Deploying generate-hms-token function...
npx supabase functions deploy generate-hms-token
if %ERRORLEVEL% NEQ 0 (
    echo Error: Failed to deploy function
    exit /b 1
)
echo ✓ Function deployed successfully
echo.

REM List functions to confirm
echo [5/5] Verifying deployment...
npx supabase functions list
echo.

echo ========================================
echo ✓ Deployment Complete!
echo ========================================
echo.
echo Your function is now live at:
echo https://YOUR_PROJECT.supabase.co/functions/v1/generate-hms-token
echo.
echo To test the function:
echo curl -X POST \
echo   'https://YOUR_PROJECT.supabase.co/functions/v1/generate-hms-token' \
echo   -H 'Authorization: Bearer YOUR_ANON_KEY' \
echo   -H 'Content-Type: application/json' \
echo   -d '{
echo     "room_id": "test-room",
echo     "user_name": "Test User"
echo   }'
echo.
echo Next: Update your Flutter app with the function URL
pause
