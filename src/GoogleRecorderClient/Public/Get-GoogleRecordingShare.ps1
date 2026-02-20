function Get-GoogleRecordingShare {
    <#
    .SYNOPSIS
        Retrieves the share list for a Google Recorder recording.

    .DESCRIPTION
        Calls the GetShareList API to fetch sharing information for a specific
        recording. Returns share objects with Email and Role properties.

        Requires an active session — run Connect-GoogleRecorder first.

    .PARAMETER RecordingId
        The UUID of the recording to get shares for.

    .EXAMPLE
        Get-GoogleRecordingShare -RecordingId 'de3d94a9-...'
        # Returns share objects for the recording.

    .EXAMPLE
        Get-GoogleRecording -First 1 | Get-GoogleRecordingShare
        # Pipes a recording to get its share list.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$RecordingId
    )

    if (-not $script:RecorderSession) {
        throw 'Not connected to Google Recorder. Run Connect-GoogleRecorder first.'
    }

    $body   = "[`"$RecordingId`"]"
    $result = Invoke-RecorderRpc -Method 'GetShareList' -Body $body

    if (-not $result -or $result.Count -eq 0) {
        return
    }

    foreach ($entry in $result[0]) {
        [PSCustomObject]@{
            PSTypeName = 'GoogleRecorder.Share'
            Email      = $entry[0]
            Role       = $entry[1]
        }
    }
}
