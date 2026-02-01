# Start-OpenClaw-LMStudio.ps1
# Automated script to start OpenClaw with LM Studio integration

Function Write-Lobster {
    Write-Host "      _ _" -ForegroundColor Cyan
    Write-Host "     ( ) )" -ForegroundColor Cyan
    Write-Host "      ) (      🦞 OpenClaw + LM Studio" -ForegroundColor Cyan
    Write-Host "    ( ) ) )" -ForegroundColor Cyan
    Write-Host "     ) ( (" -ForegroundColor Cyan
    Write-Host "    ( ) ) )" -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan
}

Clear-Host
Write-Lobster

# 1. Start LM Studio server
Write-Host "[*] Starting LM Studio server..." -ForegroundColor Yellow

# Check if lms command is available
$lmsPath = Get-Command lms -ErrorAction SilentlyContinue
if (-not $lmsPath) {
    Write-Host "[-] lms CLI not found in PATH" -ForegroundColor Red
    Write-Host "[!] Please install LM Studio CLI or start the server manually" -ForegroundColor Yellow
    Write-Host "[!] Visit: https://lmstudio.ai for installation" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "[+] Found lms CLI, starting server on port 1234..." -ForegroundColor Green

# Start the server in background
$serverJob = Start-Job -ScriptBlock {
    lms server start --port 1234 2>&1
}

Write-Host "[*] Waiting for LM Studio server to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

# 2. Verify server is running with retry logic
$maxRetries = 10
$retryCount = 0
$serverReady = $false

while ($retryCount -lt $maxRetries -and -not $serverReady) {
    try {
        $response = Invoke-WebRequest -Uri "http://127.0.0.1:1234/v1/models" -Method GET -TimeoutSec 2 -ErrorAction Stop -UseBasicParsing
        $serverReady = $true
        Write-Host "[+] LM Studio server is ready!" -ForegroundColor Green
    }
    catch {
        $retryCount++
        Write-Host "[*] Waiting for server... ($retryCount/$maxRetries)" -ForegroundColor Yellow
        Start-Sleep -Seconds 2
    }
}

if (-not $serverReady) {
    Write-Host "[-] LM Studio server failed to start after $maxRetries attempts" -ForegroundColor Red
    Write-Host "[!] Please check if:" -ForegroundColor Yellow
    Write-Host "    - LM Studio is installed correctly" -ForegroundColor Yellow
    Write-Host "    - Port 1234 is not already in use" -ForegroundColor Yellow
    Write-Host "    - You have loaded a model in LM Studio" -ForegroundColor Yellow
    Stop-Job -Job $serverJob -ErrorAction SilentlyContinue
    Remove-Job -Job $serverJob -ErrorAction SilentlyContinue
    Read-Host "Press Enter to exit"
    exit 1
}

# 3. Get and display available models
try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:1234/v1/models" -Method GET -TimeoutSec 3 -ErrorAction Stop -UseBasicParsing
    $models = ($response.Content | ConvertFrom-Json).data
    
    if ($models.Count -eq 0) {
        Write-Host "[-] No models loaded in LM Studio" -ForegroundColor Red
        Write-Host "[!] Please load a model in LM Studio and run this script again" -ForegroundColor Yellow
        Stop-Job -Job $serverJob -ErrorAction SilentlyContinue
        Remove-Job -Job $serverJob -ErrorAction SilentlyContinue
        Read-Host "Press Enter to exit"
        exit 1
    }
    
    Write-Host "[+] Available models:" -ForegroundColor Green
    foreach ($model in $models) {
        Write-Host "    - $($model.id)" -ForegroundColor Cyan
    }
    
    # Update config with actual model name
    $configPath = Join-Path $env:USERPROFILE ".openclaw\openclaw.json"
    $actualModelId = $models[0].id
    
    if (Test-Path $configPath) {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        $config.models.providers.lmstudio.models[0].id = $actualModelId
        $config.models.providers.lmstudio.models[0].name = "LM Studio: $actualModelId"
        $config.agent.model = "lmstudio/$actualModelId"
        $config | ConvertTo-Json -Depth 10 | Set-Content $configPath
        Write-Host "[+] Updated config to use model: $actualModelId" -ForegroundColor Green
    }
}
catch {
    Write-Host "[-] Failed to get models from LM Studio: $_" -ForegroundColor Red
    Stop-Job -Job $serverJob -ErrorAction SilentlyContinue
    Remove-Job -Job $serverJob -ErrorAction SilentlyContinue
    Read-Host "Press Enter to exit"
    exit 1
}

# 4. Stop any existing gateway
Write-Host "[*] Stopping any existing gateway processes..." -ForegroundColor Yellow
Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -like "*gateway*"
} | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# 5. Start Gateway in new window
Write-Host "[*] Starting OpenClaw Gateway..." -ForegroundColor Green
$gatewayScript = @"
cd '$PWD'
pnpm openclaw gateway --port 18789 --verbose
"@

Start-Process powershell -ArgumentList "-NoExit", "-Command", $gatewayScript

Write-Host "[*] Waiting for Gateway to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# 6. Test the connection
Write-Host "[*] Testing connection to LM Studio..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

# 7. Open browser to UI
Write-Host "[*] Opening Control UI in browser..." -ForegroundColor Cyan
Start-Process "http://localhost:18789"

# 8. Start interactive agent
Write-Host "`n[*] Starting interactive agent session..." -ForegroundColor Green
Write-Host "You can now chat with your local LM Studio model!" -ForegroundColor Cyan
Write-Host "----------------------------------------------------" -ForegroundColor Gray

pnpm openclaw agent --verbose
