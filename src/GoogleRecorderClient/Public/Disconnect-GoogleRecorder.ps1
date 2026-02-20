function Disconnect-GoogleRecorder {
    <#
    .SYNOPSIS
        Clears the current Google Recorder session.

    .DESCRIPTION
        Removes the in-memory session and deletes the cached session file on
        disk so that subsequent commands require a fresh Connect-GoogleRecorder.

    .EXAMPLE
        Disconnect-GoogleRecorder
        # Clears session and deletes the cache file.
    #>
    [CmdletBinding()]
    param()

    $script:RecorderSession = $null

    $cacheFile = Join-Path $script:ModuleRoot 'recorder-session.json'
    if (Test-Path $cacheFile) {
        Remove-Item -Path $cacheFile -Force
        Write-Verbose "Removed session cache: $cacheFile"
    }

    Write-Information 'Disconnected from Google Recorder.' -InformationAction Continue
}
