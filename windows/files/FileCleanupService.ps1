<#
.SYNOPSIS
    Windows service script to auto-delete old files in a directory based on TTL.
.DESCRIPTION
    Reads the following environment variables:
        DELIVERY_DIR  - The folder to monitor
        TTL_HOURS     - Time to live in hours for files
        CLEANUP_LOG   - Optional log path
        CHECK_INTERVAL_MIN - Optional interval to check folder
#>

# -------------------------------
# Configuration
# -------------------------------
$DeliveryDir       = $env:DELIVERY_DIR
$TTLHours          = [int]$env:TTL_HOURS
$CheckIntervalMin  = if ($env:CHECK_INTERVAL_MIN) { [int]$env:CHECK_INTERVAL_MIN } else { 10 }
$LogFile           = if ($env:CLEANUP_LOG) { $env:CLEANUP_LOG } else { "$DeliveryDir\cleanup.log" }

if (-not (Test-Path $DeliveryDir)) {
    Write-Host "ERROR: DELIVERY_DIR does not exist: $DeliveryDir"
    exit 1
}

Write-Host "Starting File Cleanup Service..."
Write-Host "Monitoring: $DeliveryDir"
Write-Host "TTL (hours): $TTLHours"
Write-Host "Check interval (minutes): $CheckIntervalMin"
Write-Host "Log file: $LogFile"

# -------------------------------
# Code
# -------------------------------
while ($true) {
    try {
        $now = Get-Date
        $cutoff = $now.AddHours(-$TTLHours)

        $filesToDelete = Get-ChildItem -Path $DeliveryDir -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $cutoff }
        foreach ($file in $filesToDelete) {
            try {
                Remove-Item $file.FullName -Force -ErrorAction Stop
                $msg = "$($now): Deleted $($file.FullName) (LastWriteTime: $($file.LastWriteTime))"
                Add-Content -Path $LogFile -Value $msg
            } catch {
                $msg = "$($now): ERROR deleting $($file.FullName): $_"
                Add-Content -Path $LogFile -Value $msg
            }
        }
    } catch {
        $msg = "$($now): ERROR during cleanup loop: $_"
        Add-Content -Path $LogFile -Value $msg
    }
    Start-Sleep -Seconds ($CheckIntervalMin * 60)
}
