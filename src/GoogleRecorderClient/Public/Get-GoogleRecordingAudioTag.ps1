function Get-GoogleRecordingAudioTag {
    <#
    .SYNOPSIS
        Retrieves the speaker-activity timeline for a Google Recorder recording.

    .DESCRIPTION
        Calls the GetAudioTag API to fetch speaker activity data with
        amplitude values at specific timestamps. Each entry shows which
        speaker is active at a given time and the audio amplitude.

        Requires an active session — run Connect-GoogleRecorder first.

    .PARAMETER RecordingId
        The UUID of the recording to get audio tags for.

    .EXAMPLE
        Get-GoogleRecordingAudioTag -RecordingId 'de3d94a9-...'

    .PARAMETER Title
        A title or wildcard pattern to resolve recordings by name. Alias: Name.

    .EXAMPLE
        Get-GoogleRecording -First 1 | Get-GoogleRecordingAudioTag

    .EXAMPLE
        Get-GoogleRecordingAudioTag 'My Meeting'
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
            Get-GoogleRecordingAudioTag -RecordingId $rec.RecordingId
        }
        return
    }

    $body   = "[`"$RecordingId`"]"
    $result = Invoke-RecorderRpc -Method 'GetAudioTag' -Body $body

    if (-not $result -or -not $result[0]) {
        return
    }

    foreach ($tuple in $result[0]) {
        [PSCustomObject]@{
            PSTypeName  = 'GoogleRecorder.AudioTag'
            SpeakerId   = [int]$tuple[0]
            TimestampMs = [int]$tuple[1]
            Amplitude   = [double]$tuple[2]
        }
    }
    }
}
