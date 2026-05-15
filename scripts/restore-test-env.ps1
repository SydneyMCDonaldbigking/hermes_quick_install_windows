# restore-test-env.ps1 - Restore Hermes test environment on D: drive
param(
    [switch]$InitHermes,
    [switch]$InstallHermes
)

$WSL_DISTRO_NAME = "Ubuntu-22.04"
$WSL_DATA_ROOT = "D:\wsl"
$DOCKER_DATA_ROOT = "D:\Docker\wsl"
$DOCKER_LINK = "$env:LOCALAPPDATA\Docker\wsl"
$TEST_ENV_ROOT = "D:\hermes-test"
$PROJECT_ROOT = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Write-Step([string]$Msg, [string]$Level = "Info") {
    $c = @{ Info = "Cyan"; Success = "Green"; Warning = "Yellow"; Error = "Red" }
    Write-Host $Msg -ForegroundColor $c[$Level]
}

function Invoke-WslBash([string]$Script) {
    $normalized = $Script -replace "`r`n", "`n" -replace "`r", "`n"
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($normalized))
    return wsl -d $WSL_DISTRO_NAME -u root -e bash -lc "echo $b64 | base64 -d | bash" 2>&1
}

function Test-DriveLayout {
    Write-Step "=== 1. D drive layout ==="
    $ok = $true
    @($WSL_DATA_ROOT, $DOCKER_DATA_ROOT, $TEST_ENV_ROOT) | ForEach-Object {
        if (-not (Test-Path $_)) { New-Item -ItemType Directory -Force -Path $_ | Out-Null }
    }
    $ubuntuVhd = "$WSL_DATA_ROOT\Ubuntu-22.04\ext4.vhdx"
    if (Test-Path $ubuntuVhd) {
        $gb = [math]::Round((Get-Item $ubuntuVhd).Length / 1GB, 2)
        Write-Step "  OK Ubuntu: $ubuntuVhd size=${gb}G" "Success"
    } else {
        Write-Step "  MISSING: $ubuntuVhd" "Error"
        $ok = $false
    }
    $dockerVhd = "$DOCKER_DATA_ROOT\disk\docker_data.vhdx"
    if (Test-Path $dockerVhd) {
        $gb = [math]::Round((Get-Item $dockerVhd).Length / 1GB, 2)
        Write-Step "  OK Docker: $dockerVhd size=${gb}G" "Success"
    } else {
        Write-Step "  MISSING: $dockerVhd" "Warning"
    }
    return $ok
}

function Repair-DockerJunction {
    Write-Step "=== 2. Docker junction ==="
    if (-not (Test-Path $DOCKER_DATA_ROOT)) { return $false }
    if (Test-Path $DOCKER_LINK) {
        $item = Get-Item $DOCKER_LINK -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Write-Step "  OK junction exists" "Success"
            return $true
        }
        Write-Step "  WARN: $DOCKER_LINK is not a junction" "Warning"
        return $false
    }
    $parent = Split-Path $DOCKER_LINK -Parent
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    cmd /c mklink /J "$DOCKER_LINK" "$DOCKER_DATA_ROOT" | Out-Null
    if (Test-Path $DOCKER_LINK) {
        Write-Step "  OK created junction -> $DOCKER_DATA_ROOT" "Success"
        return $true
    }
    Write-Step "  FAIL junction" "Error"
    return $false
}

function Test-WslDistro {
    Write-Step "=== 3. WSL distro ==="
    $distros = (wsl --list --quiet 2>&1 | Out-String) -replace "`0", ""
    if ($distros -notmatch $WSL_DISTRO_NAME) {
        Write-Step "  NOT FOUND: $WSL_DISTRO_NAME" "Error"
        return $false
    }
    Write-Step "  OK registered: $WSL_DISTRO_NAME" "Success"
    wsl --set-default $WSL_DISTRO_NAME 2>&1 | Out-Null
    $out = Invoke-WslBash "echo WSL_OK"
    if ($out -match "WSL_OK") {
        Write-Step "  OK WSL commands work" "Success"
        return $true
    }
    Write-Step "  FAIL: $out" "Error"
    return $false
}

function Initialize-HermesHomeWsl {
    Write-Step "=== 4. Init ~/.hermes ==="
    $script = @'
mkdir -p ~/.hermes/logs ~/.hermes/config ~/.hermes/data
if [ ! -f ~/.hermes/.env ]; then
  printf "%s\n" "HERMES_PORT=8000" "HERMES_HOST=0.0.0.0" > ~/.hermes/.env
fi
echo HERMES_HOME_OK
'@
    $out = Invoke-WslBash $script
    if ($out -match "HERMES_HOME_OK") {
        Write-Step "  OK ~/.hermes ready" "Success"
        return $true
    }
    Write-Step "  FAIL: $out" "Error"
    return $false
}

function Install-HermesAgentWsl {
    Write-Step "=== 5. Install Hermes (10-20 min) ==="
    $script = @'
mkdir -p ~/.hermes/logs
cd ~/.hermes
curl -fsSL -o install_hermes.sh https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh
chmod +x install_hermes.sh
bash ./install_hermes.sh 2>&1 | tee -a ~/.hermes/logs/install.log
command -v hermes
hermes --version
echo HERMES_INSTALL_OK
'@
    $out = Invoke-WslBash $script
    if ($LASTEXITCODE -eq 0 -and ($out | Out-String) -match "HERMES_INSTALL_OK") {
        Write-Step "  OK Hermes installed" "Success"
        return $true
    }
    Write-Step "  WARN install incomplete, see ~/.hermes/logs/install.log" "Warning"
    return $false
}

function Write-EnvManifest {
    $manifest = @{
        updatedAt      = (Get-Date -Format "o")
        projectRoot    = $PROJECT_ROOT
        wslDistro      = $WSL_DISTRO_NAME
        wslDataRoot    = $WSL_DATA_ROOT
        dockerDataRoot = $DOCKER_DATA_ROOT
        dockerLink     = $DOCKER_LINK
        testEnvRoot    = $TEST_ENV_ROOT
        hermesPort     = 8000
        healthEndpoint = "/api/health"
    }
    $path = "$TEST_ENV_ROOT\env.json"
    $manifest | ConvertTo-Json -Depth 3 | Set-Content -Path $path -Encoding UTF8
    Write-Step "=== Manifest: $path ===" "Success"
}

Write-Host ""
Write-Step "Hermes test env restore (D:)" "Info"
Write-Host ""

$allOk = Test-DriveLayout
Repair-DockerJunction | Out-Null
$allOk = (Test-WslDistro) -and $allOk

if ($InitHermes -or $InstallHermes) { Initialize-HermesHomeWsl | Out-Null }
if ($InstallHermes) {
    Install-HermesAgentWsl | Out-Null
} else {
    $hermes = Invoke-WslBash "command -v hermes 2>/dev/null || echo NOT_INSTALLED"
    if ($hermes -match "hermes") {
        Write-Step "  Hermes installed: $hermes" "Success"
    } else {
        Write-Step "  Hermes not installed. Use -InstallHermes or install-hermes.ps1" "Warning"
    }
}

Write-EnvManifest
Write-Host ""
if ($allOk) {
    Write-Step "Done. Next (Admin PowerShell):" "Success"
    Write-Host "  cd $PROJECT_ROOT"
    Write-Host "  .\scripts\auto-setup.ps1"
} else {
    Write-Step "Some checks failed. See messages above." "Warning"
}
