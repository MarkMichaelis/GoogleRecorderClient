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

    .EXAMPLE
        Get-GoogleRecording -First 1 | Get-GoogleRecordingAudioTag
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
