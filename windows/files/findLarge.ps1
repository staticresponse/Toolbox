# Sample Execution
# Get-LargeFiles
# Get-LargeFiles -Path "E:\" -Top 50
function Get-LargeFiles {
    param (
        [string]$Path = "C:\",
        [int]$Top = 20
    )

    Get-ChildItem -Path $Path -File -Recurse -ErrorAction SilentlyContinue |
        Sort-Object Length -Descending |
        Select-Object -First $Top |
        Select-Object @{
            Name = "SizeMB"
            Expression = { [math]::Round($_.Length / 1MB, 2) }
        }, FullName
}
