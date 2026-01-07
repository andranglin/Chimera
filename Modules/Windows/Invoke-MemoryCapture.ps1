<#
.SYNOPSIS
    Invoke-MemoryCapture.ps1 - Windows RAM Acquisition
.DESCRIPTION
    Interactive menu to choose between MagnetRAMCapture and DumpIt.
    Requires binaries in Tools\Windows\Memory\ subfolders.
.AUTHOR
    RootGuard (https://github.com/andranglin)
#>

$ToolsBase = "$PSScriptRoot\..\..\Tools\Windows\Memory"
$Output    = "C:\Evidence\Memory"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmm"

# Create Output Directory
if (-not (Test-Path $Output)) { 
    New-Item -Path $Output -ItemType Directory -Force | Out-Null 
}

# Define Tool Paths
$MagnetPath = Join-Path $ToolsBase "MagnetRAMCapture\MagnetRAMCapture.exe"
$DumpItPath = Join-Path $ToolsBase "DumpIt\DumpIt.exe"

# Visual Header
Write-Host "
   CHIMERA MEMORY ACQUISITION 🧠
   =============================
   Target: $env:COMPUTERNAME
   Output: $Output
" -ForegroundColor Yellow

# Check availability
$MagnetExists = Test-Path $MagnetPath
$DumpItExists = Test-Path $DumpItPath

if (-not $MagnetExists -and -not $DumpItExists) {
    Write-Error "CRITICAL: No Memory Acquisition tools found."
    Write-Warning "Please populate:"
    Write-Warning " - $MagnetPath"
    Write-Warning " - $DumpItPath"
    Pause
    Return
}

# Menu Selection
Write-Host "    [ SELECT ACQUISITION TOOL ]" -ForegroundColor Cyan
if ($MagnetExists) { Write-Host "    1. Magnet RAM Capture (Raw .dmp)" } else { Write-Host "    1. Magnet RAM Capture (Missing)" -ForegroundColor DarkGray }
if ($DumpItExists) { Write-Host "    2. Comae DumpIt (Raw .raw/dmp)" } else { Write-Host "    2. Comae DumpIt (Missing)" -ForegroundColor DarkGray }
Write-Host ""
$Selection = Read-Host "    Select Option (1 or 2)"

switch ($Selection) {
    "1" {
        if ($MagnetExists) {
            $MemFile = Join-Path $Output "Memory_Magnet_$Timestamp.raw"
            Write-Host "`n[*] Launching Magnet RAM Capture..." -ForegroundColor Yellow
            Write-Host "    Saving to: $MemFile"
            
            # Execute Magnet (Accept EULA, Go to path)
            Start-Process -FilePath $MagnetPath -ArgumentList "/accepteula /go `"$MemFile`"" -Wait
            
            if (Test-Path $MemFile) { Write-Host "[+] Acquisition Complete!" -ForegroundColor Green }
        } else {
            Write-Warning "Magnet RAM Capture binary is missing."
        }
    }
    "2" {
        if ($DumpItExists) {
            Write-Host "`n[*] Launching DumpIt..." -ForegroundColor Yellow
            
            # DumpIt interaction varies by version. 
            # We push location to Output so the dump lands there automatically.
            Push-Location $Output
            Start-Process -FilePath $DumpItPath -Wait
            Pop-Location
            
            Write-Host "[+] Process Finished. Check output folder for artifacts." -ForegroundColor Green
        } else {
            Write-Warning "DumpIt binary is missing."
        }
    }
    default {
        Write-Warning "Invalid selection."
    }
}

Pause