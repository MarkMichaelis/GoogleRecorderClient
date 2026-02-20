function Get-GoogleRecordingTranscript {
    <#
    .SYNOPSIS
        Retrieves the transcript for a Google Recorder recording.

    .DESCRIPTION
        Calls the GetTranscription API to fetch word-level transcript data
        for a specific recording. Returns structured word objects by default,
        or plain text with the -AsText switch.

        Requires an active session — run Connect-GoogleRecorder first.

    .PARAMETER RecordingId
        The UUID of the recording to get the transcript for.

    .PARAMETER AsText
        Return the transcript as a single plain text string instead of word objects.

    .EXAMPLE
        Get-GoogleRecordingTranscript -RecordingId 'de3d94a9-...'
        # Returns word objects with timing and speaker info.

    .EXAMPLE
        Get-GoogleRecordingTranscript -RecordingId 'de3d94a9-...' -AsText
        # Returns the transcript as plain text.

    .EXAMPLE
        Get-GoogleRecording -First 1 | Get-GoogleRecordingTranscript -AsText
        # Pipes a recording to get its transcript as text.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject], [string])]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$RecordingId,

        [switch]$AsText
    )

    if (-not $script:RecorderSession) {
        throw 'Not connected to Google Recorder. Run Connect-GoogleRecorder first.'
    }

    $body   = "[`"$RecordingId`"]"
    $result = Invoke-RecorderRpc -Method 'GetTranscription' -Body $body

    if (-not $result -or -not $result[0]) {
        Write-Warning "No transcript found for recording '$RecordingId'."
        return
    }

    $words = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($segment in $result[0]) {
        foreach ($wordGroup in $segment) {
            foreach ($entry in $wordGroup) {
                $word = [PSCustomObject]@{
                    PSTypeName = 'GoogleRecorder.TranscriptWord'
                    Word       = if ($entry[1]) { $entry[1] } else { $entry[0] }
                    RawWord    = $entry[0]
                    StartMs    = [int]$entry[2]
                    EndMs      = [int]$entry[3]
                    SpeakerId  = if ($entry[6]) { $entry[6][1] } else { $null }
                }
                $words.Add($word)
            }
        }
    }

    if ($AsText) {
        return ($words | ForEach-Object { $_.Word }) -join ' '
    }

    return $words
}
