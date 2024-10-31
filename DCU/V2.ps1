# Define custom field name for results in NinjaRMM
$customFieldName = 'dellCommandUpdateResults'

# Step 1: Check if OS is Server and exit if true
if ((Get-WmiObject Win32_OperatingSystem).ProductType -ne 1) {
    Write-Output "SERVER detected"
    Ninja-Property-Set $customFieldName "SERVER detected - $(Get-Date)"
    exit
}

# Step 2: Check manufacturer and exit if not Dell
$manufacturer = (Get-WmiObject Win32_ComputerSystem).Manufacturer
if ($manufacturer -notlike "*Dell*") {
    Write-Output "Non-Dell device detected"
    Ninja-Property-Set $customFieldName "Non-Dell device - $(Get-Date)"
    exit
}

# Step 3: Check model and exit if incompatible (Vostro or Inspiron)
# To add more models, modify the regex to include them, e.g., "Vostro|Inspiron|NEW MODEL"
$model = (Get-WmiObject Win32_ComputerSystem).Model
if ($model -match "Vostro|Inspiron") {
    Write-Output "NON compatible model detected: $model"
    Ninja-Property-Set $customFieldName "NON compatible model: $model - $(Get-Date)"
    exit
}

# Step 4: Check if Dell Command Update (DCU) is installed
$DCUPathX64 = "C:\Program Files\Dell\CommandUpdate\dcu-cli.exe"
$DCUPathX86 = "C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe"
$dcuCli = if (Test-Path $DCUPathX64) { $DCUPathX64 } elseif (Test-Path $DCUPathX86) { $DCUPathX86 } else { $null }

# Step 5 & 6: If DCU is not found, download and install it
if (-not $dcuCli) {
    Write-Output "Dell Command Update not found, downloading and installing..."

    function Install-DellCommandUpdateUsingInstaller {
        $installerUrl = "https://downloads.dell.com/FOLDER11563484M/1/Dell-Command-Update-Windows-Universal-Application_P83K5_WIN_5.3.0_A00.EXE"
        $installerPath = "$env:TEMP\DCU_Setup.exe"
        try {
            Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -ErrorAction Stop
            Start-Process -FilePath $installerPath -ArgumentList '/s' -Wait -NoNewWindow -ErrorAction Stop
            Remove-Item $installerPath -Force -ErrorAction Stop
            Write-Output "Dell Command Update successfully installed"
            return $true
        } catch {
            Write-Output "Failed to install Dell Command Update: $_"
            return $false
        }
    }

    $installSuccess = Install-DellCommandUpdateUsingInstaller
    if (-not $installSuccess) {
        Ninja-Property-Set $customFieldName "DCU installation failed - $(Get-Date)"
        exit
    }
    $dcuCli = if (Test-Path $DCUPathX64) { $DCUPathX64 } elseif (Test-Path $DCUPathX86) { $DCUPathX86 } else { $null }
}

# Step 7: Run DCU to check for updates, install, and gather results
if ($dcuCli) {
    Write-Output "Running Dell Command Update for driver updates..."

    $dcuResults = & $dcuCli /scan /applyUpdates /silent
    $installedDrivers = ($dcuResults | Select-String -Pattern "Installed").Matches | ForEach-Object { $_.Value }
    $failedDrivers = ($dcuResults | Select-String -Pattern "Failed").Matches | ForEach-Object { $_.Value }
    $rebootRequired = if ($dcuResults -match "Reboot required") { "Yes" } else { "No" }

    # Step 8: Log the update results to NinjaRMM custom field
    $updateSummary = "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" + "`n" +
                     "Installed Drivers: $installedDrivers" + "`n" +
                     "Failed Drivers: $failedDrivers" + "`n" +
                     "Reboot Required: $rebootRequired"
    Ninja-Property-Set $customFieldName $updateSummary
}
else {
    Write-Output "Dell Command Update could not be found or installed"
    Ninja-Property-Set $customFieldName "DCU not found or installed - $(Get-Date)"
}
