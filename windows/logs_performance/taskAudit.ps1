# Sample Execution
# Audit-ScheduledTasks
function Audit-ScheduledTasks {
    Get-ScheduledTask |
        Where-Object {
            $_.State -ne 'Disabled'
        } |
        ForEach-Object {
            $info = Get-ScheduledTaskInfo $_
            [PSCustomObject]@{
                TaskName   = $_.TaskName
                Path       = $_.TaskPath
                State      = $_.State
                LastRun    = $info.LastRunTime
                NextRun    = $info.NextRunTime
                Action     = ($_.Actions | Select-Object -First 1).Execute
            }
        } |
        Sort-Object LastRun
}
