function Disconnect-GoogleRecorder {
    <#
    .SYNOPSIS
        Clears the current Google Recorder session.

    .DESCRIPTION
        Removes the in-memory session and optionally deletes the cached session
        file so that subsequent commands require a fresh Connect-GoogleRecorder.

    .PARAMETER RemoveCache
        Also delete the persisted session cache file on disk.

    .EXAMPLE
        Disconnect-GoogleRecorder
        # Clears in-memory session only.

    .EXAMPLE
        Disconnect-GoogleRecorder -RemoveCache
        # Clears session and deletes the cache file.
    #>
    [CmdletBinding()]
    param(
        [switch]$RemoveCache
    )

    $script:RecorderSession = $null

    if ($RemoveCache) {
        $cacheFile = Join-Path $script:ModuleRoot 'recorder-session.json'
        if (Test-Path $cacheFile) {
            Remove-Item -Path $cacheFile -Force
            Write-Verbose "Removed session cache: $cacheFile"
        }
    }

    Write-Host 'Disconnected from Google Recorder.' -ForegroundColor Yellow
}
