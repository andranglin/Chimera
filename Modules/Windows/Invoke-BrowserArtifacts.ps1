<#
.SYNOPSIS
    Invoke-BrowserArtifacts.ps1 - Browser Forensics (Evidence Only) 🦁
.DESCRIPTION
    1. Mounts Volume Shadow Copy (VSS) to bypass file locks.
    2. Auto-discovers valid Browser Profiles (Chrome, Edge, Brave).
    3. Generates forensic XLSX (Excel) reports for each profile.
    4. Organizes output into dedicated folders.
.AUTHOR
    RootGuard (https://github.com/andranglin)
#>

$ErrorActionPreference = "Continue"
$HindsightPath = "$PSScriptRoot\..\..\Tools\Windows\Hindsight\hindsight.exe"
$Hostname      = $env:COMPUTERNAME
$Timestamp     = Get-Date -Format "yyyyMMdd_HHmm"
$OutputBase    = "C:\Evidence\Browsers"
$CaseDir       = Join-Path $OutputBase "${Hostname}_${Timestamp}"
$VssMount      = "C:\Chimera_VSS"

Write-Host "
   CHIMERA BROWSER FORENSICS (EVIDENCE COLLECTION) 🦁
   ==================================================
   Target: $Hostname
   Output: $CaseDir
" -ForegroundColor Yellow

if (-not (Test-Path $HindsightPath)) {
    Write-Error "CRITICAL: 'hindsight.exe' not found at $HindsightPath"
    Pause; Return
}

New-Item -Path $CaseDir -ItemType Directory -Force | Out-Null

# --- 1. VSS MOUNT ---
Write-Host "    [*] Creating Volume Shadow Copy..." -ForegroundColor Cyan
try {
    if (Test-Path $VssMount) { cmd /c rmdir $VssMount }
    $Vss = (Get-WmiObject -List Win32_ShadowCopy).Create("C:\", "ClientAccessible")
    $ShadowID = $Vss.ShadowID
    $ShadowVol = (Get-WmiObject Win32_ShadowCopy | Where-Object { $_.ID -eq $ShadowID }).DeviceObject
    cmd /c mklink /d $VssMount "$ShadowVol\" | Out-Null
    if (Test-Path "$VssMount\Users") { $SourceRoot = $VssMount; Write-Host "    [+] VSS Mounted" -ForegroundColor Green } 
    else { throw "Mount Failed" }
} catch {
    Write-Warning "    [!] VSS Failed. Using Live System."
    $SourceRoot = "C:"
}

# --- 2. PROFILE DISCOVERY ---
$UserPath = "$SourceRoot\Users"
$BrowserRoots = @(
    @{ Name="Chrome"; Path="AppData\Local\Google\Chrome\User Data" },
    @{ Name="Edge";   Path="AppData\Local\Microsoft\Edge\User Data" },
    @{ Name="Brave";  Path="AppData\Local\BraveSoftware\Brave-Browser\User Data" }
)

$ValidProfiles = @()
$Users = Get-ChildItem -Path $UserPath -Directory | Where-Object { $_.Name -notin "All Users","Default","Default User","Public" }

foreach ($User in $Users) {
    foreach ($B in $BrowserRoots) {
        $UserDataPath = Join-Path $User.FullName $B.Path
        if (Test-Path $UserDataPath) {
            $PotentialProfiles = Get-ChildItem -Path $UserDataPath -Directory
            foreach ($P in $PotentialProfiles) {
                # Check for History file to confirm it's a real profile
                if (Test-Path (Join-Path $P.FullName "History")) {
                    Write-Host "    [+] Found $($B.Name): $($User.Name) ($($P.Name))" -ForegroundColor Green
                    $ValidProfiles += [PSCustomObject]@{ Browser=$B.Name; User=$User.Name; Profile=$P.Name; Path=$P.FullName }
                }
            }
        }
    }
}

if ($ValidProfiles.Count -eq 0) {
    Write-Warning "    [!] No browser profiles found."
    if (Test-Path $VssMount) { cmd /c rmdir $VssMount }
    Pause; Return
}

# --- 3. EXECUTION ---
foreach ($Target in $ValidProfiles) {
    $JobName = "$($Target.User)_$($Target.Browser)_$($Target.Profile)"
    $JobFolder = Join-Path $CaseDir $JobName
    New-Item -Path $JobFolder -ItemType Directory -Force | Out-Null
    
    $OutputFile = Join-Path $JobFolder "Report"
    
    Write-Host "    [*] Processing: $JobName" -ForegroundColor Cyan
    
    # Generate XLSX Only
    $ArgsList = "-i `"$($Target.Path)`" -o `"$OutputFile`" --format xlsx"
    $Process = Start-Process -FilePath $HindsightPath -ArgumentList $ArgsList -Wait -PassThru -WindowStyle Hidden
    
    if (Test-Path "$OutputFile.xlsx") {
        Write-Host "        [V] Report Generated: $OutputFile.xlsx" -ForegroundColor Gray
    } else {
        Write-Warning "        [!] Report Generation Failed."
    }
}

# --- 4. CLEANUP ---
if (Test-Path $VssMount) { cmd /c rmdir $VssMount }

Write-Host "
   [+] COLLECTION COMPLETE
   -----------------------
   Evidence saved to: $CaseDir
" -ForegroundColor Cyan

Invoke-Item $CaseDir
Pause