Recover items deleted from this folder (40 items)
# Define the CLI executable name and installer URL
$cliExecutable = 'dcu-cli.exe'
$installerUrl = "https://downloads.dell.com/FOLDER11563484M/1/Dell-Command-Update-Windows-Universal-Application_P83K5_WIN_5.3.0_A00.EXE"

# Define potential locations where DCU can be found
$potentialDcuInstallPaths = @(
    'C:\Program Files\Dell\Command Update\',
    'C:\Program Files (x86)\Dell\Command Update\'
)

# Patterns to detect conflicting Dell applications
$conflictingAppPatterns = @(
    "*Dell Update*",
    "*Dell SupportAssist*",
    "*Dell*Update*",
    "*SupportAssist*"
)

# Function to retrieve system manufacturer and model information
function Get-SystemInfo {
    $system = Get-WmiObject -Class Win32_ComputerSystem
    return @{
        Manufacturer = $system.Manufacturer
        Model = $system.Model
    }
}

# Function to check if DCU is installed
function Check-DellCommandUpdateInstalled {
    foreach ($path in $potentialDcuInstallPaths) {
        $dcuPath = Join-Path -Path $path -ChildPath $cliExecutable
        if (Test-Path $dcuPath) {
            return $dcuPath
        }
    }
    return $null
}

# Function to download and install Dell Command Update
function Install-DellCommandUpdate {
    $installerPath = "$env:TEMP\DCU_Setup.exe"
    try {
        Write-Output "Downloading Dell Command Update..."
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -ErrorAction Stop
        Write-Output "Installing Dell Command Update..."
        Start-Process -FilePath $installerPath -ArgumentList '/s' -Wait -NoNewWindow -ErrorAction Stop
        Remove-Item $installerPath -Force -ErrorAction Stop
        Write-Output "Dell Command Update installed successfully."
        return $true
    } catch {
        Write-Output "Failed to install Dell Command Update: $_"
        return $false
    }
}

# Function to check and remove incompatible applications
function Remove-IncompatibleApps {
    foreach ($pattern in $conflictingAppPatterns) {
        $apps = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like $pattern }
        foreach ($app in $apps) {
            try {
                Write-Output "Removing incompatible application: $($app.Name)"
                $app.Uninstall() | Out-Null
                Write-Output "Successfully removed: $($app.Name)"
            } catch {
                Write-Output "Failed to remove $($app.Name): $_"
            }
        }
    }
}

# Function to scan and install driver updates
function Update-DriversWithDCU {
    param (
        [string]$dcuPath
    )

    Write-Output "Scanning for available updates..."
    $scanResult = & "$dcuPath" /scan -outputFormat:xml

    if ($scanResult -like "*No updates found*") {
        Write-Output "No driver updates found."
        return
    }

    Write-Output "Installing available updates without reboot..."
    $installResult = & "$dcuPath" /applyUpdates -outputFormat:xml -reboot=disable

    # Parse the results for success and failure statuses
    $successUpdates = Select-String -InputObject $installResult -Pattern "Update.*Success" -AllMatches | ForEach-Object { $_.Matches.Value }
    $failedUpdates = Select-String -InputObject $installResult -Pattern "Update.*Failed" -AllMatches | ForEach-Object { $_.Matches.Value }

    # Reporting results
    Write-Output "Driver Update Results:"
    if ($successUpdates.Count -gt 0) {
        Write-Output "Successful Updates:"
        $successUpdates | ForEach-Object { Write-Output $_ }
    } else {
        Write-Output "No updates were successfully installed."
    }

    if ($failedUpdates.Count -gt 0) {
        Write-Output "Failed Updates:"
        $failedUpdates | ForEach-Object { Write-Output $_ }
    }
}

# Main execution
$systemInfo = Get-SystemInfo
$manufacturer = $systemInfo.Manufacturer
$model = $systemInfo.Model

# Check if the computer is a Dell
if ($manufacturer -ne "Dell Inc.") {
    Write-Output "System is not a Dell. Manufacturer: $manufacturer, Model: $model. Exiting script."
    exit 1
}

# Check if it is a Vostro model
if ($model -match "Vostro") {
    Write-Output "Not compatible: Dell Vostro model detected. Model: $model. Exiting script."
    exit 1
}

# Check if it is a Server model
if ($model -match "Server") {
    Write-Output "Warning: Server model detected. Model: $model. Exiting script."
    exit 1
}

# For compatible Dell models, check if DCU is installed
$dcuPath = Check-DellCommandUpdateInstalled
if (-not $dcuPath) {
    # Remove any incompatible applications before installing DCU
    Write-Output "Checking for incompatible applications..."
    Remove-IncompatibleApps

    # Proceed to install DCU if not present
    Write-Output "Dell Command Update not found. Proceeding to download and install."
    $installSuccess = Install-DellCommandUpdate
    if ($installSuccess) {
        # Re-check the installation path
        $dcuPath = Check-DellCommandUpdateInstalled
        if (-not $dcuPath) {
            Write-Output "Failed to verify Dell Command Update installation after install."
            exit 1
        }
    } else {
        Write-Output "Failed to install Dell Command Update."
        exit 1
    }
} else {
    Write-Output "Dell Command Update is already installed."
}

# Proceed to update drivers if DCU is installed
Update-DriversWithDCU -dcuPath $dcuPath
