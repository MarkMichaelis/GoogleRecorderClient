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

    .PARAMETER Title
        A title or wildcard pattern to resolve recordings by name. Alias: Name.

    .EXAMPLE
        Get-GoogleRecording -First 1 | Get-GoogleRecordingWaveform
        # Pipes a recording to get its waveform data.

    .EXAMPLE
        Get-GoogleRecordingWaveform 'My Meeting'
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
            Get-GoogleRecordingWaveform -RecordingId $rec.RecordingId
        }
        return
    }

    $body   = "[`"$RecordingId`"]"
    $result = Invoke-RecorderRpc -Method 'GetWaveform' -Body $body

    [PSCustomObject]@{
        PSTypeName  = 'GoogleRecorder.Waveform'
        RecordingId = $RecordingId
        Samples     = $result[0][0]
    }
    }
}
