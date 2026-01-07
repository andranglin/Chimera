<#
.SYNOPSIS
    Invoke-WinArtifacts.ps1 - The Eagle (Comprehensive Artifacts) 🦅
.DESCRIPTION
    Orchestrates EZTools and Native Calls to collect:
    - Application Execution (Shimcache, Amcache, SRUM, UserAssist, Timeline)
    - File Access (Recent Files, Run Dialog, Typed Paths, Recycle Bin, Office MRUs)
    - System Info (OS, Boot, Shutdown Times, Autostarts)
    - Devices (USB History, VSN, Drive Letters)
    - Network (WLAN Logs, SRUM, Timezone, URL Params)
    Generates a professional HTML Dashboard.
.AUTHOR
    RootGuard (https://github.com/andranglin)
#>

# --- 1. CONFIGURATION ---
$ErrorActionPreference = "SilentlyContinue"
$Hostname    = $env:COMPUTERNAME
$Timestamp   = Get-Date -Format "yyyyMMdd_HHmm"
$BaseDir     = "C:\Evidence\Artifacts"
$CaseDir     = Join-Path $BaseDir "${Hostname}_${Timestamp}"
$ReportFile  = Join-Path $CaseDir "Artifact_Dashboard.html"
$ToolsDir    = "$PSScriptRoot\..\..\Tools\Windows\EZTools"
$ConfigPath  = "$PSScriptRoot\..\..\Config\Chimera_Triage.reb"
$VssMount    = "C:\Chimera_VSS"

New-Item -Path $CaseDir -ItemType Directory -Force | Out-Null

Write-Host "
   CHIMERA ARTIFACT ENGINE 🦅
   ==========================
   Target: $Hostname
   Output: $CaseDir
" -ForegroundColor Yellow

function Log-Activity ($Message) { Write-Host "    [+] $Message" -ForegroundColor Green }

# --- 2. VSS CREATION ---
Log-Activity "Creating Volume Shadow Copy..."
try {
    $Vss = (Get-WmiObject -List Win32_ShadowCopy).Create("C:\", "ClientAccessible")
    $ShadowID = $Vss.ShadowID
    $ShadowVol = (Get-WmiObject Win32_ShadowCopy | Where-Object { $_.ID -eq $ShadowID }).DeviceObject
    if (Test-Path $VssMount) { cmd /c rmdir $VssMount }
    cmd /c mklink /d $VssMount "$ShadowVol\" | Out-Null
} catch {
    Write-Warning "VSS Creation Failed. Attempting live collection."
}
if (-not (Test-Path $VssMount)) { $SourceRoot = "C:" } else { $SourceRoot = $VssMount; Log-Activity "VSS Mounted at $VssMount" }


# --- 3. RECMD BATCH SETUP ---
$LocalReb = Join-Path $CaseDir "Chimera_Triage.reb"
if (Test-Path $ConfigPath) {
    Copy-Item $ConfigPath $LocalReb
} else {
    Write-Warning "Config\Chimera_Triage.reb not found. Creating default..."
    Set-Content -Path $LocalReb -Value "Description: Default`nId: 1000`nKeys:`n  - HiveType: NTUSER`n    KeyPath: Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU`n    Recursive: true`n    Comment: RunMRU"
}


# --- 4. ARTIFACT EXECUTION ENGINE ---

# === A. SYSTEM INFORMATION & AUTOSTART ===
Log-Activity "Collecting System Info, Boot & Shutdown Times..."

# 1. OS & Boot Time
Get-ComputerInfo | Select-Object OsName, WindowsVersion, OsBuildNumber, CsName, TimeZone, OsLastBootUpTime, OsUptime | Export-Csv (Join-Path $CaseDir "01_System_Info.csv") -NoTypeInformation

# 2. Last Shutdown Time (Event 1074/6006)
Get-WinEvent -FilterHashtable @{LogName='System'; ID=1074,6006} -MaxEvents 20 -ErrorAction SilentlyContinue | Select-Object TimeCreated, Id, Message | Export-Csv (Join-Path $CaseDir "01_Last_Shutdown_Events.csv") -NoTypeInformation

# 3. Autostart Programs (WMI + Registry)
Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location, User | Export-Csv (Join-Path $CaseDir "01_Autostart_Programs.csv") -NoTypeInformation


# === B. REGISTRY ARTIFACTS (RECmd) ===
# Covers: Run Dialog, User Typed Paths, Last Visited MRU, UserAssist, USBSTOR, Office MRU
if (Test-Path "$ToolsDir\RECmd.exe") {
    Log-Activity "Parsing Registry (RunMRU, TypedPaths, USB, Office)..."
    Start-Process -FilePath "$ToolsDir\RECmd.exe" -ArgumentList "-d `"$SourceRoot`" --bn $LocalReb --csv `"$CaseDir`" --csvf 02_Registry_Artifacts.csv" -Wait -WindowStyle Hidden
}

# === C. FILE ACCESS & EXECUTION ===

# 1. Prefetch
if (Test-Path "$ToolsDir\PECmd.exe") {
    Log-Activity "Parsing Prefetch..."
    Start-Process -FilePath "$ToolsDir\PECmd.exe" -ArgumentList "-d `"$SourceRoot\Windows\Prefetch`" --csv `"$CaseDir`" --csvf 03_Prefetch.csv -q" -Wait -WindowStyle Hidden
}

# 2. Windows 10 Timeline
if (Test-Path "$ToolsDir\WxTCmd.exe") {
    Log-Activity "Parsing Windows Timeline..."
    Start-Process -FilePath "$ToolsDir\WxTCmd.exe" -ArgumentList "-d `"$SourceRoot\Users`" --csv `"$CaseDir`" --csvf 03_Timeline.csv -q" -Wait -WindowStyle Hidden
}

# 3. Recycle Bin
if (Test-Path "$ToolsDir\RBCmd.exe") {
    Log-Activity "Parsing Recycle Bin..."
    Start-Process -FilePath "$ToolsDir\RBCmd.exe" -ArgumentList "-d `"$SourceRoot`" --csv `"$CaseDir`" --csvf 03_RecycleBin.csv -q" -Wait -WindowStyle Hidden
}

# 4. Jump Lists
if (Test-Path "$ToolsDir\JLECmd.exe") {
    Log-Activity "Parsing Jump Lists (Recent Files)..."
    Start-Process -FilePath "$ToolsDir\JLECmd.exe" -ArgumentList "-d `"$SourceRoot\Users`" --csv `"$CaseDir`" --csvf 03_JumpLists.csv -q" -Wait -WindowStyle Hidden
}

# 5. Shortcuts (LNK)
if (Test-Path "$ToolsDir\LECmd.exe") {
    Log-Activity "Parsing LNK Shortcuts..."
    Start-Process -FilePath "$ToolsDir\LECmd.exe" -ArgumentList "-d `"$SourceRoot\Users`" --csv `"$CaseDir`" --csvf 03_Shortcuts.csv -q" -Wait -WindowStyle Hidden
}

# 6. ShellBags
if (Test-Path "$ToolsDir\SBECmd.exe") {
    Log-Activity "Parsing ShellBags..."
    Start-Process -FilePath "$ToolsDir\SBECmd.exe" -ArgumentList "-d `"$SourceRoot`" --csv `"$CaseDir`" --csvf 03_Shellbags.csv" -Wait -WindowStyle Hidden
}


# === D. EXECUTION EVIDENCE ===

# 1. Shimcache
if (Test-Path "$ToolsDir\AppCompatCacheParser.exe") {
    Log-Activity "Parsing Shimcache..."
    Start-Process -FilePath "$ToolsDir\AppCompatCacheParser.exe" -ArgumentList "--csv `"$CaseDir`" --csvf 04_Shimcache.csv -t -q" -Wait -WindowStyle Hidden
}

# 2. Amcache
if (Test-Path "$ToolsDir\AmcacheParser.exe") {
    Log-Activity "Parsing Amcache..."
    Start-Process -FilePath "$ToolsDir\AmcacheParser.exe" -ArgumentList "-f `"$SourceRoot\Windows\appcompat\Programs\Amcache.hve`" --csv `"$CaseDir`" --csvf 04_Amcache.csv -i on -q" -Wait -WindowStyle Hidden
}


# === E. NETWORK & ACTIVITY ===

# 1. SRUM (Network History & Resource Usage)
if (Test-Path "$ToolsDir\SrumECmd.exe") {
    Log-Activity "Parsing SRUM (Network Usage)..."
    Start-Process -FilePath "$ToolsDir\SrumECmd.exe" -ArgumentList "-f `"$SourceRoot\Windows\System32\sru\SRUDB.dat`" --csv `"$CaseDir`" -q" -Wait -WindowStyle Hidden
}

# 2. Native Network Info
Log-Activity "Collecting Network Interfaces & Timezone..."
Get-NetAdapter | Select-Object Name, InterfaceDescription, MacAddress, LinkSpeed, Status | Export-Csv (Join-Path $CaseDir "05_Network_Interfaces.csv") -NoTypeInformation

# 3. WLAN Event Log (WiFi History)
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-WLAN-AutoConfig/Operational'; ID=8000,8001,8002,11000,11001} -MaxEvents 500 -ErrorAction SilentlyContinue | Select-Object TimeCreated, Id, Message | Export-Csv (Join-Path $CaseDir "05_WLAN_History.csv") -NoTypeInformation


# === F. USB & DEVICE LOGS ===
Log-Activity "Parsing USB/PnP Events (Log 20001)..."
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-DriverFrameworks-UserMode/Operational'; ID=20001,20003} -MaxEvents 500 -ErrorAction SilentlyContinue | Select-Object TimeCreated, Id, Message | Export-Csv (Join-Path $CaseDir "06_USB_PnP_Events.csv") -NoTypeInformation


# --- 5. CLEANUP ---
if (Test-Path $VssMount) { cmd /c rmdir $VssMount }


# --- 6. HTML DASHBOARD GENERATOR ---
Log-Activity "Generating Interactive Dashboard..."

$CSS = @"
<style>
    :root {
        --primary: #2c3e50; --secondary: #34495e; --accent: #e67e22;
        --header-bg: #2c3e50; --bg: #f4f7f6; --text: #333; --sidebar-width: 260px;
    }
    body { font-family: 'Segoe UI', Inter, sans-serif; margin: 0; background-color: var(--bg); color: var(--text); display: flex; height: 100vh; overflow: hidden; }
    
    nav { width: var(--sidebar-width); background: var(--primary); color: white; display: flex; flex-direction: column; height: 100vh; flex-shrink: 0; box-shadow: 2px 0 5px rgba(0,0,0,0.1); }
    .brand { padding: 25px; font-size: 1.4em; font-weight: bold; border-bottom: 1px solid rgba(255,255,255,0.1); background: linear-gradient(135deg, #2c3e50 0%, #d35400 100%); text-align: center; }
    .nav-links { flex: 1; overflow-y: auto; list-style: none; padding: 0; margin: 0; }
    .nav-links li a { display: block; padding: 14px 20px; color: #bdc3c7; text-decoration: none; border-left: 5px solid transparent; transition: 0.2s; font-size: 0.9em; }
    .nav-links li a:hover, .nav-links li a.active { background: rgba(0,0,0,0.2); color: white; border-left-color: var(--accent); }
    
    main { flex: 1; overflow-y: auto; padding: 40px; position: relative; scroll-behavior: smooth; }
    .dashboard-header { margin-bottom: 40px; display: flex; justify-content: space-between; align-items: end; border-bottom: 2px solid #ddd; padding-bottom: 15px; }
    .header-info h1 { margin: 0 0 10px 0; color: var(--primary); font-size: 2.2em; border-left: 8px solid var(--accent); padding-left: 20px; }
    .meta-tags span { background: #e0e0e0; color: #555; padding: 5px 10px; border-radius: 4px; font-size: 0.85em; margin-right: 10px; font-weight: 600; }
    
    .card { background: white; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); margin-bottom: 35px; overflow: hidden; border: 1px solid #e1e4e8; }
    .card-header { background: var(--header-bg); padding: 15px 20px; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--secondary); }
    .card-title { margin: 0; color: white; font-size: 1.2em; font-weight: 500; }
    .download-link { font-size: 0.85em; color: #f39c12; text-decoration: none; font-weight: bold; border: 1px solid #f39c12; padding: 4px 10px; border-radius: 4px; transition: 0.3s; }
    .download-link:hover { background: #f39c12; color: white; }
    
    .table-container { overflow-x: auto; max-height: 500px; }
    table { width: 100%; border-collapse: collapse; font-size: 0.9em; }
    th { background: #ecf0f1; color: #2c3e50; font-weight: 700; text-align: left; padding: 15px; position: sticky; top: 0; box-shadow: 0 2px 2px rgba(0,0,0,0.05); border-bottom: 2px solid #bdc3c7; }
    td { padding: 12px 15px; border-bottom: 1px solid #eee; color: #444; white-space: nowrap; max-width: 350px; overflow: hidden; text-overflow: ellipsis; }
    tr:nth-child(even) { background-color: #fafafa; }
    .search-box { padding: 6px 12px; border: none; border-radius: 4px; font-size: 0.9em; width: 220px; margin-right: 10px; }
    footer { margin-top: 50px; text-align: center; color: #95a5a6; border-top: 1px solid #eee; padding-top: 20px; }
</style>
<script>
    function filterTable(inputId, tableId) {
        var input, filter, table, tr, td, i, j, txtValue;
        input = document.getElementById(inputId);
        filter = input.value.toUpperCase();
        table = document.getElementById(tableId);
        tr = table.getElementsByTagName("tr");
        for (i = 1; i < tr.length; i++) {
            tr[i].style.display = "none";
            td = tr[i].getElementsByTagName("td");
            for (j = 0; j < td.length; j++) {
                if (td[j]) {
                    txtValue = td[j].textContent || td[j].innerText;
                    if (txtValue.toUpperCase().indexOf(filter) > -1) {
                        tr[i].style.display = "";
                        break;
                    }
                }
            }
        }
    }
</script>
"@

$Header = @"
<!DOCTYPE html>
<html lang='en'>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>Artifact Report | $Hostname</title>
    $CSS
</head>
<body>
    <nav>
        <div class='brand'>🦅 ARTIFACTS</div>
        <ul class='nav-links' id='nav-list'>
"@

$MainContent = @"
        </ul>
    </nav>
    <main>
        <div class='dashboard-header'>
            <div class='header-info'>
                <h1>Forensic Artifact Report</h1>
                <div class='meta-tags'>
                    <span>Target: $Hostname</span>
                    <span>Date: $Timestamp</span>
                    <span>VSS Used: $(if($SourceRoot -eq "C:"){'No'}else{'Yes'})</span>
                </div>
            </div>
            <div style='text-align:right; color:#7f8c8d;'>
                <strong>RootGuard DFIR Engine</strong><br>
                <small>Deep Analysis Module</small>
            </div>
        </div>
"@

$NavItems = ""
$ContentItems = ""
$Counter = 0
$CSVs = Get-ChildItem -Path $CaseDir -Filter "*.csv" | Sort-Object Name

foreach ($File in $CSVs) {
    $Counter++
    $ID = "tbl_" + $Counter
    $SearchID = "src_" + $Counter
    $RawName = $File.Name
    $NiceName = $RawName -replace "^\d+_", "" -replace "_", " " -replace ".csv", ""
    
    $NavItems += "<li><a href='#$ID'>$NiceName</a></li>`n"
    
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
        $ContentItems += @"
        <div id='$ID' class='card'>
            <div class='card-header'>
                <h3 class='card-title'>$NiceName</h3>
                <div>
                    <input type='text' id='$SearchID' onkeyup='filterTable("$SearchID", "$ID")' placeholder='Search...' class='search-box'>
                    <a href='$RawName' class='download-link'>CSV ⬇</a>
                </div>
            </div>
            <div class='table-container'>
                <table id='$ID'>
                    <thead><tr>$Th</tr></thead>
                    <tbody>$Tr</tbody>
                </table>
            </div>
        </div>
"@
    }
}

$Footer = "<footer><p>Generated by <strong>Chimera Triage Toolkit</strong> | RootGuard</p></footer></main></body></html>"
Set-Content -Path $ReportFile -Value ($Header + $NavItems + $MainContent + $ContentItems + $Footer)

# --- 7. FINISH ---
Write-Host "
   [+] DASHBOARD GENERATED
   -----------------------
   Path: $ReportFile
" -ForegroundColor Cyan

Invoke-Item $ReportFile