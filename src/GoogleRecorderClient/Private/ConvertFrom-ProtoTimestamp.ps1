function ConvertFrom-ProtoTimestamp {
    <#
    .SYNOPSIS
        Converts a Google Recorder proto timestamp array [unix_seconds, nanos]
        to a local DateTime.
    #>
    [CmdletBinding()]
    [OutputType([datetime])]
    param(
        [Parameter(Mandatory)]
        [object]$Timestamp
    )

    $seconds = [long]$Timestamp[0]
    $epoch   = [DateTimeOffset]::FromUnixTimeSeconds($seconds)
    return $epoch.LocalDateTime
}
