<#
.SYNOPSIS
    Invoke-WinLiveResponse.ps1 - The Lion (Comprehensive Forensic Edition) 🦁
.DESCRIPTION
    A deep-dive forensic collection engine.
    - RECOVERS persistent PowerShell history from all user profiles.
    - FILTERS Event Logs to show human/network logons only (removes System noise).
    - ANALYZES Persistence, Network, Processes, and Registry in depth.
    - Generates a searchable HTML Forensic Dashboard.
.AUTHOR
    RootGuard (https://github.com/andranglin)
#>

# --- 1. CONFIGURATION ---
$ErrorActionPreference = "SilentlyContinue"
$Hostname   = $env:COMPUTERNAME
$Timestamp  = Get-Date -Format "yyyyMMdd_HHmm"
$BaseDir    = "C:\Evidence\DeepDive"
$CaseDir    = Join-Path $BaseDir "${Hostname}_${Timestamp}"
$ReportFile = Join-Path $CaseDir "Forensic_Report.html"

New-Item -Path $CaseDir -ItemType Directory -Force | Out-Null

Write-Host "
   CHIMERA FORENSIC ENGINE (The Lion) 🦁
   =====================================
   Target: $Hostname
   Output: $CaseDir
" -ForegroundColor Yellow

function Log-Activity ($Message) { Write-Host "    [+] $Message" -ForegroundColor Green }

# --- 2. COLLECTION ENGINE ---

# PHASE 1: SYSTEM & METADATA
Log-Activity "Phase 1/7: System Information & Patching..."
Get-ComputerInfo | Select-Object OsName, OsVersion, OsBuildNumber, OsArchitecture, BiosManufacturer, BiosSerialNumber, CsName, TimeZone | Export-Csv (Join-Path $CaseDir "01_System_Info.csv") -NoTypeInformation
Get-CimInstance -ClassName Win32_QuickFixEngineering | Select-Object Description, HotFixID, InstalledOn | Sort-Object InstalledOn -Descending | Export-Csv (Join-Path $CaseDir "01_Patches.csv") -NoTypeInformation
Get-WmiObject -Class Win32_OperatingSystem | Select-Object LastBootUpTime, LocalDateTime, NumberOfUsers, FreePhysicalMemory | Export-Csv (Join-Path $CaseDir "01_OS_Metrics.csv") -NoTypeInformation
Get-ChildItem env:\ | Select-Object Key, Value | Export-Csv (Join-Path $CaseDir "01_Env_Vars.csv") -NoTypeInformation


# PHASE 2: PROCESSES & MALWARE HUNTING
Log-Activity "Phase 2/7: Process Analysis (Tree & CommandLine)..."
# Full Process List with CommandLine (Critical for finding 'powershell -enc ...')
Get-CimInstance -Class Win32_Process | Select-Object ProcessId, Name, ParentProcessId, CommandLine, ExecutionState, Handle | Sort-Object ProcessId | Export-Csv (Join-Path $CaseDir "02_Processes_Detailed.csv") -NoTypeInformation

# Suspicious Processes (Regex Match)
Get-CimInstance -Class Win32_Process | Where-Object { $_.Name -match "powershell|cmd|psexec|bitsadmin|certutil|wscript|cscript|mshta|rundll32|regsvr32" } | Select-Object ProcessId, Name, CommandLine, ParentProcessId | Export-Csv (Join-Path $CaseDir "02_Suspicious_Processes.csv") -NoTypeInformation

# Services (Anomalies: Auto-Start but Stopped)
Get-WmiObject -Class Win32_Service | Where-Object { $_.StartMode -eq 'Auto' -and $_.State -ne 'Running' } | Select-Object Name, DisplayName, State, StartMode, PathName | Export-Csv (Join-Path $CaseDir "02_Service_Anomalies.csv") -NoTypeInformation


# PHASE 3: USER ACTIVITY & HISTORY (Deep Dive)
Log-Activity "Phase 3/7: Recovering PowerShell History (All Users)..."

# 3A. Persistent History Recovery (Scanning User Profiles)
$UsersDir = "C:\Users"
$HistoryResults = @()

if (Test-Path $UsersDir) {
    $UserFolders = Get-ChildItem -Path $UsersDir -Directory
    foreach ($User in $UserFolders) {
        $HistPath = "$($User.FullName)\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
        if (Test-Path $HistPath) {
            # Read the file and add the username to the object
            Get-Content $HistPath | ForEach-Object {
                $HistoryResults += [PSCustomObject]@{
                    User    = $User.Name
                    Command = $_
                    Source  = "ConsoleHost_history.txt"
                }
            }
        }
    }
}
if ($HistoryResults) {
    $HistoryResults | Export-Csv (Join-Path $CaseDir "03_Recovered_PS_History.csv") -NoTypeInformation
} else {
    Log-Activity "No persistent history files found."
}

# 3B. Active User Sessions
quser 2>$null | ForEach-Object { 
    $L = $_.Trim() -replace '\s+',','; if($L -notmatch 'USERNAME'){$L} 
} | Out-File (Join-Path $CaseDir "03_Active_Sessions_Raw.txt")


# PHASE 4: NETWORK TELEMETRY
Log-Activity "Phase 4/7: Network Connections & DNS..."
Get-NetTCPConnection | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess, CreationTime | Export-Csv (Join-Path $CaseDir "04_Network_All.csv") -NoTypeInformation
# Established only (C2 Hunting)
Get-NetTCPConnection -State Established | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, OwningProcess, CreationTime | Export-Csv (Join-Path $CaseDir "04_Network_Established.csv") -NoTypeInformation
# DNS Cache
Get-DnsClientCache | Select-Object Entry, RecordName, RecordType, Status | Export-Csv (Join-Path $CaseDir "04_DNS_Cache.csv") -NoTypeInformation
# SMB Shares
Get-SmbShare | Select-Object Name, Path, Description | Export-Csv (Join-Path $CaseDir "04_SMB_Shares.csv") -NoTypeInformation


# PHASE 5: PERSISTENCE
Log-Activity "Phase 5/7: Persistence (Registry, WMI, Tasks)..."
# Scheduled Tasks
Get-ScheduledTask | Select-Object TaskName, TaskPath, State, Description | Export-Csv (Join-Path $CaseDir "05_ScheduledTasks.csv") -NoTypeInformation

# WMI Event Subscriptions (Advanced Malware)
Get-WmiObject -Namespace "root\subscription" -Class __EventFilter | Select-Object Name, Query | Export-Csv (Join-Path $CaseDir "05_WMI_Filters.csv") -NoTypeInformation
Get-WmiObject -Namespace "root\subscription" -Class __EventConsumer | Select-Object Name, CommandLineTemplate, ExecutablePath | Export-Csv (Join-Path $CaseDir "05_WMI_Consumers.csv") -NoTypeInformation

# Registry Autoruns
$RunKeys = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run")
foreach ($Key in $RunKeys) { 
    Get-ItemProperty -Path $Key | Select-Object * -Exclude PSPath, PSParentPath, PSChildName, PSProvider, PSDrive | Export-Csv (Join-Path $CaseDir "05_Registry_Autoruns.csv") -Append -NoTypeInformation 
}


# PHASE 6: LOGON ANALYSIS (Filtered)
Log-Activity "Phase 6/7: Analyzing Logons (Removing Noise)..."

# Filter OUT System accounts to see real activity
# We look for Event 4624 (Logon)
# We filter where TargetUserName is NOT System, Network Service, DWM, or the MachineAccount itself ($)
$Machine = $env:COMPUTERNAME + "$"
$Logons = Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4624} -MaxEvents 2000 | Where-Object { 
    $_.Properties[5].Value -notmatch "SYSTEM|NETWORK SERVICE|LOCAL SERVICE|DWM-|$Machine|UMFD-" 
} | Select-Object TimeCreated, 
    Id, 
    @{N='TargetUser';E={$_.Properties[5].Value}}, 
    @{N='LogonType';E={$_.Properties[8].Value}}, 
    @{N='SourceIP';E={$_.Properties[18].Value}}, 
    @{N='Workstation';E={$_.Properties[11].Value}}

