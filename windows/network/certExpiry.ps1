# Sample Execution
# Get-CertificateExpiry -DaysThreshold 90
function Get-CertificateExpiry {
    param (
        [int]$DaysThreshold = 30
    )

    Get-ChildItem Cert:\LocalMachine\My |
        Where-Object {
            $_.NotAfter -lt (Get-Date).AddDays($DaysThreshold)
        } |
        Select-Object Subject, Issuer, NotAfter, Thumbprint |
        Sort-Object NotAfter
}
