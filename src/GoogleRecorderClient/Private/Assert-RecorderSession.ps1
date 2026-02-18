function Assert-RecorderSession {
    <#
    .SYNOPSIS
        Ensures a valid Google Recorder session is available.

    .DESCRIPTION
        If no in-memory session exists, attempts to restore one from cached
        credentials via Connect-GoogleRecorder (no browser, no user prompt).
        Throws if no session can be established.

        This is an internal helper called at the start of every public
        function that requires authentication.
    #>
    [CmdletBinding()]
    param()

    if ($script:RecorderSession) {
        return
    }

    # Try to restore from cache silently (Connect-GoogleRecorder checks
    # the cache file first and only launches a browser if the cache is
    # missing or expired).
    $cacheFile = Join-Path $script:ModuleRoot 'recorder-session.json'
    if (Test-Path $cacheFile) {
        try {
            Connect-GoogleRecorder -ErrorAction Stop
            if ($script:RecorderSession) {
                return
            }
        }
        catch {
            Write-Verbose "Auto-connect from cache failed: $_"
        }
    }

    throw 'Not connected to Google Recorder. Run Connect-GoogleRecorder first.'
}
