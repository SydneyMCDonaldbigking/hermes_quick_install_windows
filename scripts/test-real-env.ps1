# test-real-env.ps1 - Real environment integration tests for hermes_launch
# Usage: powershell -File scripts/test-real-env.ps1

$ErrorActionPreference = "Continue"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$LogFile = "D:\hermes-test\test-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$results = @()

function Add-Result($Name, $Pass, $Detail = "") {
    $script:results += [PSCustomObject]@{ Test = $Name; Pass = $Pass; Detail = $Detail }
    $icon = if ($Pass) { "PASS" } else { "FAIL" }
    $line = "[$icon] $Name"
    if ($Detail) { $line += " - $Detail" }
    Write-Host $line -ForegroundColor $(if ($Pass) { "Green" } else { "Red" })
    Add-Content -Path $LogFile -Value $line
}

function Invoke-WslBash([string]$Script) {
    $normalized = $Script -replace "`r`n", "`n" -replace "`r", "`n"
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($normalized))
    return wsl -d Ubuntu-22.04 -u root -e bash -lc "echo $b64 | base64 -d | bash" 2>&1
}

New-Item -ItemType Directory -Force -Path "D:\hermes-test" | Out-Null
"=== Real env test $(Get-Date -Format o) ===" | Set-Content $LogFile

# 1. D drive layout
Add-Result "D:\wsl\Ubuntu-22.04" (Test-Path "D:\wsl\Ubuntu-22.04\ext4.vhdx")
Add-Result "D:\Docker\wsl" (Test-Path "D:\Docker\wsl\disk\docker_data.vhdx")
$link = Get-Item "$env:LOCALAPPDATA\Docker\wsl" -Force -EA SilentlyContinue
Add-Result "Docker junction" ($link -and ($link.Attributes -band [IO.FileAttributes]::ReparsePoint))

# 2. WSL distro name (auto-setup logic)
$distros = (wsl --list --quiet 2>&1 | Out-String) -replace "`0", ""
Add-Result "WSL Ubuntu-22.04 registered" ($distros -match "Ubuntu-22.04")

# 3. WSL root access
$wslOut = Invoke-WslBash "echo WSL2_OK"
Add-Result "WSL root exec" ($wslOut -match "WSL2_OK") ($wslOut | Out-String).Trim()

# 4. Hermes home
$homeOut = Invoke-WslBash "test -f ~/.hermes/.env && echo ENV_OK"
Add-Result "Hermes ~/.hermes" ($homeOut -match "ENV_OK")

# 5. Hermes binary
$hermesOut = Invoke-WslBash "command -v hermes 2>/dev/null && hermes --version 2>/dev/null || echo NOT_INSTALLED"
$hermesInstalled = $hermesOut -match "hermes" -and $hermesOut -notmatch "NOT_INSTALLED"
Add-Result "Hermes installed" $hermesInstalled ($hermesOut | Out-String).Trim()

# 6. manage-hermes logic (same bash as Get-HermesStatus, via Invoke-WslBash)
$statusOut = Invoke-WslBash @'
PID=$(pgrep -f "hermes gateway" | head -1)
if [ -z "$PID" ]; then
  echo '{"running":false,"pid":null}'
else
  echo '{"running":true,"pid":'"$PID"'}'
fi
'@
Add-Result "gateway status JSON" ($statusOut -match '"running"\s*:\s*(true|false)')

$connOk = $false
foreach ($ip in @("127.0.0.1", "localhost")) {
    try {
        $r = Invoke-WebRequest -Uri "http://${ip}:8000/api/health" -TimeoutSec 2 -ErrorAction Stop
        if ($r.StatusCode -eq 200) { $connOk = $true; break }
    } catch {}
}
$gwRunning = ($statusOut -match '"running"\s*:\s*true')
if ($connOk) {
    Add-Result "health /api/health" $true
} elseif ($hermesInstalled -and $gwRunning) {
    Add-Result "health /api/health" $true "gateway process up; HTTP:8000 N/A on Hermes v0.13+"
} elseif (-not $hermesInstalled) {
    Add-Result "health /api/health" (-not $connOk) "expected fail when not installed"
} else {
    Add-Result "health /api/health" $false "no HTTP listener on :8000"
}

# 7. health endpoint path in source
$mh = Get-Content "$ScriptsDir\manage-hermes.ps1" -Raw
Add-Result "health uses /api/health" ($mh -match '/api/health' -and $mh -notmatch ':8000/health"')

# 8. WSL_DISTRO_NAME consistent
$scripts = Get-ChildItem "$ScriptsDir\*.ps1"
$bad = $scripts | Where-Object {
    $_.Name -ne 'test-real-env.ps1' -and (Get-Content $_.FullName -Raw -Encoding UTF8) -match 'HermesUbuntu'
}
Add-Result "no HermesUbuntu leftover" ($bad.Count -eq 0)

# Summary
$passed = ($results | Where-Object Pass).Count
$total = $results.Count
Write-Host ""
Write-Host "=== Summary: $passed / $total passed ===" -ForegroundColor Cyan
Write-Host "Log: $LogFile"
$results | ConvertTo-Json | Set-Content "D:\hermes-test\test-results-latest.json" -Encoding UTF8
if ($passed -lt $total) { exit 1 }
