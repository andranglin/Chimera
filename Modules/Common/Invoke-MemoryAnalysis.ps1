<#
.SYNOPSIS
    Invoke-MemoryAnalysis.ps1 - The Owl (Comprehensive Memory Forensics) 🦉
.DESCRIPTION
    Automates Volatility 3 analysis for Windows and Linux memory dumps.
    Features a comprehensive plugin list for deep-dive forensics (Malware, Rootkits, Network).
    Generates a searchable, interactive HTML Dashboard.
.NOTE
    Location: Modules\Common\Invoke-MemoryAnalysis.ps1
    Requires Python 3 installed and in PATH.
    Requires 'vol.py' in Tools\Common\Volatility3\
.AUTHOR
    RootGuard (https://github.com/andranglin)
#>

param (
    [Parameter(Mandatory=$false)]
    [string]$MemoryFile,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Windows","Linux")]
    [string]$OS
)

# --- 1. CONFIGURATION ---
$VolScript  = "$PSScriptRoot\..\..\Tools\Common\Volatility3\vol.py"
$Hostname   = $env:COMPUTERNAME
$Timestamp  = Get-Date -Format "yyyyMMdd_HHmm"
$BaseDir    = "C:\Evidence\MemoryAnalysis"
$CaseDir    = Join-Path $BaseDir "Analysis_$Timestamp"

# --- 2. SETUP & CHECKS ---
Write-Host "
   CHIMERA MEMORY ANALYZER (The Owl) 🦉
   ====================================
" -ForegroundColor Yellow

if (-not (Test-Path $VolScript)) {
    Write-Error "CRITICAL: 'vol.py' not found."
    Write-Warning "Please place Volatility 3 source in: $PSScriptRoot\..\..\Tools\Common\Volatility3\"
    Pause; Return
}

# Check Python
try { $null = python --version 2>&1 } catch {
    Write-Error "CRITICAL: Python 3 not found in PATH."
    Pause; Return
}

# --- 3. INTERACTIVE SELECTION ---

# A. Select Memory File
if ([string]::IsNullOrWhiteSpace($MemoryFile)) {
    Add-Type -AssemblyName System.Windows.Forms
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.Title = "Select Memory Image"
    $OpenFileDialog.Filter = "Memory Files (*.raw;*.dmp;*.mem;*.lime;*.vmem)|*.raw;*.dmp;*.mem;*.lime;*.vmem|All Files (*.*)|*.*"
    
    if ($OpenFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $MemoryFile = $OpenFileDialog.FileName
    } else {
        Write-Warning "No file selected."; Return
    }
}

# B. Select OS Profile
if ([string]::IsNullOrWhiteSpace($OS)) {
    Write-Host "`n    [ SELECT TARGET OS ]" -ForegroundColor Cyan
    Write-Host "    1. Windows"
    Write-Host "       (PsList, NetScan, Malfind, Registry, DriverScan, etc.)"
    Write-Host "    2. Linux"
    Write-Host "       (Bash, LSOF, Netstat, Check_Syscall, ELF, etc.)"
    Write-Host ""
    $Sel = Read-Host "    Select Option (1 or 2)"
    
    if ($Sel -eq "1") { $OS = "Windows" } 
    elseif ($Sel -eq "2") { $OS = "Linux" } 
    else { Write-Warning "Invalid Selection. Defaulting to Windows."; $OS = "Windows" }
}

New-Item -Path $CaseDir -ItemType Directory -Force | Out-Null

Write-Host "`n    Target: $MemoryFile"
Write-Host "    Profile: $OS"
Write-Host "    Output: $CaseDir"
Write-Host "    [*] Starting Comprehensive Analysis...`n" -ForegroundColor Cyan


# --- 4. PLUGIN DEFINITIONS (COMPREHENSIVE) ---
$Plugins = @()

if ($OS -eq "Windows") {
    # --- PROCESSES ---
    $Plugins += @{ Name="Info";          Cmd="windows.info";             Desc="Image Info" }
    $Plugins += @{ Name="PsList";        Cmd="windows.pslist";           Desc="Process List" }
    $Plugins += @{ Name="PsScan";        Cmd="windows.psscan";           Desc="Hidden Processes (Pool Scan)" }
    $Plugins += @{ Name="PsTree";        Cmd="windows.pstree";           Desc="Process Tree" }
    $Plugins += @{ Name="CmdLine";       Cmd="windows.cmdline";          Desc="Command Line Args" }
    
    # --- NETWORK ---
    $Plugins += @{ Name="NetScan";       Cmd="windows.netscan";          Desc="Network Connections" }
    
    # --- MALWARE & INJECTION ---
    $Plugins += @{ Name="Malfind";       Cmd="windows.malfind";          Desc="Code Injection" }
    $Plugins += @{ Name="LdrModules";    Cmd="windows.ldrmodules";       Desc="Unlinked/Hidden DLLs" }
    $Plugins += @{ Name="DllList";       Cmd="windows.dlllist";          Desc="Loaded DLLs" }
    $Plugins += @{ Name="DriverScan";    Cmd="windows.driverscan";       Desc="Driver Objects" }
    
    # --- SYSTEM ---
    $Plugins += @{ Name="SvcScan";       Cmd="windows.svcscan";          Desc="Services" }
    $Plugins += @{ Name="HiveList";      Cmd="windows.registry.hivelist"; Desc="Registry Hives" }
    $Plugins += @{ Name="FileScan";      Cmd="windows.filescan";         Desc="File Objects (MFT)" }
}
elseif ($OS -eq "Linux") {
    # --- PROCESSES ---
    $Plugins += @{ Name="PsList";        Cmd="linux.pslist";             Desc="Process List" }
    $Plugins += @{ Name="PsTree";        Cmd="linux.pstree";             Desc="Process Tree" }
    $Plugins += @{ Name="PsAux";         Cmd="linux.psaux";              Desc="Process Command Lines" }
    
    # --- USER & NETWORK ---
    $Plugins += @{ Name="Bash";          Cmd="linux.bash";               Desc="Bash History" }
    $Plugins += @{ Name="Netstat";       Cmd="linux.netstat";            Desc="Network Connections" }
    $Plugins += @{ Name="Lsof";          Cmd="linux.lsof";               Desc="Open Files/Sockets" }
    
    # --- ROOTKITS & MALWARE ---
    $Plugins += @{ Name="Malfind";       Cmd="linux.malfind";            Desc="Code Injection" }
    $Plugins += @{ Name="Check_Modules"; Cmd="linux.check_modules";      Desc="Hidden Kernel Modules" }
    $Plugins += @{ Name="Elfs";          Cmd="linux.elfs";               Desc="ELF Binaries in Memory" }
    $Plugins += @{ Name="ProcMaps";      Cmd="linux.proc_maps";          Desc="Process Memory Maps" }
}


# --- 5. EXECUTION ENGINE (PYTHON) ---

foreach ($P in $Plugins) {
    Write-Host "    [+] Running: $($P.Desc) ($($P.Cmd))..." -ForegroundColor Green
    
    $OutFile = Join-Path $CaseDir "$($P.Name).csv"
    
    # Volatility 3 execution via Python
    $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
    $ProcessInfo.FileName = "python"
    $ProcessInfo.Arguments = "`"$VolScript`" -f `"$MemoryFile`" -r csv $($P.Cmd)"
    $ProcessInfo.RedirectStandardOutput = $true
    $ProcessInfo.RedirectStandardError = $false 
    $ProcessInfo.UseShellExecute = $false
    $ProcessInfo.CreateNoWindow = $true
    
    $Process = [System.Diagnostics.Process]::Start($ProcessInfo)
    $Content = $Process.StandardOutput.ReadToEnd()
    $Process.WaitForExit()
    
    if (-not [string]::IsNullOrWhiteSpace($Content)) {
        $Content | Out-File -FilePath $OutFile -Encoding ASCII
    } else {
        Write-Warning "        No data returned or plugin failed."
    }
}


# --- 6. DASHBOARD GENERATOR ---
Write-Host "`n    [*] Generating Interactive Dashboard..." -ForegroundColor Yellow
$ReportFile = Join-Path $CaseDir "Memory_Dashboard.html"

$CSS = @"
<style>
    :root { --primary: #2c3e50; --secondary: #34495e; --accent: #9b59b6; --bg: #f4f7f6; --text: #333; --sidebar: 260px; }
    body { font-family: 'Segoe UI', Inter, sans-serif; margin: 0; background-color: var(--bg); color: var(--text); display: flex; height: 100vh; overflow: hidden; }
    
    /* Sidebar */
    nav { width: var(--sidebar); background: var(--primary); color: white; display: flex; flex-direction: column; height: 100vh; flex-shrink: 0; }
    .brand { padding: 25px; font-size: 1.4em; font-weight: bold; background: linear-gradient(135deg, #2c3e50 0%, #8e44ad 100%); text-align: center; border-bottom: 1px solid rgba(255,255,255,0.1); }
    .nav-links { flex: 1; overflow-y: auto; list-style: none; padding: 0; margin: 0; }
    .nav-links li a { display: block; padding: 12px 20px; color: #bdc3c7; text-decoration: none; border-left: 4px solid transparent; transition: 0.2s; font-size: 0.9em; }
    .nav-links li a:hover, .nav-links li a.active { background: rgba(0,0,0,0.2); color: white; border-left-color: var(--accent); }
    
    /* Main */
    main { flex: 1; overflow-y: auto; padding: 40px; position: relative; scroll-behavior: smooth; }
    .header { margin-bottom: 30px; display: flex; justify-content: space-between; align-items: end; border-bottom: 2px solid #ddd; padding-bottom: 15px; }
    .header h1 { margin: 0; color: var(--primary); font-size: 2.2em; border-left: 8px solid var(--accent); padding-left: 20px; }
    
    /* Card/Table */
    .card { background: white; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); margin-bottom: 35px; overflow: hidden; border: 1px solid #e1e4e8; }
    .card-header { background: var(--secondary); padding: 15px 20px; color: white; display: flex; justify-content: space-between; align-items: center; }
    .search-box { padding: 5px 10px; border-radius: 4px; border: none; font-size: 0.9em; width: 200px; }
    .btn { color: var(--accent); background: white; text-decoration: none; padding: 5px 10px; border-radius: 4px; font-size: 0.8em; font-weight: bold; }
    
    .table-container { overflow-x: auto; max-height: 500px; }
    table { width: 100%; border-collapse: collapse; font-size: 0.85em; }
    th { background: #ecf0f1; color: #2c3e50; padding: 12px; text-align: left; position: sticky; top: 0; }
    td { padding: 10px 12px; border-bottom: 1px solid #eee; white-space: nowrap; }
    tr:nth-child(even) { background: #fafafa; }
    tr:hover { background: #f4ecf7; }
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

$NavItems = ""
$ContentItems = ""
$Counter = 0

$CSVs = Get-ChildItem -Path $CaseDir -Filter "*.csv" | Sort-Object Name

foreach ($File in $CSVs) {
    $Counter++
    $ID = "tbl_" + $Counter
    $SearchID = "src_" + $Counter
    $Name = $File.BaseName
    
    $NavItems += "<li><a href='#$ID'>$Name</a></li>"
    
    try {
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
                    <h3>$Name</h3>
                    <div>
                        <input type='text' id='$SearchID' onkeyup='filterTable("$SearchID", "$ID")' placeholder='Search...' class='search-box'>
                        <a href='$($File.Name)' class='btn'>CSV ⬇</a>
                    </div>
                </div>
                <div class='table-container'>
                    <table id='$ID'><thead><tr>$Th</tr></thead><tbody>$Tr</tbody></table>
                </div>
            </div>
"@
        }
    } catch {
        # Skip empty files
    }
}

$HTML = @"
<!DOCTYPE html><html><head><title>Memory Report</title>$CSS</head><body>
<nav>
    <div class='brand'>🦉 MEMORY</div>
    <ul class='nav-links'>$NavItems</ul>
</nav>
<main>
    <div class='header'>
        <div>
            <h1>Memory Analysis</h1>
            <p>Target: $MemoryFile | OS: $OS | Date: $Timestamp</p>
        </div>
        <div><small>Chimera Triage (Volatility 3)</small></div>
    </div>
    $ContentItems
</main>
</body></html>
"@

Set-Content -Path $ReportFile -Value $HTML

Write-Host "
   [+] ANALYSIS COMPLETE
   ---------------------
   Report: $ReportFile
" -ForegroundColor Cyan

Invoke-Item $ReportFile
Pause