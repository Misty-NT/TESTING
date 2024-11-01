# Define the output custom field name for NinjaRMM
$customFieldName = "DiskUsageSummary"

# Initialize the output for readability
$usageSummary = "Detailed Disk Usage Summary - $(Get-Date):`n"

# Define a function to get the size of a directory
function Get-DirectorySize {
    param ([string]$directoryPath)
    $totalSize = 0
    try {
        $files = Get-ChildItem -Path $directoryPath -Recurse -File -ErrorAction SilentlyContinue
        $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
    } catch {
        Write-Output "Error reading directory: $directoryPath"
    }
    return $totalSize
}

# Get top-level directories on C drive and their sizes
$topDirectories = Get-ChildItem -Path C:\ -Directory | ForEach-Object {
    # Calculate top-level directory size
    $topDirSize = Get-DirectorySize -directoryPath $_.FullName
    $topDirSizeFormatted = "{0:N2} GB" -f ($topDirSize / 1GB)
    $usageSummary += "$($_.FullName) - $topDirSizeFormatted`n"

    # Get one-level deep subdirectories only for specific directories (e.g., Program Files)
    if ($_.Name -eq "Program Files" -or $_.Name -eq "Users") {
        $subDirectories = Get-ChildItem -Path $_.FullName -Directory -ErrorAction SilentlyContinue
        foreach ($subDirectory in $subDirectories) {
            $subDirSize = Get-DirectorySize -directoryPath $subDirectory.FullName
            $subDirSizeFormatted = "{0:N2} GB" -f ($subDirSize / 1GB)
            $usageSummary += "   ├─ $($subDirectory.Name) - $subDirSizeFormatted`n"
        }
    }
}

# Output the formatted summary to the custom field or a text file for testing
$usageSummary | Out-File -FilePath "$env:TEMP\DetailedDiskUsageReport.txt"
Write-Output "Detailed disk usage report generated at $env:TEMP\DetailedDiskUsageReport.txt"

# Optionally, if running in NinjaRMM, set the custom field
# Ninja-Property-Set $customFieldName $usageSummary
