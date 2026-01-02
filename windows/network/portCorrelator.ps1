# Sample Execution
# Get-PortProcess -Port 8080
function Get-PortProcess {
    param (
        [int]$Port
    )

    $connections = Get-NetTCPConnection -ErrorAction SilentlyContinue |
        Where-Object { !$Port -or $_.LocalPort -eq $Port }

    $connections | ForEach-Object {
        $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            LocalAddress  = "$($_.LocalAddress):$($_.LocalPort)"
            RemoteAddress = "$($_.RemoteAddress):$($_.RemotePort)"
            State         = $_.State
            PID           = $_.OwningProcess
            Process       = $proc.ProcessName
        }
    } | Sort-Object LocalAddress
}
