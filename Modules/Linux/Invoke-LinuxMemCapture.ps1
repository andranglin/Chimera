<#
.SYNOPSIS
    Invoke-LinuxMemCapture.ps1 - The Memory Hunter (Streamline Edition) ⚡
.DESCRIPTION
    1. Uploads AVML.
    2. Pipes RAM capture DIRECTLY into Gzip (Bypasses disk I/O bottleneck).
    3. Downloads the compressed image immediately.
.NOTE
    Resulting file is .lime.gz.
.AUTHOR
    RootGuard
#>

param (
    [Parameter(Mandatory=$false)]
    [string]$TargetIP,

    [Parameter(Mandatory=$false)]
    [string]$Username
)

# --- 1. CONFIGURATION ---
$Hostname   = $env:COMPUTERNAME
$Timestamp  = Get-Date -Format "yyyyMMdd_HHmm"
$BaseDir    = "C:\Evidence\LinuxMemory"
$CaseDir    = Join-Path $BaseDir "MemDump_$Timestamp"
$AvmlPath   = "$PSScriptRoot\..\..\Tools\Linux\avml" 

# SSH Options
$SshOpts = @("-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-o", "LogLevel=ERROR", "-c", "aes128-ctr") 

# --- 2. HEADER ---
Write-Host "
   CHIMERA LINUX MEMORY (STREAMLINE) ⚡
   ===================================
" -ForegroundColor Magenta

if (-not (Test-Path $AvmlPath)) {
    Write-Error "CRITICAL: 'avml' binary not found at $AvmlPath"
    Pause; Return
}

if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) { Write-Error "CRITICAL: 'ssh' not found."; Return }
if ([string]::IsNullOrWhiteSpace($TargetIP)) { $TargetIP = Read-Host "    Target IP Address" }
if ([string]::IsNullOrWhiteSpace($Username)) { $Username = Read-Host "    SSH Username" }
if (-not $TargetIP -or -not $Username) { Write-Warning "Missing inputs."; Return }

New-Item -Path $CaseDir -ItemType Directory -Force | Out-Null
Write-Host "    Target: $Username@$TargetIP"
Write-Host "    Output: $CaseDir"

# --- HELPER ---
function Invoke-InteractiveCommand {
    param($Exe, $ArgsList)
    $Process = Start-Process -FilePath $Exe -ArgumentList $ArgsList -NoNewWindow -PassThru -Wait
    return $Process.ExitCode
}

# --- 3. UPLOAD AVML ---
Write-Host "`n    [*] Uploading AVML Tool (1/4)..." -ForegroundColor Yellow
$RemoteAvml = "/tmp/avml"
$ScpArgs = $SshOpts + @("$AvmlPath", "${Username}@${TargetIP}:$RemoteAvml")

if ((Invoke-InteractiveCommand "scp" $ScpArgs) -ne 0) { 
    Write-Warning "Upload Failed."
    Return 
}

# --- 4. STREAMING ACQUISITION ---
Write-Host "    [*] Streaming Memory to Disk (2/4)..." -ForegroundColor Yellow
Write-Host "        (This compresses RAM on-the-fly. Please wait...)" -ForegroundColor DarkGray

$CompressedDump = "/tmp/memdump_$TargetIP.lime.gz"

# COMMAND EXPLANATION:
# 1. sudo $RemoteAvml /dev/stdout  -> Dumps RAM directly to the output stream (no file)
# 2. | gzip -1                     -> Catches that stream and compresses it instantly
# 3. > $CompressedDump             -> Writes only the final small file to disk
# 4. chown                         -> Fixes permissions for download
$RemoteCmd = "chmod +x $RemoteAvml && sudo $RemoteAvml /dev/stdout | gzip -1 > $CompressedDump && sudo chown `$(id -u):`$(id -g) $CompressedDump"

$SshArgs = $SshOpts + @("-t", "${Username}@${TargetIP}", $RemoteCmd)

if ((Invoke-InteractiveCommand "ssh" $SshArgs) -ne 0) {
    Write-Warning "Acquisition Failed."
    Return
}

# --- 5. DOWNLOAD ---
Write-Host "    [*] Downloading Image (3/4)..." -ForegroundColor Cyan
$LocalDump = Join-Path $CaseDir "MemDump_$TargetIP.lime.gz"
$DownloadArgs = $SshOpts + @("${Username}@${TargetIP}:$CompressedDump", "$LocalDump")

if ((Invoke-InteractiveCommand "scp" $DownloadArgs) -eq 0) {
    if (Test-Path $LocalDump) {
        $Size = (Get-Item $LocalDump).Length / 1MB
        Write-Host "        [V] Saved: $LocalDump ($([math]::Round($Size, 2)) MB)" -ForegroundColor Green

        # --- 6. CLEANUP ---
        Write-Host "    [*] Cleaning up (4/4)..." -ForegroundColor Gray
        $CleanupCmd = "sudo rm -f $RemoteAvml $CompressedDump"
        $CleanupArgs = $SshOpts + @("-t", "${Username}@${TargetIP}", $CleanupCmd)
        
        Invoke-InteractiveCommand "ssh" $CleanupArgs | Out-Null

        Write-Host "
   [+] ACQUISITION COMPLETE
   ------------------------
   Path: $CaseDir
        " -ForegroundColor Cyan
        Invoke-Item $CaseDir
    }
} else {
    Write-Warning "Download Failed."
}

Pause