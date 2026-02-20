function Get-UnixTimestamp {
    <#
    .SYNOPSIS
        Returns the current UTC time as a [seconds, nanoseconds] array
        matching the Google Recorder proto timestamp format.
    #>
    [CmdletBinding()]
    [OutputType([long[]])]
    param()

    $now     = [DateTimeOffset]::UtcNow
    $seconds = $now.ToUnixTimeSeconds()
    $millis  = $now.ToUnixTimeMilliseconds()
    $nanos   = [int](($millis % 1000) * 1000000)

    return @($seconds, $nanos)
}
