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

    .PARAMETER Title
        A title or wildcard pattern to resolve recordings by name. Alias: Name.

    .PARAMETER AsText
        Return the transcript as a single plain text string instead of word objects.

    .PARAMETER OutputPath
        File path or directory to save the transcript. If a directory, the
        filename defaults to "{RecordingId}.txt". Implies -AsText.

    .PARAMETER Force
        Overwrite the output file if it already exists.

    .EXAMPLE
        Get-GoogleRecordingTranscript -RecordingId 'de3d94a9-...'
        # Returns word objects with timing and speaker info.

    .EXAMPLE
        Get-GoogleRecordingTranscript -RecordingId 'de3d94a9-...' -AsText
        # Returns the transcript as plain text.

    .EXAMPLE
        Get-GoogleRecording -First 1 | Get-GoogleRecordingTranscript -AsText
        # Pipes a recording to get its transcript as text.

    .EXAMPLE
        Get-GoogleRecordingTranscript 'My Meeting' -AsText

    .EXAMPLE
        Get-GoogleRecordingTranscript -RecordingId 'de3d94a9-...' -OutputPath './transcripts/'
        # Saves the transcript to a text file.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ById')]
    [OutputType([PSCustomObject], [string])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById', ValueFromPipelineByPropertyName)]
        [Parameter(Mandatory, ParameterSetName = 'ByIdSave', ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$RecordingId,

        [Parameter(Mandatory, ParameterSetName = 'ByTitle', Position = 0)]
        [Parameter(Mandatory, ParameterSetName = 'ByTitleSave', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [SupportsWildcards()]
        [string]$Title,

        [Parameter(ParameterSetName = 'ById')]
        [Parameter(ParameterSetName = 'ByTitle')]
        [switch]$AsText,

        [Parameter(Mandatory, ParameterSetName = 'ByIdSave')]
        [Parameter(Mandatory, ParameterSetName = 'ByTitleSave')]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter(ParameterSetName = 'ByIdSave')]
        [Parameter(ParameterSetName = 'ByTitleSave')]
        [switch]$Force
    )

    process {
    Assert-RecorderSession

    if ($PSCmdlet.ParameterSetName -in 'ByTitle', 'ByTitleSave') {
        $resolved = Resolve-RecordingByTitle -Title $Title
        foreach ($rec in $resolved) {
            $params = @{ RecordingId = $rec.RecordingId }
            if ($OutputPath) {
                $params['OutputPath'] = $OutputPath
                if ($Force) { $params['Force'] = $true }
            }
            elseif ($AsText) { $params['AsText'] = $true }
            Get-GoogleRecordingTranscript @params
        }
        return
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

    if ($OutputPath) {
        $text        = ($words | ForEach-Object { $_.Word }) -join ' '
        $resolvedOut = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($OutputPath)
        $filePath    = Resolve-OutputFilePath -OutputPath $resolvedOut -BaseName $RecordingId -Extension '.txt' -Force:$Force
        if ($PSCmdlet.ShouldProcess($filePath, 'Save transcript')) {
            Set-Content -Path $filePath -Value $text -Encoding utf8
        }
        return
    }

    if ($AsText) {
        return ($words | ForEach-Object { $_.Word }) -join ' '
    }

    return $words
    }
}


