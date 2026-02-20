function Test-GoogleRecorderSearch {
    <#
    .SYNOPSIS
        Tests whether global search is available for the user's recordings.

    .DESCRIPTION
        Calls the GetGlobalSearchReadiness API to determine if the global
        search feature is ready for the authenticated user's account.

        Requires an active session — run Connect-GoogleRecorder first.

    .EXAMPLE
        Test-GoogleRecorderSearch
        # Returns $true if search is ready, $false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not $script:RecorderSession) {
        throw 'Not connected to Google Recorder. Run Connect-GoogleRecorder first.'
    }

    $result = Invoke-RecorderRpc -Method 'GetGlobalSearchReadiness' -Body '[]'

    return ($null -ne $result -and $result.Count -gt 0 -and $result[0] -eq 1)
}
