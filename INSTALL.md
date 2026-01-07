# 🦁 Chimera Triage Toolkit
**A Modular Forensic Acquisition & Triage Framework**

[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux-blue?style=flat-square&logo=linux)](https://github.com/YOUR_USERNAME/Chimera)
[![Language](https://img.shields.io/badge/Language-PowerShell%20%7C%20Bash-green?style=flat-square&logo=powershell)](https://github.com/YOUR_USERNAME/Chimera)
[![License](https://img.shields.io/badge/License-MIT-orange?style=flat-square)](LICENSE)

Chimera is a modular PowerShell framework designed for Incident Response. While the scripts are included in this repository, **you must download the third-party forensic tools separately** to ensure compliance and version integrity.

---

## 📑 Table of Contents
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Tool Dependencies (Required)](#-tool-dependencies-required)
    - [Windows Tools](#-windows-tools)
    - [Linux Tools](#-linux-tools)
    - [Common Analysis Tools](#-common--analysis-tools)
- [Final Directory Structure](#-final-directory-structure)
- [Usage Guide](#-usage-guide)
- [Troubleshooting](#-troubleshooting)

---

## 📋 Prerequisites

* **Host Machine:** Windows 10 / 11 / Server 2016+
* **PowerShell:** Version 5.1 or newer (Run as Administrator)
* **Networking:**
    * **OpenSSH Client** (Required for Linux modules).
    * **WinRM / SMB** (Required for Remote Windows modules).

---

## 🚀 Quick Start

### 1. Clone the Repository
Download the scripts to your analysis machine or a secure triage USB drive.

```powershell
git clone https://github.com/YOUR_USERNAME/Chimera.git
cd Chimera
```

### 2. Unblock Scripts
Windows blocks downloaded scripts by default. Run this one-liner in an **Admin PowerShell** terminal to unblock the suite:

```powershell
Get-ChildItem -Recurse | Unblock-File
```

---

## 🛠️ Tool Dependencies (Required)

Chimera acts as an orchestrator for industry-standard tools. You must download these binaries and place them in the correct `Tools` directory.

### 🪟 Windows Tools

<details>
<summary><b>1. EZTools (Artifact Parsing) - Click to Expand</b></summary>

* **Target:** Registry, Amcache, Shimcache, Event Logs
* **Download:** [Eric Zimmerman's GitHub](https://ericzimmerman.github.io/#!index.md)
* **Location:** `Chimera\Tools\Windows\EZTools\`
* **Required Files:**
    * `RECmd.exe`
    * `PECmd.exe`
    * `AmcacheParser.exe`
    * `AppCompatCacheParser.exe`
    * `LECmd.exe`
    * `JLECmd.exe`

</details>

<details>
<summary><b>2. KAPE (Triage) - Click to Expand</b></summary>

* **Target:** Fast Artifact Collection
* **Download:** [Kroll KAPE](https://www.kroll.com/en/services/cyber-risk/incident-response-litigation-support/kroll-artifact-parser-extractor-kape)
* **Location:** `Chimera\Tools\Windows\KAPE\`
* **Note:** Ensure `kape.exe` is directly inside this folder, not nested (e.g., `Tools\Windows\KAPE\kape.exe`).

</details>

<details>
<summary><b>3. Hindsight (Browser Forensics) - Click to Expand</b></summary>

* **Target:** Chrome, Edge, Brave History
* **Download:** [Obsidian Forensics](https://github.com/obsidianforensics/hindsight/releases)
* **Location:** `Chimera\Tools\Windows\Hindsight\`
* **Action:** Rename the downloaded file to `hindsight.exe`.

</details>

<details>
<summary><b>4. Memory Acquisition - Click to Expand</b></summary>

* **Target:** Windows RAM
* **Download:** [Magnet DumpIt](https://www.magnetforensics.com/resources/magnet-dumpit-for-windows/) or [Magnet RAM Capture](https://www.magnetforensics.com/resources/magnet-ram-capture/)
* **Location:** `Chimera\Tools\Windows\Memory\`

</details>

### 🐧 Linux Tools

<details>
<summary><b>1. AVML (Memory Acquisition) - Click to Expand</b></summary>

* **Target:** Linux RAM
* **Download:** [Microsoft AVML](https://github.com/microsoft/avml/releases)
* **Location:** `Chimera\Tools\Linux\`
* **Action:** Rename the file to `avml` (remove any extension).

</details>

### 🌐 Common / Analysis Tools

<details>
<summary><b>1. Volatility 3 (Memory Analysis) - Click to Expand</b></summary>

* **Target:** Post-Acquisition Memory Analysis
* **Download:** [Volatility Foundation](https://github.com/volatilityfoundation/volatility3)
* **Location:** `Chimera\Tools\Common\volatility3\`
* **Note:** Ensure `vol.py` is present in this folder.

</details>

---

## 📂 Final Directory Structure

Ensure your file tree looks **exactly** like this. The scripts depend on these specific paths to load the tools.

```text
Chimera/
│
├── Chimera.ps1                       # Main Menu Launcher
├── README.md
├── INSTALL.md
├── .gitignore
│
├── Modules/
│   ├── Common/
│   │   └── Invoke-MemoryAnalysis.ps1
│   │
│   ├── Windows/
│   │   ├── Invoke-BrowserArtifacts.ps1
│   │   ├── Invoke-KapeWrapper.ps1
│   │   ├── Invoke-MemoryCapture.ps1
│   │   ├── Invoke-RemoteWindows.ps1
│   │   ├── Invoke-WinArtifacts.ps1
│   │   └── Invoke-WinLiveResponse.ps1
│   │
│   └── Linux/
│       ├── Invoke-LinuxLiveResponse.ps1
│       └── Invoke-LinuxMemCapture.ps1
│
└── Tools/
    ├── Common/
    │   └── volatility3/              # [Folder containing vol.py]
    │
    ├── Windows/
    │   ├── EZTools/                  # [Folder containing RECmd.exe, etc.]
    │   ├── Hindsight/                # [Folder containing hindsight.exe]
    │   ├── KAPE/                     # [Folder containing kape.exe]
    │   └── Memory/                   # [Folder containing DumpIt.exe]
    │
    └── Linux/
        ├── avml                      # [Binary File]
        └── Memory/                   # [Optional output folder]
```

---

## ▶️ Usage Guide

### Launching the Framework
1.  Open PowerShell as **Administrator**.
2.  Navigate to the `Chimera` directory.
3.  Run the launcher:

```powershell
.\Chimera.ps1
```

### 📦 Module Overview

#### 🪟 Windows Modules
* **`Invoke-WinLiveResponse`**: Full live triage (Processes, Network, Services).
* **`Invoke-WinArtifacts`**: VSS-based parsing of Registry, ShimCache, Amcache.
* **`Invoke-KapeWrapper`**: Wrapper to execute KAPE triage profiles.
* **`Invoke-MemoryCapture`**: Acquires RAM using DumpIt or Magnet.
* **`Invoke-RemoteWindows`**: Remote triage via WinRM/SMB.

#### 🐧 Linux Modules
* **`Invoke-LinuxLiveResponse`**: **"The Goat"** - Hybrid Bash/PS forensic triage engine.
* **`Invoke-LinuxMemCapture`**: Remote RAM acquisition using AVML + Gzip.

#### 🌐 Common Modules
* **`Invoke-MemoryAnalysis`**: Post-acquisition analysis using Volatility 3.

---

## ❓ Troubleshooting

### ❌ "Script is not digitally signed"
Your Execution Policy is restricting the script. Run this command:
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

### ❌ "KAPE not found"
Double-check your path. It should be `Tools\Windows\KAPE\kape.exe`. Avoid nested folders like `KAPE\KAPE\kape.exe`.

### ❌ "Access Denied" on output folders
Ensure you are running PowerShell as **Administrator**. Shadow Copy (VSS) operations require high privileges.

### ❌ Linux SSH Errors
Ensure the **OpenSSH Client** is installed on your Windows host:
*Settings > Apps > Optional Features > Add a feature > OpenSSH Client*

---

*For educational and authorized forensic use only.*