<#
.SYNOPSIS
    Invoke-LinuxLiveResponse.ps1 - The Goat (Hybrid CSV/TXT Edition) 🐐
.DESCRIPTION
    A Forensic Collection engine that balances Reliability with Usability.
    1. Uses .TXT for raw tool output (ps, netstat, ip) to prevent parsing errors.
    2. Uses .CSV for the File System Timeline (Sortable in Excel).
    3. Auto-accepts Host Keys & uses Numeric IDs for AD compatibility.
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
$BaseDir    = "C:\Evidence\LinuxTriage"
$CaseDir    = Join-Path $BaseDir "Triage_$Timestamp"
$LocalScript = "$env:TEMP\chimera_payload.sh"

$SshOpts = @("-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-o", "LogLevel=ERROR")

# --- 2. HEADER ---
Write-Host "
   CHIMERA LINUX TRIAGE (Hybrid CSV Engine) 🐐
   ============================================
" -ForegroundColor Green

if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) { Write-Error "CRITICAL: 'ssh' not found."; Return }
if ([string]::IsNullOrWhiteSpace($TargetIP)) { $TargetIP = Read-Host "    Target IP Address" }
if ([string]::IsNullOrWhiteSpace($Username)) { $Username = Read-Host "    SSH Username" }
if (-not $TargetIP -or -not $Username) { Write-Warning "Missing inputs."; Return }

New-Item -Path $CaseDir -ItemType Directory -Force | Out-Null
Write-Host "    Target: $Username@$TargetIP"
Write-Host "    Output: $CaseDir"

# --- 3. GENERATE PAYLOAD ---
Write-Host "`n    [*] Generating Payload..." -ForegroundColor Cyan

$BashContent = @'
#!/bin/bash
# Chimera Hybrid Engine

export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export TS=$(date +%Y%m%d_%H%M)
export WORK_DIR="/tmp/chimera_$TS"
export OUT_FILE="/tmp/chimera_evidence.tar.gz"

echo "    [L] Forensic Triage Started in $WORK_DIR"
mkdir -p $WORK_DIR/Console_Logs
exec 2> $WORK_DIR/Console_Logs/execution_errors.log

