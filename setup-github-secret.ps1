# GitHub Setup Script for Server Deletion Automation
# This script sets up the GitHub secret and pushes the workflow file

Write-Host "================================" -ForegroundColor Blue
Write-Host "GitHub Actions Setup" -ForegroundColor Blue
Write-Host "================================" -ForegroundColor Blue
Write-Host ""

# Check if GitHub CLI is installed
try {
    $ghVersion = gh --version 2>&1
    Write-Host "✓ GitHub CLI found: $($ghVersion[0])" -ForegroundColor Green
} catch {
    Write-Host "❌ GitHub CLI not found. Install it first:" -ForegroundColor Red
    Write-Host "npm install -g gh" -ForegroundColor Yellow
    Write-Host "Or download: https://cli.github.com" -ForegroundColor Yellow
    exit 1
}

# Get repository info
Write-Host ""
Write-Host "Getting repository information..." -ForegroundColor Yellow

$repoInfo = gh repo view --json nameWithOwner,url 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Not in a GitHub repository or not authenticated" -ForegroundColor Red
    Write-Host "Run: gh auth login" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Repository found" -ForegroundColor Green

# Set the secret
Write-Host ""
Write-Host "Adding SUPABASE_SERVICE_ROLE_KEY secret..." -ForegroundColor Yellow

$secretValue = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF2YWV3emtnc2lsaXRjcm5jcWhlIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MjQ1MjY3NywiZXhwIjoyMDc4MDI4Njc3fQ.xdjNyCH_QfWlRa0ACC3YjmIsA-IZHYg2bOeab9lsmJc"

# Create temporary file with secret
$tempFile = New-TemporaryFile
Set-Content -Path $tempFile -Value $secretValue -Encoding ASCII

# Add secret using GitHub CLI
gh secret set SUPABASE_SERVICE_ROLE_KEY < $tempFile

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Secret added successfully" -ForegroundColor Green
    Remove-Item -Path $tempFile -Force
} else {
    Write-Host "❌ Failed to add secret" -ForegroundColor Red
    Remove-Item -Path $tempFile -Force
    exit 1
}

Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host "✓ Setup Complete!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next: Commit and push the workflow file:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  git add .github/workflows/server-deletion-cron.yml" -ForegroundColor Cyan
Write-Host "  git commit -m 'Add server deletion automation'" -ForegroundColor Cyan
Write-Host "  git push" -ForegroundColor Cyan
Write-Host ""
Write-Host "Your server deletion will run automatically every hour!" -ForegroundColor Green
