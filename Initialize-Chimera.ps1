<#
.SYNOPSIS
    Initialize-Chimera.ps1 - Setup & Verification Utility
.DESCRIPTION
    1. Creates the complete folder structure for Chimera (Modules, Tools, Config).
    2. Adds .gitkeep files to empty tool folders (Essential for Git tracking).
    3. Checks if required third-party tools (EZTools, KAPE, AVML) are present.
    4. Unblocks scripts to prevent ExecutionPolicy errors.
.AUTHOR
    RootGuard
#>

$BaseDir = $PSScriptRoot

# --- 1. DEFINE DIRECTORY STRUCTURE ---
# This matches the structure defined in your INSTALL.md
$Folders = @(
    # Modules
    "Modules\Common",
    "Modules\Windows",
    "Modules\Linux",
    
    # Tools - Windows
    "Tools\Windows\EZTools",
    "Tools\Windows\KAPE",
    "Tools\Windows\Hindsight",
    "Tools\Windows\Memory",
    
    # Tools - Linux
    "Tools\Linux",
    "Tools\Linux\Memory",
    
    # Tools - Common
    "Tools\Common\volatility3",
    
    # Configuration & Output
    "Config",
    "Output"
)

# --- 2. CREATE FOLDERS ---
Write-Host "`n[*] Initializing Chimera Directory Structure..." -ForegroundColor Cyan

foreach ($Folder in $Folders) {
    $Path = Join-Path $BaseDir $Folder
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
        Write-Host "    [+] Created: $Folder" -ForegroundColor Green
    } else {
        Write-Host "    [.] Exists:  $Folder" -ForegroundColor Gray
    }
    
    # Add .gitkeep to ensure empty folders are tracked by Git
    # Without this, empty 'Tools' folders won't show up on GitHub
    $GitKeep = Join-Path $Path ".gitkeep"
    if (-not (Test-Path $GitKeep)) {
        New-Item -Path $GitKeep -ItemType File -Force | Out-Null
    }
}

# --- 3. TOOL VERIFICATION ---
Write-Host "`n[*] Verifying Third-Party Tools..." -ForegroundColor Cyan

$CriticalTools = @(
    @{ Name="RECmd";       Path="Tools\Windows\EZTools\RECmd.exe" },
    @{ Name="KAPE";        Path="Tools\Windows\KAPE\kape.exe" },
    @{ Name="Hindsight";   Path="Tools\Windows\Hindsight\hindsight.exe" },
    @{ Name="AVML";        Path="Tools\Linux\avml" },
    @{ Name="Volatility";  Path="Tools\Common\volatility3\vol.py" }
)

$MissingTools = $false

foreach ($Tool in $CriticalTools) {
    $ToolPath = Join-Path $BaseDir $Tool.Path
    if (Test-Path $ToolPath) {
        Write-Host "    [V] Found: $($Tool.Name)" -ForegroundColor Green
    } else {
        Write-Host "    [X] MISSING: $($Tool.Name) (Expected at: $($Tool.Path))" -ForegroundColor Red
        $MissingTools = $true
    }
}

# --- 4. UNBLOCK SCRIPTS ---
Write-Host "`n[*] Unblocking PowerShell Scripts..." -ForegroundColor Cyan
try {
    Get-ChildItem -Path $BaseDir -Recurse -Filter "*.ps1" | Unblock-File
    Write-Host "    [V] All scripts unblocked." -ForegroundColor Green
} catch {
    Write-Warning "    [!] Could not unblock scripts. Ensure you are running as Administrator."
}

# --- 5. SUMMARY ---
Write-Host "`n----------------------------------------"
if ($MissingTools) {
    Write-Warning "SETUP INCOMPLETE: Some tools are missing."
    Write-Host "Please download the missing binaries as described in INSTALL.md." -ForegroundColor Yellow
} else {
    Write-Host "SETUP COMPLETE: Chimera is ready to roar! 🦁" -ForegroundColor Green
    Write-Host "Run '.\Chimera.ps1' to start the main menu." -ForegroundColor Cyan
}
Write-Host "----------------------------------------`n"