# --- A. SYSTEM & CORE (.txt) ---
echo "    [L] System Info..."
mkdir $WORK_DIR/System
uname -a > $WORK_DIR/System/uname.txt
uptime > $WORK_DIR/System/uptime.txt
cat /etc/*release > $WORK_DIR/System/os_release.txt 2>/dev/null
lsmod > $WORK_DIR/System/loaded_modules.txt
df -h > $WORK_DIR/System/df.txt
mount > $WORK_DIR/System/mount.txt

# --- B. PROCESSES (.txt) ---
echo "    [L] Process Forensics..."
mkdir $WORK_DIR/Processes
if ps axwwSo user,pid,ppid,vsz,rss,tname,stat,stime,time,args >/dev/null 2>&1; then
    ps axwwSo user,pid,ppid,vsz,rss,tname,stat,stime,time,args > $WORK_DIR/Processes/ps_list.txt
else
    ps auxww > $WORK_DIR/Processes/ps_list.txt
fi
# Hash Running Binaries
find -L /proc/[0-9]*/exe -print0 2>/dev/null | xargs -0 sha1sum 2>/dev/null > $WORK_DIR/Processes/running_binary_hashes.txt
# Deleted Binaries
ls -l /proc/*/exe 2>/dev/null | grep "deleted" > $WORK_DIR/Processes/deleted_binaries.txt

# --- C. NETWORK (.txt) ---
echo "    [L] Network Artifacts..."
mkdir $WORK_DIR/Network
if command -v ss >/dev/null 2>&1; then ss -anepo > $WORK_DIR/Network/ss_connections.txt; else netstat -antup > $WORK_DIR/Network/netstat_connections.txt; fi
if command -v ip >/dev/null 2>&1; then ip addr > $WORK_DIR/Network/ip_addr.txt; else ifconfig -a > $WORK_DIR/Network/ifconfig.txt; fi
if command -v ip >/dev/null 2>&1; then ip neigh > $WORK_DIR/Network/arp_table.txt; else arp -a > $WORK_DIR/Network/arp_table.txt; fi
cat /etc/hosts > $WORK_DIR/Network/etc_hosts.txt

# --- D. FILE TIMELINE (.CSV) ---
# This is where CSV shines. We use 'stat' to format the output perfectly for Excel.
echo "    [L] Generating File Timeline (CSV)..."
mkdir $WORK_DIR/Timeline

# Columns: Inode, HardLinks, Permissions, Owner, Group, Size, ModifiedTime, AccessTime, FilePath
HEADER="Inode,Links,Perms,Owner,Group,Size,ModTime,AccessTime,Path"
echo $HEADER > $WORK_DIR/Timeline/filesystem_timeline.csv

# We scan /etc, /tmp, /dev/shm, /home, /var/www, and /root to save time (Full / scan can take hours)
# If you want full system, change the paths below to just "/"
TARGET_PATHS="/etc /tmp /dev/shm /home /root /var/www /srv"

if command -v stat >/dev/null 2>&1; then
    find $TARGET_PATHS -xdev -print0 2>/dev/null | xargs -0 stat --printf="%i,%h,%A,%U,%G,%s,%y,%x,%n\n" >> $WORK_DIR/Timeline/filesystem_timeline.csv 2>/dev/null
else
    # Fallback to text if 'stat' is missing (rare)
    find $TARGET_PATHS -xdev -ls > $WORK_DIR/Timeline/filesystem_fallback.txt
fi

# --- E. WEB SERVER FORENSICS (.txt) ---
echo "    [L] Web Server Forensics..."
mkdir $WORK_DIR/Web
WEB_ROOTS=("/var/www" "/usr/share/nginx/html" "/var/www/html" "/srv/www")

# Config Detection
if command -v apache2ctl >/dev/null 2>&1; then
    APACHE_CONF=$(apache2ctl -V 2>/dev/null | grep SERVER_CONFIG_FILE | cut -d= -f2 | tr -d '"')
    [ -f "$APACHE_CONF" ] && cp --parents "$APACHE_CONF" $WORK_DIR/Web/
elif command -v httpd >/dev/null 2>&1; then
    HTTPD_CONF=$(httpd -V 2>/dev/null | grep SERVER_CONFIG_FILE | cut -d= -f2 | tr -d '"')
    [ -f "$HTTPD_CONF" ] && cp --parents "$HTTPD_CONF" $WORK_DIR/Web/
fi
if command -v nginx >/dev/null 2>&1; then
    NGINX_CONF=$(nginx -V 2>&1 | grep "configure arguments" | sed -e "s/^.*--conf-path=\(.*\)conf.*$/\1/" | xargs)'conf'
    [ -f "$NGINX_CONF" ] && cp --parents "$NGINX_CONF" $WORK_DIR/Web/
fi

# Web Shell Hunter
find ${WEB_ROOTS[@]} -type f \( -iname '*.php' -o -iname '*.jsp' -o -iname '*.asp' -o -iname '*.aspx' -o -iname '*.sh' \) 2>/dev/null -print0 | xargs -0 sha1sum > $WORK_DIR/Web/webshell_hashes.txt

# --- F. PERSISTENCE & USER DATA (.txt) ---
echo "    [L] Persistence & Users..."
mkdir $WORK_DIR/Persistence
ls -la /etc/cron* > $WORK_DIR/Persistence/cron_file_list.txt
systemctl list-unit-files --state=enabled > $WORK_DIR/Persistence/systemd_enabled.txt 2>/dev/null
cat /etc/passwd > $WORK_DIR/Persistence/passwd.txt

# Grab History for all users
awk -F: '($3>=1000 || $3==0){print $1":"$6}' /etc/passwd | while read user_info; do
    USER=$(echo $user_info | cut -d: -f1)
    HOME=$(echo $user_info | cut -d: -f2)
    mkdir -p "$WORK_DIR/Persistence/$USER"
    [ -f "$HOME/.bash_history" ] && cp "$HOME/.bash_history" "$WORK_DIR/Persistence/$USER/bash_history.txt"
    crontab -u $USER -l > "$WORK_DIR/Persistence/$USER/crontab.txt" 2>/dev/null
done

# --- G. LOGS ---
echo "    [L] Logs..."
mkdir $WORK_DIR/Logs
[ -f /var/log/secure ] && tail -n 5000 /var/log/secure > $WORK_DIR/Logs/secure_tail.txt
[ -f /var/log/auth.log ] && tail -n 5000 /var/log/auth.log > $WORK_DIR/Logs/auth_log_tail.txt
tail -n 5000 /var/log/syslog > $WORK_DIR/Logs/syslog_tail.txt 2>/dev/null

# --- PACKAGING ---
echo "    [L] Packaging Evidence..."
cd /tmp
tar -czf $OUT_FILE chimera_$TS

# AD/DOMAIN PERMISSION FIX
if [ -n "$SUDO_USER" ]; then
    USER_UID=$(id -u $SUDO_USER)
    USER_GID=$(id -g $SUDO_USER)
    chown $USER_UID:$USER_GID $OUT_FILE
else
    chmod 666 $OUT_FILE
fi

rm -rf $WORK_DIR
echo "EVIDENCE_READY"
'@

$BashContent = $BashContent -replace "`r`n", "`n"
[System.IO.File]::WriteAllText($LocalScript, $BashContent)

# --- HELPER FUNCTION ---
function Invoke-InteractiveCommand {
    param($Exe, $ArgsList)
    $Process = Start-Process -FilePath $Exe -ArgumentList $ArgsList -NoNewWindow -PassThru -Wait
    return $Process.ExitCode
}

# --- 4. UPLOAD ---
Write-Host "    [*] Uploading Hybrid Payload (1/4)..." -ForegroundColor Yellow
$ScpArgs = $SshOpts + @("$LocalScript", "${Username}@${TargetIP}:/tmp/chimera_payload.sh")
if ((Invoke-InteractiveCommand "scp" $ScpArgs) -ne 0) { Write-Warning "Upload Failed"; Return }

# --- 5. EXECUTE ---
Write-Host "    [*] Executing Forensic Engine (2/4)..." -ForegroundColor Yellow
$RemoteCmd = "chmod +x /tmp/chimera_payload.sh && sudo /tmp/chimera_payload.sh && rm /tmp/chimera_payload.sh"
$SshArgs = $SshOpts + @("-t", "${Username}@${TargetIP}", $RemoteCmd)
if ((Invoke-InteractiveCommand "ssh" $SshArgs) -ne 0) { Write-Warning "Execution Failed"; Return }

# --- 6. DOWNLOAD ---
Write-Host "    [*] Downloading Evidence (3/4)..." -ForegroundColor Cyan
$LocalEvidence = Join-Path $CaseDir "Evidence_${TargetIP}.tar.gz"
$DownloadArgs = $SshOpts + @("${Username}@${TargetIP}:/tmp/chimera_evidence.tar.gz", "$LocalEvidence")

if ((Invoke-InteractiveCommand "scp" $DownloadArgs) -eq 0) {
    if (Test-Path $LocalEvidence) {
        Write-Host "        [V] Evidence Saved" -ForegroundColor Green
        
        # --- 7. CLEANUP ---
        Write-Host "    [*] Removing Remote Evidence (4/4)..." -ForegroundColor Gray
        $CleanupArgs = $SshOpts + @("${Username}@${TargetIP}", "rm -f /tmp/chimera_evidence.tar.gz")
        Invoke-InteractiveCommand "ssh" $CleanupArgs | Out-Null

        Write-Host "
   [+] TRIAGE COMPLETE
   -------------------
   Evidence: $CaseDir
        " -ForegroundColor Cyan
        Invoke-Item $CaseDir
    }
} else {
    Write-Warning "Download Failed."
}

Pause