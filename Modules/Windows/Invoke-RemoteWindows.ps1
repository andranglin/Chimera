<#
.SYNOPSIS
    Invoke-RemoteWindows.ps1 - Chimera Remote Acquisition 🦁
.DESCRIPTION
    The "Zip & Ship" Module.
    1. Pushes the Live Response script to a remote target via WinRM.
    2. Executes the triage locally on the target.
    3. Compresses the HTML Report and CSVs.
    4. Downloads the Zip evidence file to your machine.
    5. Performs secure cleanup on the target.
.AUTHOR
    RootGuard (https://github.com/andranglin)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$TargetIP,
    
    [PSCredential]$Credential
)

# --- CONFIGURATION ---
$LocalScript   = "$PSScriptRoot\Invoke-WinLiveResponse.ps1"
$RemoteStage   = "C:\Windows\Temp\Chimera_Stage"
$RemoteOutput  = "C:\Forensics\DeepDive"  # Must match the Output path in WinLiveResponse
$LocalEvidence = "C:\Evidence\Remote_Collections"

# --- VISUALS ---
Write-Host "
   CHIMERA REMOTE ACQUISITION (WinRM) 🦁
   =====================================
   Target: $TargetIP
   Payload: Invoke-WinLiveResponse.ps1
" -ForegroundColor Yellow

if (-not (Test-Path $LocalScript)) {
    Write-Error "CRITICAL: Could not find 'Invoke-WinLiveResponse.ps1' in the current directory."
    Return
}

# --- 1. CONNECTION ---
Write-Host "[*] Establishing PSSession to $TargetIP..." -ForegroundColor Cyan
try {
    if ($Credential) {
        $Session = New-PSSession -ComputerName $TargetIP -Credential $Credential -ErrorAction Stop
    } else {
        $Session = New-PSSession -ComputerName $TargetIP -ErrorAction Stop
    }
} catch {
    Write-Error "Connection Failed: $_"
    Write-Warning "Ensure WinRM is enabled on target: 'winrm quickconfig'"
    Return
}

# --- 2. STAGING & PUSH ---
Write-Host "[*] Creating Staging Directory ($RemoteStage)..." -ForegroundColor Cyan
Invoke-Command -Session $Session -ScriptBlock { param($Path) New-Item -Path $Path -ItemType Directory -Force | Out-Null } -ArgumentList $RemoteStage

Write-Host "[*] Pushing Triage Script Payload..." -ForegroundColor Cyan
Copy-Item -Path $LocalScript -Destination $RemoteStage -ToSession $Session

# --- 3. EXECUTION ---
Write-Host "[*] Executing Live Response on Target (This may take 1-2 mins)..." -ForegroundColor Yellow
Invoke-Command -Session $Session -ScriptBlock {
    param($Stage, $ScriptPath)
    
    # Run the script (It will output to C:\Forensics\DeepDive by default)
    Set-Location $Stage
    & ".\Invoke-WinLiveResponse.ps1"
    
} -ArgumentList $RemoteStage

# --- 4. COMPRESSION ---
Write-Host "[*] Compressing Remote Evidence..." -ForegroundColor Cyan
$RemoteZip = "$RemoteStage\Evidence_$($TargetIP).zip"

Invoke-Command -Session $Session -ScriptBlock {
    param($SourceDir, $ZipPath)
    
    if (Test-Path $SourceDir) {
        # Find the most recent case folder
        $LatestCase = Get-ChildItem $SourceDir | Sort-Object CreationTime -Descending | Select-Object -First 1
        
        if ($LatestCase) {
            Write-Host "    Found Case: $($LatestCase.FullName)"
            Compress-Archive -Path $LatestCase.FullName -DestinationPath $ZipPath -Force
        }
    }
} -ArgumentList $RemoteOutput, $RemoteZip

# --- 5. RETRIEVAL ---
if (-not (Test-Path $LocalEvidence)) { New-Item -Path $LocalEvidence -ItemType Directory -Force | Out-Null }
$LocalZip = Join-Path $LocalEvidence "Evidence_$($TargetIP)_$(Get-Date -Format 'yyyyMMdd-HHmm').zip"

Write-Host "[*] Pulling Evidence to Local Machine..." -ForegroundColor Green
try {
    Copy-Item -Path $RemoteZip -Destination $LocalZip -FromSession $Session -ErrorAction Stop
    Write-Host "    [+] Success! Saved to: $LocalZip" -ForegroundColor Green
} catch {
    Write-Error "Failed to retrieve evidence: $_"
}

# --- 6. CLEANUP ---
Write-Host "[*] Cleaning up Remote Artifacts..." -ForegroundColor Cyan
Invoke-Command -Session $Session -ScriptBlock {
    param($Stage, $Output)
    Remove-Item -Path $Stage -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $Output -Recurse -Force -ErrorAction SilentlyContinue
} -ArgumentList $RemoteStage, $RemoteOutput

Remove-PSSession $Session
Write-Host "`n[+] Session Closed. Operation Complete." -ForegroundColor Cyan
Pause