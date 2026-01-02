#Sample Execution
# Search-Logs -SearchTerm "random" -LogPath "D:\app\logs"
function Search-Logs {
    [CmdletBinding()]
    param (
        # Required
        [Parameter(Mandatory)]
        [string]$SearchTerm,

        [Parameter(Mandatory)]
        [string]$LogPath,

        # Optional filters
        [datetime]$StartDate,
        [datetime]$EndDate,

        [string[]]$IncludeExtensions = @('.log', '.txt'),

        # Output
        [string]$OutputDirectory = "$env:USERPROFILE\Desktop",
        [string]$BaseFileName = 'log_search_results',

        # Performance
        [int]$ThrottleLimit = 8,

        # Behavior
        [switch]$Recursive,
        [switch]$CaseSensitive,
        [switch]$ShowMatchesInConsole
    )

    # -------------------------------
    # Setup
    # -------------------------------
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $txtOutput = Join-Path $OutputDirectory "$BaseFileName_$timestamp.txt"
    $csvOutput = Join-Path $OutputDirectory "$BaseFileName_$timestamp.csv"

    Write-Host "`nStarting log search..." -ForegroundColor Cyan
    Write-Host "Path:        $LogPath"
    Write-Host "Search term: $SearchTerm"
    Write-Host "Output:      $txtOutput`n"

    # -------------------------------
    # File Discovery
    # -------------------------------
    $files = Get-ChildItem -Path $LogPath `
        -File `
        -Recurse:$Recursive `
        -ErrorAction SilentlyContinue |
        Where-Object {
            (!$IncludeExtensions -or $IncludeExtensions -contains $_.Extension.ToLower()) -and
            (!$StartDate -or $_.CreationTime -ge $StartDate) -and
            (!$EndDate -or $_.CreationTime -le $EndDate)
        }

    if (-not $files) {
        Write-Warning "No files matched the criteria."
        return
    }

    # -------------------------------
    # Search (Parallel)
    # -------------------------------
    $results = $files | ForEach-Object -Parallel {
        param ($SearchTerm, $CaseSensitive)

        try {
            Select-String `
                -Path $_.FullName `
                -Pattern $SearchTerm `
                -CaseSensitive:$CaseSensitive `
                -ErrorAction SilentlyContinue |
            ForEach-Object {
                [PSCustomObject]@{
                    Timestamp  = Get-Date
                    File       = $_.Path
                    LineNumber = $_.LineNumber
                    Match      = $_.Line.Trim()
                }
            }
        } catch {
            $null
        }

    } -ThrottleLimit $ThrottleLimit -ArgumentList $SearchTerm, $CaseSensitive

    if (-not $results) {
        Write-Host "No matches found." -ForegroundColor Yellow
        return
    }

    # -------------------------------
    # Output (Text)
    # -------------------------------
    $results |
        Sort-Object File, LineNumber |
        ForEach-Object {
            "[{0}] {1}:{2} :: {3}" -f `
                $_.Timestamp, $_.File, $_.LineNumber, $_.Match
        } |
        Out-File -FilePath $txtOutput -Encoding UTF8

    # -------------------------------
    # Output (CSV)
    # -------------------------------
    $results |
        Export-Csv -Path $csvOutput -NoTypeInformation

    # -------------------------------
    # Console Output
    # -------------------------------
    if ($ShowMatchesInConsole) {
        $results | ForEach-Object {
            Write-Host "$($_.File):$($_.LineNumber)" -ForegroundColor DarkGray
            Write-Host "  $($_.Match)" -ForegroundColor Green
        }
    }

    # -------------------------------
    # Open Results
    # -------------------------------
    notepad $txtOutput

    Write-Host "`nSearch complete. Matches found: $($results.Count)" -ForegroundColor Green
}
