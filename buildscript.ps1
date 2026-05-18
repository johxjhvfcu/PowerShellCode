# ================================
# System Configuration Script
# ================================
# Must be run as Administrator
# ================================

# ================================
# Summary File Setup
# ================================
$SummaryPath = "C:\Users\Public\Desktop\System_Config_Summary.txt"

New-Item -Path $SummaryPath -ItemType File -Force | Out-Null

function Write-Summary {
    param (
        [string]$Message
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp - $Message" | Out-File -FilePath $SummaryPath -Append -Encoding UTF8
}

Write-Summary "===== System Configuration Started ====="

# ================================
# Get computer name
# ================================
$ComputerName = $env:COMPUTERNAME
Write-Host "Running on computer: $ComputerName"
Write-Summary "Computer Name: $ComputerName"

# ================================
# Disable TCP/IP v6
# ================================
try {
    Disable-NetAdapterBinding -Name "*" -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue
    Write-Summary "TCP/IP v6 disabled on all adapters"
}
catch {
    Write-Summary "ERROR disabling TCP/IP v6: $($_.Exception.Message)"
}

# ================================
# Disable Windows Firewall (Domain)
# ================================
try {
    Set-NetFirewallProfile -Profile Domain -Enabled False
    Write-Summary "Windows Firewall (Domain Profile) disabled"
}
catch {
    Write-Summary "ERROR disabling Domain Firewall: $($_.Exception.Message)"
}

# ================================
# Veeam SQL Registry Key (SQL only)
# ================================
if ($ComputerName -like "*SQL*") {
    try {
        $VeeamRegPath = "HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication"
        New-Item -Path $VeeamRegPath -Force | Out-Null

        New-ItemProperty `
            -Path $VeeamRegPath `
            -Name "UseSqlNativeClientProvider" `
            -PropertyType DWord `
            -Value 1 `
            -Force | Out-Null

        Write-Summary "SQL system detected - Veeam registry key configured"
    }
    catch {
        Write-Summary "ERROR configuring Veeam SQL registry key: $($_.Exception.Message)"
    }
}
else {
    Write-Summary "Non-SQL system detected - Veeam configuration skipped"
}

# ================================
# Local Administrator password
# ================================
try {
    Set-LocalUser -Name "Administrator" -PasswordNeverExpires $true
    Write-Summary "Local Administrator password set to never expire"
}
catch {
    Write-Summary "ERROR setting Administrator password policy: $($_.Exception.Message)"
}

# ================================
# Install BigFix Client
# ================================
try {
    $BigFixSource      = "\\imgsrv01\ghost$\Software For A New Build\Bigfix Client\10.0.11.108\Windows"
    $BigFixDestination = "C:\BigFixInstall"

    New-Item -Path $BigFixDestination -ItemType Directory -Force | Out-Null
    robocopy $BigFixSource $BigFixDestination /E /COPY:DAT /R:3 /W:5 /NFL /NDL | Out-Null

    Start-Process "$BigFixDestination\setup.exe" -ArgumentList "/S /v/qn" -Wait
    Write-Summary "BigFix Client installed successfully"
}
catch {
    Write-Summary "ERROR installing BigFix Client: $($_.Exception.Message)"
}

# ================================
# Install Rapid7 Agent
# ================================
try {
    $Rapid7Source      = "\\imgsrv01\ghost$\Software For A New Build\Rapid7-Agent\Windows\R7"
    $Rapid7Destination = "C:\Rapid7Install"

    New-Item -Path $Rapid7Destination -ItemType Directory -Force | Out-Null
    robocopy $Rapid7Source $Rapid7Destination /E /COPY:DAT /R:3 /W:5 /NFL /NDL | Out-Null

    Start-Process `
        -FilePath "msiexec.exe" `
        -ArgumentList "/i `"$Rapid7Destination\agentInstaller-x86_64.msi`" /quiet /norestart" `
        -Wait `
        -NoNewWindow

    Write-Summary "Rapid7 Agent installed successfully"
}
catch {
    Write-Summary "ERROR installing Rapid7 Agent: $($_.Exception.Message)"
}

# ================================
# Windows Updates
# ================================
try {
    Write-Summary "Starting Windows Update scan"

    $UpdateSession   = New-Object -ComObject Microsoft.Update.Session
    $UpdateSearcher  = $UpdateSession.CreateUpdateSearcher()
    $SearchResult    = $UpdateSearcher.Search("IsInstalled=0 and Type='Software'")
    $UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl

    foreach ($Update in $SearchResult.Updates) {
        $UpdatesToInstall.Add($Update) | Out-Null
    }

    Write-Summary "$($SearchResult.Updates.Count) updates found"

    $Downloader = $UpdateSession.CreateUpdateDownloader()
    $Downloader.Updates = $UpdatesToInstall
    $Downloader.Download()

    $Installer = $UpdateSession.CreateUpdateInstaller()
    $Installer.Updates = $UpdatesToInstall
    $Result = $Installer.Install()

    if ($Result.RebootRequired) {
        Write-Summary "Updates installed - reboot required"
    }
    else {
        Write-Summary "Updates installed - no reboot required"
    }
}
catch {
    Write-Summary "ERROR during Windows Update: $($_.Exception.Message)"
}

Write-Summary "===== System Configuration Completed ====="
######## End of Script ########