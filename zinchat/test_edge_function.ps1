# Test Supabase Edge Function for notifications
# Replace these values with real ones from your database

$url = "https://avaewzkgsilitcrncqhe.supabase.co/functions/v1/send-notification"
$anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF2YWV3emtnc2lsaXRjcm5jcWhlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI0NTI2NzcsImV4cCI6MjA3ODAyODY3N30.wVrlS6WYTI5IpL23B5LtpD3czW-HwzSbzFC2sS9sLLg"

Write-Host "Testing Edge Function..." -ForegroundColor Yellow
Write-Host ""
Write-Host "IMPORTANT: Replace these values with real data from your database:" -ForegroundColor Red
Write-Host "  - userId: The recipient's user ID" -ForegroundColor Cyan
Write-Host "  - messageId: Any message ID" -ForegroundColor Cyan
Write-Host "  - senderId: The sender's user ID" -ForegroundColor Cyan
Write-Host ""

# Example body (replace with real IDs)
$body = @{
    type = "direct_message"
    userId = "REPLACE_WITH_RECIPIENT_USER_ID"
    messageId = "test-123"
    senderId = "REPLACE_WITH_SENDER_USER_ID"
    senderName = "Test User"
    content = "Hello! This is a test notification"
    chatId = "test-chat-123"
} | ConvertTo-Json

$headers = @{
    "Content-Type" = "application/json"
    "Authorization" = "Bearer $anonKey"
}

Write-Host "Request body:" -ForegroundColor Yellow
Write-Host $body
Write-Host ""

try {
    $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body
    Write-Host "✅ SUCCESS!" -ForegroundColor Green
    Write-Host "Response:" -ForegroundColor Yellow
    $response | ConvertTo-Json -Depth 5
} catch {
    Write-Host "❌ ERROR!" -ForegroundColor Red
    Write-Host $_.Exception.Message
    Write-Host ""
    if ($_.Exception.Response) {
        $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "Error details:" -ForegroundColor Yellow
        Write-Host $responseBody
    }
}
