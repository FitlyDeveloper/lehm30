# PowerShell script to force deploy Firebase functions

Write-Host "Forcing deployment of Firebase functions..." -ForegroundColor Cyan

# Update version number in package.json
$timestamp = Get-Date -UFormat %s
$packageJson = Get-Content -Raw -Path "package.json" | ConvertFrom-Json
$packageJson.version = "3.0.$timestamp"
$packageJson | ConvertTo-Json -Depth 10 | Set-Content -Path "package.json"

Write-Host "Updated package.json version to $($packageJson.version)" -ForegroundColor Green

# Deploy the functions
firebase deploy --only functions --force

Write-Host "Deployment completed!" -ForegroundColor Green 