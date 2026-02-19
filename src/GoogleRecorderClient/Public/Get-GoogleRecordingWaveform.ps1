function Get-GoogleRecordingWaveform {
    <#
    .SYNOPSIS
        Retrieves waveform amplitude data for a Google Recorder recording.

    .DESCRIPTION
        Calls the GetWaveform API to fetch amplitude samples for a specific
        recording. Returns a waveform object containing an array of float
        amplitude values.

        Requires an active session — run Connect-GoogleRecorder first.

    .PARAMETER RecordingId
        The UUID of the recording to get waveform data for.

    .EXAMPLE
        Get-GoogleRecordingWaveform -RecordingId 'de3d94a9-...'
        # Returns a waveform object with amplitude samples.

    .EXAMPLE
        Get-GoogleRecording -First 1 | Get-GoogleRecordingWaveform
        # Pipes a recording to get its waveform data.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$RecordingId
    )

    process {
    Assert-RecorderSession

    $body   = "[`"$RecordingId`"]"
    $result = Invoke-RecorderRpc -Method 'GetWaveform' -Body $body

    [PSCustomObject]@{
        PSTypeName  = 'GoogleRecorder.Waveform'
        RecordingId = $RecordingId
        Samples     = $result[0][0]
    }
    }
}
