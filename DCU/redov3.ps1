# Function to download and install Dell Command Update using the installer from Dell's website
function Install-DellCommandUpdateUsingInstaller {
    $installerUrl = "https://downloads.dell.com/FOLDER11563484M/1/Dell-Command-Update-Windows-Universal-Application_P83K5_WIN_5.3.0_A00.EXE"
    $installerPath = "$env:TEMP\DCU_Setup.exe"
    try {
        # Download the installer
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -ErrorAction Stop
        # Install the application silently
        Start-Process -FilePath $installerPath -ArgumentList '/s' -Wait -NoNewWindow -ErrorAction Stop
        # Clean up by removing the installer file
        Remove-Item $installerPath -Force -ErrorAction Stop
        return $true
    } catch {
        Write-Output "Failed to install Dell Command Update: $_"
        return $false
    }
}

# Function to check if Dell Command Update is installed
function Check-DellCommandUpdateInstallation {
    $PossibleDcuCliPaths = @("C:\Program Files\Dell\CommandUpdate\dcu-cli.exe", "C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe")
    $DcuCliPath = ($PossibleDcuCliPaths | Where-Object { Test-Path $_ -PathType Leaf })[0]

    if (-not $DcuCliPath) {
        Write-Output "Dell Command Update executable not found."
        return $null
    } else {
        Write-Output "Dell Command Update is installed."
        return $DcuCliPath
    }
}

# Main script logic
try {
    # Check if computer is a Dell
    $computerManufacturer = (Get-WmiObject -Class Win32_ComputerSystem).Manufacturer
    $computerModel = (Get-WmiObject -Class Win32_ComputerSystem).Model

    if ($computerManufacturer -notlike "*Dell*") {
        Write-Output "This computer is not a Dell. Exiting script."
        exit
    }

    # Check if the model is a Vostro, Inspiron, or Server
    if ($computerModel -like "*Vostro*" -or $computerModel -like "*Inspiron*" -or $computerModel -like "*Server*") {
        Write-Output "Non-compatible model detected: $computerModel. Exiting script."
        exit
    }

    # Check if DCU is already installed
    $DcuCliPath = Check-DellCommandUpdateInstallation

    if (-not $DcuCliPath) {
        # Install DCU if not found
        $installSuccess = Install-DellCommandUpdateUsingInstaller
        if (-not $installSuccess) {
            Write-Output "DCU installation failed. Exiting script."
            exit
        }
        # Verify the installation
        $DcuCliPath = Check-DellCommandUpdateInstallation
        if (-not $DcuCliPath) {
            Write-Output "Dell Command Update installation verification failed. Exiting script."
            exit
        }
    }

    # Start driver scan and installation
    Write-Output "Starting driver scan and installation..."
    $driverScan = Start-Process -FilePath $DcuCliPath -ArgumentList "/scan" -NoNewWindow -Wait -PassThru
    if ($driverScan.ExitCode -ne 0) {
        Write-Output "Driver scan failed. Exiting script."
        exit
    }

    $installDrivers = Start-Process -FilePath $DcuCliPath -ArgumentList "/applyUpdates -noRestart" -NoNewWindow -Wait -PassThru
    $rebootRequired = $false
    $installedDrivers = @()
    $failedDrivers = @()

    # Parse DCU logs for results
    $logFilePath = "C:\ProgramData\Dell\UpdateService\Log\dellCommandUpdate.log"
    if (Test-Path $logFilePath) {
        $logContent = Get-Content $logFilePath -Raw

        if ($logContent -match "Reboot Required") {
            $rebootRequired = $true
        }

        foreach ($line in $logContent -split "`n") {
            if ($line -match "Installed Driver") {
                $installedDrivers += $line
            } elseif ($line -match "Failed Driver") {
                $failedDrivers += $line
            }
        }
    }

    # Prepare output for Ninja RMM
    $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "Date: $date`nInstalled Drivers: $($installedDrivers -join ", ")`nFailed Drivers: $($failedDrivers -join ", ")"
    if ($rebootRequired) {
        $logEntry += "`nReboot Required: Yes"
    } else {
        $logEntry += "`nReboot Required: No"
    }

    # Output the log to Ninja RMM custom field
    try {
        # Replace `Ninja-Property-Set` with actual Ninja RMM field set command or API call
        Ninja-Property-Set dellCommandUpdateResults $logEntry
        Write-Output "Successfully logged DCU results to Ninja RMM."
    } catch {
        Write-Output "Failed to log DCU results to Ninja RMM:" $_
    }

} catch {
    Write-Output "An error occurred: $_"
}
