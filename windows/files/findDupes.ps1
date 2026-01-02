# Sample Execution
# Find-DuplicateFiles -Path "D:\app\data"
function Find-DuplicateFiles {
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    Get-ChildItem -Path $Path -File -Recurse |
        Group-Object {
            Get-FileHash $_.FullName -Algorithm SHA256 | Select-Object -ExpandProperty Hash
        } |
        Where-Object { $_.Count -gt 1 } |
        ForEach-Object {
            [PSCustomObject]@{
                Hash  = $_.Name
                Files = $_.Group.FullName
            }
        }
}
