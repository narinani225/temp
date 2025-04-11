<#

.DESCRIPTION

This script installs the PSWindowsUpdate module and uses it to apply Windows updates on the machine.

.NOTES

If using for Azure Windows VMs, this only works for Desktop/Client OS(Win10/Win11), not Server OS.

Once updates are installed, this script will execute Chocolatey and use it to install VS Code and Notepad++.

#>
 
[CmdletBinding()]

param ()
 
$logfile = "C:\Windows\Temp\WinUpdateStep_log.log"
 
# Function for logging

function Write-Log {

    Param ([string]$LogString)

    $Stamp = (Get-Date).ToString("yyyy/MM/dd HH:mm:ss")

    $LogMessage = "$Stamp $LogString"

    Write-Output $LogMessage

    Add-content $logfile -value $LogMessage

}
 
[bool]$NugetFailed = $false

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
 
# Check for NuGet provider

try {

    if (-not (Get-PackageProvider -Name Nuget -ListAvailable -ErrorAction SilentlyContinue)) {

        Write-Log "NuGet package provider not found. Installing."

        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop

        Write-Log "Installed the Nuget Package Provider"

    }

}

catch {

    Write-Log "ERROR: $($_.Exception.Message)"

    $NugetFailed = $true

}
 
if ($NugetFailed) {

    Write-Log "Skipping PSWindowsUpdate installation due to NuGet failure."

    Exit

}
 
# Install PSWindowsUpdate module

try {

    if (-not (Get-Module -Name "PSWindowsUpdate" -ListAvailable -ErrorAction SilentlyContinue)) {

        Write-Log "PSWindowsUpdate module not found. Installing."

        if ($NugetFailed) {

            Write-Log "Failed to install the NuGet provider. Exiting since PSWindowsUpdate module cannot be downloaded."

            Exit

        } else {

            Install-Module -Name PSWindowsUpdate -Scope AllUsers -Force -Confirm:$false -ErrorAction Stop

        }

        Write-Log "Installed the PSWindowsUpdate module."

    }

}

catch {

    Write-Log "ERROR: $($_.Exception.Message)"

}
 
Import-Module PSWindowsUpdate

Write-Log "Imported the PSWindowsUpdate module"
 
# Check for Windows updates

try {

    Add-WUServiceManager -MicrosoftUpdate -Silent -Confirm:$false

    $updates = Get-WindowsUpdate

    if ($updates) {

        Write-Log "Updates are available. Downloading and applying updates."

        Install-WindowsUpdate -Install -MicrosoftUpdate -AcceptAll -IgnoreReboot | Out-File "C:\Windows\Temp\$(get-date -f yyyy-MM-dd)-WindowsUpdate.log" -Force

        Write-Log "Installed Windows Updates. You might want to reboot your computer."

        $rebootStatus = Get-WURebootStatus -Silent

        Write-Log "Reboot required: $rebootStatus"

    }

    else {

        Write-Log "No updates to install."

    }

}

catch {

    Write-Log "ERROR: $($_.Exception.Message)"

}
 
# Set execution policy

try {

    Write-Log "Setting execution policy to Bypass..."

    Set-ExecutionPolicy Bypass -Scope Process -Force

    Write-Log "Execution policy set successfully."

}

catch {

    Write-Log "Failed to set execution policy. Error: $_"

    exit 1

}
 
# Install Chocolatey

$chocoInstalled = $false

$retryCount = 0

$maxRetries = 5
 
while (-not $chocoInstalled -and $retryCount -lt $maxRetries) {

    try {

        Write-Log "Installing Chocolatey..."

        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

        Write-Log "Chocolatey installation complete."

        $chocoInstalled = $true

    }

    catch {

        Write-Log "Chocolatey installation failed. Error: $_"

        $retryCount++

        Write-Log "Retrying ($retryCount of $maxRetries)..."

        Start-Sleep -Seconds 10  # Increase delay

    }

}
 
if (-not $chocoInstalled) {

    Write-Log "Failed to install Chocolatey after $maxRetries attempts."

    exit 1

}
 
# Verify Chocolatey installation

try {

    Write-Log "Verifying Chocolatey installation..."

    choco -v

}

catch {

    Write-Log "Chocolatey verification failed. Error: $_"

}
 
 
 
# Install Notepad++

try {

    Write-Log "Installing Putty..."

    choco install putty -y

    Write-Log "Putty installed successfully."

}

catch {

    Write-Log "Failed to install Putty. Error: $_"

}
 
 
 
try {

    Start-Process -FilePath "C:\Windows\System32\Sysprep\sysprep.exe" -ArgumentList "/generalize","/shutdown","/oobe" -Wait

}

catch {

    Write-Host "Error while sysprepping: $($_.Exception.Message)"

    Write-Host "Please check the logs in the SysPrep\Panther folder"

}
 
