function Get-GoogleRecorderLabel {
    <#
    .SYNOPSIS
        Retrieves all available labels/tags for the user's recordings.

    .DESCRIPTION
        Calls the ListLabels API to fetch all label definitions available
        in the user's Google Recorder account.

        Requires an active session — run Connect-GoogleRecorder first.

    .EXAMPLE
        Get-GoogleRecorderLabel
        # Lists all available labels.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    if (-not $script:RecorderSession) {
        throw 'Not connected to Google Recorder. Run Connect-GoogleRecorder first.'
    }

    $result = Invoke-RecorderRpc -Method 'ListLabels' -Body '[]'

    if (-not $result -or -not $result[0]) {
        return
    }

    foreach ($labelArray in $result[0]) {
        [PSCustomObject]@{
            PSTypeName = 'GoogleRecorder.Label'
            Id         = $labelArray[0]
            Name       = $labelArray[1]
        }
    }
}