if ($Logons) {
    $Logons | Export-Csv (Join-Path $CaseDir "06_Human_Logons.csv") -NoTypeInformation
} else {
    Log-Activity "No human logons found in recent logs."
}

# RDP Logons Specific (Type 10)
$RDP = $Logons | Where-Object { $_.LogonType -eq 10 }
if ($RDP) { $RDP | Export-Csv (Join-Path $CaseDir "06_RDP_Logons.csv") -NoTypeInformation }


# PHASE 7: FILE SYSTEM & BROWSER
Log-Activity "Phase 7/7: File & Browser Artifacts..."
# Typed URLs (IE/Explorer)
Get-ItemProperty -Path "HKCU:\Software\Microsoft\Internet Explorer\TypedURLs" -ErrorAction SilentlyContinue | Select-Object * -Exclude PSPath, PSParentPath | Export-Csv (Join-Path $CaseDir "07_IE_TypedURLs.csv") -NoTypeInformation
# Disk Info
Get-PSDrive | Where-Object {$_.Provider -match "FileSystem"} | Select-Object Name, Used, Free, Root | Export-Csv (Join-Path $CaseDir "07_Disk_Usage.csv") -NoTypeInformation


# --- 3. HTML DASHBOARD GENERATOR ---
Log-Activity "Generating Forensic Report..."

