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
    [CmdletBinding(DefaultParameterSetName = 'ById')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById', ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$RecordingId,

        [Parameter(Mandatory, ParameterSetName = 'ByTitle', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [SupportsWildcards()]
        [string]$Title
    )

    process {
    Assert-RecorderSession

    if ($PSCmdlet.ParameterSetName -eq 'ByTitle') {
        $resolved = Resolve-RecordingByTitle -Title $Title
        foreach ($rec in $resolved) {
            Get-GoogleRecordingShare -RecordingId $rec.RecordingId
        }
        return
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
}
