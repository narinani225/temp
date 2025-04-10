<#
.DESCRIPTION
This script installs the PSWindowsUpdate module and uses it to apply Windows updates on the machine.

.NOTES
If using for Azure Windows VMs, this only works for Desktop/Client OS(Win10/Win11), not Server OS.
once updates are installed, This script will execute Chocolatey and using Chocolatey it will install vs code and notepad ++

#>



[CmdletBinding()]
param (
)

$logfile = "C:\Windows\Temp\WinUpdateStep_log.log"
function Write-Log
{
Param ([string]$LogString)
$Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
$LogMessage = "$Stamp $LogString"
Write-Output $LogMessage
Add-content $LogFile -value $LogMessage
}

[bool]$NugetFailed = $false

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    # install the NuGet package provider if required
    if(-not(Get-PackageProvider -Name Nuget -ListAvailable -ErrorAction SilentlyContinue)) {
        Write-Log "Nuget package provider not found. Installing."
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop
        Write-Log -LogString "Installed the Nuget Package Provider"
    }
}
catch {
    Write-log -LogString "ERROR: $($_.Exception.Message)"
    $NugetFailed = $true
}

# check if the package provider is installed.
if(Get-PackageProvider -Name Nuget -ListAvailable -ErrorAction SilentlyContinue) {
    Write-Log -LogString "Nuget package provider is verified installed."
}
else {
    $NugetFailed = $true
}

try {
    # Install the PSWindowsUpdate moduele
    if(-not(Get-Module -Name "PSWindowsUpdate" -ListAvailable -ErrorAction SilentlyContinue)) {
        Write-Log "PSWindowsUpdate module not found. Installing."
        if($NugetFailed) {
            Write-Log -LogString "Failed to install the Nuget provider. Exiting since PSWindowsUpdate module cannot be downloaded without this provider."
            Exit
        } else {
            Install-Module -Name PSWindowsUpdate -Scope AllUsers -Force -Confirm:$false -ErrorAction Stop
        }
        
        Write-Log -LogString "Installed the PSWindowsUpdate module."
    }
}
catch {
    Write-log -LogString "ERROR: $($_.Exception.Message)"
}

Import-Module PSWindowsUpdate
Write-Log -LogString "Imported the PSWindowsUpdate module"

try {
    Add-WUServiceManager -MicrosoftUpdate -Silent -Confirm:$false
    $updates = Get-WindowsUpdate
    if($updates) {
        Write-Log -LogString "Updates are available. Downloading and applying updates."
        Write-Log -LogString "Available Updates: `n$($updates | Out-String)"
        Install-WindowsUpdate -Install -MicrosoftUpdate -AcceptAll -IgnoreReboot | Out-File "C:\Windows\Temp\$(get-date -f yyyy-MM-dd)-WindowsUpdate.log" -Force
        Write-Log -LogString "Installed Windows Updates. You might want to reboot your computer."
        $rebootStatus = Get-WURebootStatus -Silent
        Write-Log -LogString "Reboot required: $rebootStatus"
    }
    else {
        Write-Log -LogString "No updates to install."
    }
}
catch {
    Write-Host "Error while updating Windows: $($_.Exception.Message)"
    Write-log -LogString "ERROR: $($_.Exception.Message)"
}

# Step 1: Set execution policy
try {
    Write-Output "Setting execution policy to Bypass..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Write-Output "Execution policy set successfully."
}
catch {
    Write-Error "Failed to set execution policy. Error: $_"
    exit 1
}

# Step 2: Install Chocolatey
try {
    Write-Output "Installing Chocolatey..."
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Write-Output "Chocolatey installation complete."
}
catch {
    Write-Error "Chocolatey installation failed. Error: $_"
    exit 1
}

# Step 3: Install Notepad++
try {
    Write-Output "Installing Notepad++..."
    choco install notepadplusplus -y
    Write-Output "Notepad++ installed successfully."
}
catch {
    Write-Error "Failed to install Notepad++. Error: $_"
}

# Step 4: Install Visual Studio Code
try {
    Write-Output "Installing Visual Studio Code..."
    choco install vscode -y
    Write-Output "Visual Studio Code installed successfully."
}
catch {
    Write-Error "Failed to install Visual Studio Code. Error: $_"
}

# Step 5: Final version check
try {
    Write-Output "Verifying Chocolatey installation..."
    choco -v
}
catch {
    Write-Error "Chocolatey verification failed. Error: $_"
}