$CSS = @"
<style>
    :root { --primary: #2c3e50; --accent: #e67e22; --bg: #ecf0f1; --text: #2c3e50; }
    body { font-family: 'Segoe UI', sans-serif; margin: 0; background: var(--bg); color: var(--text); padding-bottom: 50px; }
    
    /* Header */
    header { background: #2c3e50; color: white; padding: 20px; text-align: center; border-bottom: 5px solid var(--accent); }
    h1 { margin: 0; letter-spacing: 1px; }
    .meta { font-size: 0.9em; opacity: 0.8; margin-top: 5px; }
    
    /* Navigation */
    .nav-bar { background: #34495e; padding: 10px; text-align: center; position: sticky; top: 0; z-index: 100; box-shadow: 0 2px 5px rgba(0,0,0,0.2); }
    .nav-bar a { color: white; text-decoration: none; padding: 8px 15px; font-size: 0.9em; margin: 0 5px; border-radius: 4px; transition: 0.3s; }
    .nav-bar a:hover { background: var(--accent); }
    
    /* Container */
    .container { max-width: 1200px; margin: 20px auto; padding: 0 20px; }
    
    /* Cards */
    .card { background: white; border-radius: 6px; box-shadow: 0 2px 10px rgba(0,0,0,0.05); margin-bottom: 30px; overflow: hidden; border-top: 3px solid var(--primary); }
    .card-header { background: #f8f9fa; padding: 12px 20px; border-bottom: 1px solid #eee; display: flex; justify-content: space-between; align-items: center; }
    .card-title { font-weight: bold; font-size: 1.1em; color: var(--primary); }
    .btn-dl { background: #27ae60; color: white; text-decoration: none; font-size: 0.8em; padding: 5px 10px; border-radius: 3px; }
    
    /* Tables */
    .table-wrapper { overflow-x: auto; max-height: 450px; }
    table { width: 100%; border-collapse: collapse; font-size: 0.85em; }
    th { background: #34495e; color: white; text-align: left; padding: 12px; position: sticky; top: 0; }
    td { padding: 10px 12px; border-bottom: 1px solid #eee; white-space: nowrap; }
    tr:nth-child(even) { background: #f8f9fa; }
    tr:hover { background: #eaf2f8; }
</style>
"@

$Header = @"
<!DOCTYPE html>
<html><head><title>Forensic Report | $Hostname</title>$CSS</head><body>
<header>
    <h1>🦁 Chimera Forensic Report</h1>
    <div class='meta'>Target: $Hostname | Date: $Timestamp | Case ID: $(Split-Path $CaseDir -Leaf)</div>
</header>
<div class='nav-bar'>
    <a href='#System'>System</a>
    <a href='#Processes'>Processes</a>
    <a href='#Network'>Network</a>
    <a href='#Users'>Users & Logons</a>
    <a href='#Persistence'>Persistence</a>
</div>
<div class='container'>
"@

$Content = ""
$CSVs = Get-ChildItem -Path $CaseDir -Filter "*.csv" | Sort-Object Name

foreach ($File in $CSVs) {
    $Name = $File.BaseName -replace "^\d+_", "" -replace "_", " "
    
    # Import Data (Preview 50 rows)
    $Data = Import-Csv $File.FullName | Select-Object -First 50
    
    if ($Data) {
        $Props = $Data[0].PSObject.Properties.Name
        $Th = $Props | ForEach-Object { "<th>$_</th>" }
        $Tr = $Data | ForEach-Object {
            $Row = "<tr>"
            foreach ($P in $Props) { $Row += "<td>$($_.$P)</td>" }
            $Row += "</tr>"
            $Row
        }
        
        # Assign ID based on name for navigation
        $ID = "Other"
        if ($Name -match "System|OS|Patch") { $ID = "System" }
        if ($Name -match "Process|Service") { $ID = "Processes" }
        if ($Name -match "Network|DNS|SMB") { $ID = "Network" }
        if ($Name -match "User|Logon|History") { $ID = "Users" }
        if ($Name -match "Task|Autorun|WMI") { $ID = "Persistence" }
        
        $Content += @"
        <div id='$ID' class='card'>
            <div class='card-header'>
                <span class='card-title'>$Name</span>
                <a href='$($File.Name)' class='btn-dl'>Download CSV</a>
            </div>
            <div class='table-wrapper'>
                <table><thead><tr>$Th</tr></thead><tbody>$Tr</tbody></table>
            </div>
        </div>
"@
    }
}

$Footer = "</div><footer style='text-align:center; padding:20px; color:#aaa; font-size:0.8em;'>Generated by Chimera Triage Toolkit</footer></body></html>"

Set-Content -Path $ReportFile -Value ($Header + $Content + $Footer)

# --- 4. LAUNCH ---
Write-Host "   [+] Forensic Collection Complete" -ForegroundColor Cyan
Write-Host "   [+] Report: $ReportFile" -ForegroundColor Cyan
Invoke-Item $ReportFile