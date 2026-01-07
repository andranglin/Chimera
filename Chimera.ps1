<#
.SYNOPSIS
    Chimera.ps1 - Forensic Console
.DESCRIPTION
    The central orchestration dashboard for the Chimera Triage Toolkit.
    Features modern UI, session tracking, and unified cross-platform operations.
.AUTHOR
    RootGuard (https://github.com/andranglin)
#>

# --- 1. INITIALIZATION ---
$ErrorActionPreference = "SilentlyContinue"
$Host.UI.RawUI.WindowTitle = "Chimera Enterprise Forensics | RootGuard"

# Privilege Check
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $IsAdmin) {
    Write-Warning "Administrator privileges required. Please Run as Administrator."
    Start-Sleep -Seconds 2
    Exit
}

# Path Configuration
$WinModules    = "$PSScriptRoot\Modules\Windows"
$LinuxModules  = "$PSScriptRoot\Modules\Linux"
$CommonModules = "$PSScriptRoot\Modules\Common"

# --- 2. UI ENGINE ---

function Draw-Line {
    param([string]$Color = "DarkGray")
    Write-Host ("-" * 85) -ForegroundColor $Color
}

function Draw-Header {
    Clear-Host
    $Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $User = $env:USERNAME
    $HostName = $env:COMPUTERNAME

    # 1. ASCII ART & TITLE
    Write-Host "
   _______  __   __  ___   __   __  _______  ______    _______ 
  |       ||  | |  ||   | |  |_|  ||       ||    _ |  |   _   |
  |       ||  |_|  ||   | |       ||    ___||   | ||  |  |_|  |
  |       ||       ||   | |       ||   |___ |   |_||_ |       |
  |      _||       ||   | |       ||    ___||    __  ||       |
  |     |_ |   _   ||   | | ||_|| ||   |___ |   |  | ||   _   |
  |_______||__| |__||___| |_|   |_||_______||___|  |_||__| |__|
                                               TRIAGE TOOLKIT v1.0
    " -ForegroundColor Cyan

    Draw-Line "Cyan"

    # 2. TOOL DESCRIPTION / MISSION STATEMENT
    Write-Host "  SYSTEM DESCRIPTION" -ForegroundColor Yellow
    Write-Host "  Enterprise Incident Response & Forensics Orchestration Console." -ForegroundColor Gray
    Write-Host "  Designed for rapid evidence acquisition, triage, and memory analysis." -ForegroundColor Gray
    Write-Host "  NOTE: Authorized for legitimate security investigations only." -ForegroundColor DarkGray
    
    Draw-Line

    # 3. SESSION INFORMATION (Analyst, Host, Time)
    Write-Host "  SESSION TELEMETRY" -ForegroundColor Yellow
    Write-Host "  ANALYST  : " -NoNewline -ForegroundColor Gray
    Write-Host "$User" -ForegroundColor White
    Write-Host "  HOSTNAME : " -NoNewline -ForegroundColor Gray
    Write-Host "$HostName" -ForegroundColor White
    Write-Host "  TIME     : " -NoNewline -ForegroundColor Gray
    Write-Host "$Date" -ForegroundColor White

    Draw-Line
}

function Draw-SectionHeader {
    param([string]$Title, [string]$Color)
    Write-Host "  [ $Title ]" -ForegroundColor $Color
}

function Draw-MenuItem {
    param([string]$Key, [string]$Label, [string]$Desc)
    Write-Host "   $Key. " -NoNewline -ForegroundColor Cyan
    Write-Host "$Label" -NoNewline -ForegroundColor White
    # Padding for alignment
    $Pad = " " * (18 - $Label.Length)
    if ($Desc) {
        Write-Host "$Pad : $Desc" -ForegroundColor DarkGray
    } else {
        Write-Host ""
    }
}

# --- 3. MAIN LOOP ---
while ($true) {
    Draw-Header
    
    # --- WINDOWS MODULES ---
    Draw-SectionHeader "WINDOWS OPERATIONS" "Yellow"
    Draw-MenuItem "1" "Live Response" "Volatile Data & Triage (The Lion)"
    Draw-MenuItem "2" "Artifacts"     "Deep Forensic Collection (The Eagle)"
    Draw-MenuItem "3" "Memory Dump"   "Acquire RAM (Magnet/DumpIt)"
    Draw-MenuItem "4" "Browser Data"  "History & Cache (Hindsight)"
    Draw-MenuItem "5" "KAPE Triage"   "EZParser & SANS Triage"
    Draw-MenuItem "6" "Remote Ops"    "WinRM Push/Pull Acquisition"
    Write-Host ""

    # --- LINUX MODULES ---
    Draw-SectionHeader "LINUX OPERATIONS" "Green"
    Draw-MenuItem "7" "SSH Triage"    "Live Response via SSH (The Goat)"
    Draw-MenuItem "8" "Remote Memory" "Acquire RAM (AVML)"
    Write-Host ""

    # --- ANALYSIS ---
    Draw-SectionHeader "MEMORY ANALYSIS OPERATIONS" "Magenta"
    Draw-MenuItem "9" "Memory Lab"    "Analyze Dump (Volatility 3)"
    
    Draw-Line
    Write-Host "   Q. Quit System" -ForegroundColor DarkGray
    
    # Prompt
    Write-Host ""
    Write-Host "  Chimera" -NoNewline -ForegroundColor Cyan
    $Selection = Read-Host " >"
    
    switch ($Selection) {
        # WINDOWS
        "1" { . "$WinModules\Invoke-WinLiveResponse.ps1" }
        "2" { . "$WinModules\Invoke-WinArtifacts.ps1" }
        "3" { . "$WinModules\Invoke-MemoryCapture.ps1" }
        "4" { . "$WinModules\Invoke-BrowserArtifacts.ps1" }
        "5" { . "$WinModules\Invoke-KapeWrapper.ps1" }
        "6" { 
            Write-Host "`n[*] Initiating Remote Connection Protocol..." -ForegroundColor Cyan
            $Target = Read-Host "    Target IP"
            $Creds  = Get-Credential
            if ($Target -and $Creds) { . "$WinModules\Invoke-RemoteWindows.ps1" -TargetIP $Target -Credential $Creds }
        }

        # LINUX
        "7" { if (Test-Path "$LinuxModules\Invoke-LinuxLiveResponse.ps1") { . "$LinuxModules\Invoke-LinuxLiveResponse.ps1" } else { Write-Warning "Module Missing" ; Pause } }
        "8" { if (Test-Path "$LinuxModules\Invoke-LinuxMemCapture.ps1")   { . "$LinuxModules\Invoke-LinuxMemCapture.ps1" } else { Write-Warning "Module Missing" ; Pause } }

        # ANALYSIS
        "9" { if (Test-Path "$CommonModules\Invoke-MemoryAnalysis.ps1")   { . "$CommonModules\Invoke-MemoryAnalysis.ps1" } else { Write-Warning "Module Missing" ; Pause } }

        "Q" { Clear-Host; Write-Host "System Shutdown." -ForegroundColor Gray; Exit }
        "q" { Clear-Host; Write-Host "System Shutdown." -ForegroundColor Gray; Exit }
        default { }
    }
}