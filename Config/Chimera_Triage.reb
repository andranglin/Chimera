Description: Chimera Comprehensive Triage
Author: RootGuard
Version: 3.0
Id: 1001
Keys:
    # --- FILE ACCESS & MRUs ---
    - HiveType: NTUSER
      KeyPath: Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU
      Recursive: true
      Comment: Access_RunDialog
    - HiveType: NTUSER
      KeyPath: Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths
      Recursive: true
      Comment: Access_UserTypedPaths
    - HiveType: NTUSER
      KeyPath: Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRU
      Recursive: true
      Comment: Access_LastVisitedMRU
    - HiveType: NTUSER
      KeyPath: Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs
      Recursive: true
      Comment: Access_RecentDocs
    - HiveType: NTUSER
      KeyPath: Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist
      Recursive: true
      Comment: Execution_UserAssist
    - HiveType: NTUSER
      KeyPath: Software\Microsoft\Office\*\*\File MRU
      Recursive: true
      Comment: Access_Office_Recent

    # --- DEVICES & USB ---
    - HiveType: SYSTEM
      KeyPath: ControlSet001\Enum\USBSTOR
      Recursive: true
      Comment: Device_USBSTOR
    - HiveType: SOFTWARE
      KeyPath: Microsoft\Windows Portable Devices\Devices
      Recursive: true
      Comment: Device_Portable
    - HiveType: SYSTEM
      KeyPath: MountedDevices
      Recursive: true
      Comment: Device_Mounted
    - HiveType: SYSTEM
      KeyPath: ControlSet001\Enum\SWD\WPDBUSENUM
      Recursive: true
      Comment: Device_WPD_Bus

    # --- EXECUTION ---
    - HiveType: SYSTEM
      KeyPath: ControlSet001\Services\bam\State\UserSettings
      Recursive: true
      Comment: Execution_BAM_DAM
    - HiveType: SOFTWARE
      KeyPath: Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store
      Recursive: true
      Comment: Execution_AppCompat

    # --- NETWORK & REMOTE ---
    - HiveType: NTUSER
      KeyPath: Software\Microsoft\Terminal Server Client
      Recursive: true
      Comment: RDP_History
    - HiveType: SOFTWARE
      KeyPath: Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles
      Recursive: true
      Comment: Network_Profiles