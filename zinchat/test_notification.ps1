# Test Notification Script
# This will call your Edge Function directly

Write-Host "=== ZinChat Notification Test ===" -ForegroundColor Cyan
Write-Host ""

# You need to get these values:
Write-Host "STEP 1: Get your user token" -ForegroundColor Yellow
Write-Host "Go to: https://supabase.com/dashboard/project/avaewzkgsilitcrncqhe/api" -ForegroundColor White
Write-Host "Copy your 'anon' key" -ForegroundColor White
Write-Host ""

$SUPABASE_URL = "https://avaewzkgsilitcrncqhe.supabase.co"
$ANON_KEY = Read-Host "Paste your Supabase anon key here"

Write-Host ""
Write-Host "STEP 2: Get the recipient user ID" -ForegroundColor Yellow
Write-Host "This is the user who should receive the notification" -ForegroundColor White
$RECIPIENT_ID = Read-Host "Paste recipient user_id (from hamzaabdulhakim3@gmail.com)"

Write-Host ""
Write-Host "STEP 3: Sending test notification..." -ForegroundColor Green

$body = @{
    type = "direct_message"
    userId = $RECIPIENT_ID
    messageId = "test-message-123"
    senderId = "test-sender"
    senderName = "Test User"
    content = "🔔 This is a test notification!"
    chatId = "test-chat-123"
} | ConvertTo-Json

$headers = @{
    "Authorization" = "Bearer $ANON_KEY"
    "Content-Type" = "application/json"
    "apikey" = $ANON_KEY
}

try {
    $response = Invoke-RestMethod `
        -Uri "$SUPABASE_URL/functions/v1/send-notification" `
        -Method POST `
        -Headers $headers `
        -Body $body
    
    Write-Host ""
    Write-Host "✅ SUCCESS!" -ForegroundColor Green
    Write-Host "Response: $($response | ConvertTo-Json -Depth 5)" -ForegroundColor White
} catch {
    Write-Host ""
    Write-Host "❌ ERROR!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor White
    Write-Host "Response: $($_.ErrorDetails.Message)" -ForegroundColor White
}

Write-Host ""
Write-Host "Check your phone for the notification!" -ForegroundColor Cyan
