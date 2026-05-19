###Deletes a file on a remote system. Logs the result to a log file.###
param (
    [Parameter(Mandatory = $true)]
    [string]$Address,

    [Parameter(Mandatory = $true)]
    [string]$Path
)

# --- Config ---
$LogFile = "C:\Automation\Logs\FileDelete.log"

# --- Function: Write Log ---
function Write-Log {
    param ([string]$Message)

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp [$Address] $Message"

    Add-Content -Path $LogFile -Value $entry
    Write-Output $entry
}

try {
    Write-Log "Starting remote file delete. Target: $Address | Path: $Path"

    # Run command on remote system
    $result = Invoke-Command -ComputerName $Address -ScriptBlock {
        param($remotePath)

        if (Test-Path $remotePath) {
            Remove-Item -Path $remotePath -Force -ErrorAction Stop
            return "SUCCESS: File deleted"
        }
        else {
            return "INFO: File not found"
        }

    } -ArgumentList $Path -ErrorAction Stop

    Write-Log $result
    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}