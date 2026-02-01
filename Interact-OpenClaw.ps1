# Interact-OpenClaw.ps1
# This script launches the OpenClaw Gateway and starts an interactive Agent session.

Function Write-Lobster {
    Write-Host "      _ _" -ForegroundColor Cyan
    Write-Host "     ( ) )" -ForegroundColor Cyan
    Write-Host "      ) (      🦞 OpenClaw" -ForegroundColor Cyan
    Write-Host "    ( ) ) )" -ForegroundColor Cyan
    Write-Host "     ) ( (" -ForegroundColor Cyan
    Write-Host "    ( ) ) )" -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan
}

Function Test-Dependency {
    param($Name, $Command)
    if (!(Get-Command $Command -ErrorAction SilentlyContinue)) {
        Write-Host "[-] Error: $Name is not installed ($Command)." -ForegroundColor Red
        return $false
    }
    Write-Host "[+] Found $Name" -ForegroundColor Green
    return $true
}

Clear-Host
Write-Lobster

# 1. Dependency Checks
if (!(Test-Dependency "pnpm" "pnpm") -or !(Test-Dependency "Node.js" "node")) {
    Write-Host "Please install the missing dependencies and try again." -ForegroundColor Yellow
    exit 1
}

# 2. Setup (if needed)
if (!(Test-Path "node_modules")) {
    Write-Host "[*] First time setup: Installing dependencies..." -ForegroundColor Yellow
    pnpm install
}

if (!(Test-Path "dist")) {
    Write-Host "[*] Building project..." -ForegroundColor Yellow
    pnpm build
    pnpm ui:build
}

# 3. Check configuration
$ConfigPath = Join-Path $HOME ".openclaw\openclaw.json"
if (!(Test-Path $ConfigPath)) {
    Write-Host "[!] No configuration found at $ConfigPath" -ForegroundColor Magenta
    $Choice = Read-Host "Would you like to run the onboarding wizard now? (y/n)"
    if ($Choice -eq 'y') {
        pnpm openclaw onboard
    }
    else {
        Write-Host "Warning: The agent might fail to start without models configured." -ForegroundColor Yellow
    }
}

# 4. Starting Gateway
Write-Host "[*] Starting Gateway on port 18789 in a new window..." -ForegroundColor Green
Start-Process powershell -ArgumentList "-NoExit", "-Command", "pnpm openclaw gateway --port 18789"

Write-Host "[*] Waiting a few seconds for Gateway to initialize..." -ForegroundColor Green
Start-Sleep -Seconds 3

# 5. Interacting with Agent
Write-Host "[*] Launching Interactive Agent Mode..." -ForegroundColor Cyan
Write-Host "Type your messages below. Use Ctrl+C to exit." -ForegroundColor Gray
Write-Host "----------------------------------------------------" -ForegroundColor Gray

# Run the agent command. Use --verbose for better debug info.
pnpm openclaw agent --verbose
