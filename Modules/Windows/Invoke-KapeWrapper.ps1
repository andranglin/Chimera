<#
.SYNOPSIS
    Invoke-KapeWrapper.ps1 - KAPE Orchestration Module 🦁
.DESCRIPTION
    Wraps Kroll Artifact Parser and Extractor (KAPE) for forensic collection.
    Offers preset profiles for Standard vs. Comprehensive triage.
    Requires kape.exe in Tools\Windows\KAPE\.
.AUTHOR
    RootGuard (https://github.com/andranglin)
#>

# --- 1. CONFIGURATION ---
$KapeBinary = "$PSScriptRoot\..\..\Tools\Windows\KAPE\kape.exe"
$Hostname   = $env:COMPUTERNAME
$Timestamp  = Get-Date -Format "yyyyMMdd_HHmm"
$BaseDir    = "C:\Evidence\KAPE"
$CaseDir    = Join-Path $BaseDir "${Hostname}_${Timestamp}"

# --- 2. CHECKS ---
Write-Host "
   CHIMERA KAPE WRAPPER 🦁
   ======================
   Target: $Hostname
   Output: $CaseDir
" -ForegroundColor Yellow

if (-not (Test-Path $KapeBinary)) {
    Write-Error "CRITICAL: 'kape.exe' not found."
    Write-Warning "Please place KAPE in: $KapeBinary"
    Write-Warning "Download from: https://www.kroll.com/en/services/cyber-risk/incident-response-litigation-support/kroll-artifact-parser-extractor-kape"
    Pause
    Return
}

# --- 3. MENU SELECTION ---
Write-Host "    [ SELECT TRIAGE PROFILE ]" -ForegroundColor Cyan
Write-Host "    1. Standard Triage (Target: KapeTriage)"
Write-Host "       - Collects basic artifacts (MFT, Registry, Events, Prefetch)."
Write-Host "       - Fast and efficient for initial scoping."
Write-Host ""
Write-Host "    2. Comprehensive Triage (Target: !SANS_Triage)"
Write-Host "       - Collects deep artifacts (Amcache, SRUM, Full Event Logs, $MFT)."
Write-Host "       - significantly more data."
Write-Host ""
Write-Host "    3. Custom Command"
Write-Host "       - Enter your own Target and Module."
Write-Host ""

$Selection = Read-Host "    Select Option (1-3)"

switch ($Selection) {
    "1" {
        $Target = "KapeTriage"
        $Module = "!EZParser"
        $Desc   = "Standard"
    }
    "2" {
        $Target = "!SANS_Triage"
        $Module = "!EZParser"
        $Desc   = "Comprehensive"
    }
    "3" {
        $Target = Read-Host "    Enter Target (e.g., RegistryHives)"
        $Module = Read-Host "    Enter Module (e.g., !EZParser)"
        $Desc   = "Custom"
    }
    default {
        Write-Warning "Invalid Selection. Defaulting to Standard."
        $Target = "KapeTriage"
        $Module = "!EZParser"
        $Desc   = "Standard"
    }
}

# --- 4. EXECUTION ---
New-Item -Path $CaseDir -ItemType Directory -Force | Out-Null

Write-Host "`n[*] Launching KAPE ($Desc Profile)..." -ForegroundColor Yellow
Write-Host "    Target: $Target"
Write-Host "    Module: $Module"
Write-Host "    This console will pause until KAPE finishes." -ForegroundColor DarkGray

# Build Arguments
# --tflush: Delete target destination if exists
# --mflush: Delete module destination if exists
# --gui: Show the KAPE GUI so you can see progress bars (remove if you want silent execution)
$ArgsList = "--tsource C: --tdest `"$CaseDir\Source`" --tflush --target $Target --mdest `"$CaseDir\Processed`" --module $Module --mflush --gui"

Start-Process -FilePath $KapeBinary -ArgumentList $ArgsList -Wait

# --- 5. REPORTING ---
Write-Host "`n[+] KAPE Processing Complete!" -ForegroundColor Green
Write-Host "    Raw Evidence:  $CaseDir\Source"
Write-Host "    Parsed Output: $CaseDir\Processed"

# Check if KAPE generated a timeline or CSVs
if (Test-Path "$CaseDir\Processed") {
    Invoke-Item "$CaseDir\Processed"
}

Pause