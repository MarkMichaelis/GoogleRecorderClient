function Format-RecorderDuration {
    <#
    .SYNOPSIS
        Formats a proto duration array [seconds_str, nanos] as mm:ss or hh:mm:ss.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object]$Duration
    )

    $totalSeconds = [int]$Duration[0]
    $ts = [TimeSpan]::FromSeconds($totalSeconds)

    if ($ts.TotalHours -ge 1) {
        return $ts.ToString('hh\:mm\:ss')
    }
    return $ts.ToString('mm\:ss')
}
