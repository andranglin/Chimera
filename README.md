# 🦁 Chimera Triage Toolkit

![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux-blue?style=for-the-badge&logo=linux) ![Language](https://img.shields.io/badge/Language-PowerShell%20%7C%20Bash-green?style=for-the-badge&logo=powershell) [![Documentation](https://img.shields.io/badge/Docs-RootGuard%20GitBook-blue?style=for-the-badge&logo=gitbook)](https://rootguard.gitbook.io/rootguard/)

**Chimera** is a modular, agent-less forensic triage framework designed for Incident Response (IR) teams. It bridges the gap between fast "Live Response" and deep-dive forensics by orchestrating industry-standard tools (EZTools, AVML, Hindsight) via PowerShell and SSH.

> **Note:** This tool is designed for authorised forensic acquisition only.

---

## 📚 Documentation & Knowledge Base

Chimera is part of the **RootGuard** ecosystem. For detailed usage instructions, forensic methodology, and artifact analysis guides, visit our official documentation:

👉 **[RootGuard Official Docs (GitBook)](https://rootguard.gitbook.io/cyberops)**

---

## ⚡ Key Features

### 🪟 Windows Forensics
* **Shadow Copy (VSS) Access:** Bypasses file locks to parse Registry, Event Logs, and filesystem artifacts.
* **Eric Zimmerman Integration:** Native support for EZTools (Amcache, Shimcache, Registry) outputting directly to CSV.
* **Browser Forensics:** Automated history/profile parsing for Chrome, Edge, and Brave using *Hindsight*.

### 🐧 Linux Forensics
* **Zero-Footprint Triage:** Pushes a static payload via SSH, executes via RAM/Tmp, and cleans up traces automatically.
* **"The Goat" Engine:** A hybrid collection script combining methodologies for deep artifact hunting (Web Shells, Rootkits, User History, Docker, Databases).
* **Memory Acquisition:** Streamlined RAM capture using Microsoft's *AVML* with on-the-fly compression to minimize transfer time.

---

## 🧠 RootGuard DFIR Resources

Beyond this tool, **RootGuard** provides a comprehensive learning hub for Digital Forensics and Incident Response. Visit the site to explore topics including:

* **Linux Forensics:** Deep dives into `/proc` analysis, inode anomaly detection, and persistence hunting.
* **Windows Artifacts:** Understanding ShimCache, Amcache, and SRUM for evidence of execution.
* **Memory Forensics:** Methodologies for acquiring and analysing volatile memory.
* **Incident Response Playbooks:** Structured workflows for handling Ransomware, BEC, and Web Shell incidents.

[**Explore the Knowledge Base**](https://rootguard.gitbook.io/cyberops)

---

## 📦 Installation & Setup

Chimera requires external third-party tools (EZTools, AVML, Hindsight) to function. These are not included in the repo to ensure you always use the latest verifiable binaries.

👉 **[Read the Full Installation Guide](INSTALL.md)**

---

## 🚀 Quick Usage

1.  **Open PowerShell** as Administrator.
2.  **Unblock Scripts** (First time only):
    ```powershell
    Get-ChildItem -Recurse | Unblock-File
    ```
3.  **Run the Launcher**:
    ```powershell
    .\Chimera.ps1
    ```

---

## 🧩 Module Manifest

| Module | OS | Description |
| :--- | :--- | :--- |
| `Invoke-WinArtifacts` | Windows | VSS-based artifact collection (Registry, Event Logs, ShimCache). |
| `Invoke-BrowserArtifacts` | Windows | Multi-browser history and download parsing. |
| `Invoke-LinuxLiveResponse` | Linux | Hybrid forensic triage (System, Network, Persistence, Web Shells). |
| `Invoke-LinuxMemCapture` | Linux | Remote RAM acquisition using AVML + Gzip streaming. |

---

## ⚠️ Disclaimer

This software is provided "as is", without warranty of any kind. The author is not responsible for any damage or legal issues caused by the use of this tool. Always ensure you have proper authorization before running forensic acquisition tools on any network or endpoint.

---

*Project maintained by [RootGuard](https://rootguard.gitbook.io/cyberops)*
