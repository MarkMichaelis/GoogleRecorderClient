function Save-GoogleRecordingAudio {
    <#
    .SYNOPSIS
        Downloads the audio file for a Google Recorder recording.

    .DESCRIPTION
        Fetches the audio data from the Google Recorder content server
        and saves it to the specified path. If OutputPath is a directory,
        the file is saved as "{RecordingId}.m4a".

        Requires an active session — run Connect-GoogleRecorder first.

    .PARAMETER RecordingId
        The UUID of the recording to download audio for.

    .PARAMETER OutputPath
        File path or directory to save the audio. If a directory, the
        filename defaults to "{RecordingId}.m4a".

    .PARAMETER Title
        A title or wildcard pattern to resolve recordings by name. Alias: Name.

    .PARAMETER Force
        Overwrite the output file if it already exists.

    .EXAMPLE
        Save-GoogleRecordingAudio -RecordingId 'de3d94a9-...' -OutputPath './audio.m4a'

    .EXAMPLE
        Save-GoogleRecordingAudio -RecordingId 'de3d94a9-...' -OutputPath './downloads/'
        # Saves as ./downloads/de3d94a9-....m4a

    .EXAMPLE
        Get-GoogleRecording -First 1 | Save-GoogleRecordingAudio -OutputPath './downloads/'

    .EXAMPLE
        Save-GoogleRecordingAudio 'My Meeting' -OutputPath './downloads/'
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById', ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$RecordingId,

        [Parameter(Mandatory, ParameterSetName = 'ByTitle', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [SupportsWildcards()]
        [string]$Title,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [switch]$Force
    )

    process {
        Assert-RecorderSession

        if ($PSCmdlet.ParameterSetName -eq 'ByTitle') {
            $resolved = Resolve-RecordingByTitle -Title $Title
            foreach ($rec in $resolved) {
                $params = @{ RecordingId = $rec.RecordingId; OutputPath = $OutputPath }
                if ($Force) { $params['Force'] = $true }
                Save-GoogleRecordingAudio @params
            }
            return
        }

        $session     = $script:RecorderSession
        $resolvedOut = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($OutputPath)
        $filePath    = Resolve-OutputFilePath -OutputPath $resolvedOut -BaseName $RecordingId -Extension '.m4a' -Force:$Force
        $headers     = Build-AudioDownloadHeaders -Session $session

        if ($PSCmdlet.ShouldProcess($filePath, 'Download audio file')) {
            $url = "https://usercontent.recorder.google.com/download/playback/$RecordingId"
            $webSession = New-RecorderWebSession -CookieHeader $session.CookieHeader

            Invoke-WebRequest -Uri $url -Method GET `
                -Headers $headers -WebSession $webSession `
                -OutFile $filePath -UseBasicParsing
        }
    }
}

function Build-AudioDownloadHeaders {
    <#
    .SYNOPSIS
        Builds HTTP headers for the audio download request.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Session
    )

    $recorderBase = 'https://recorder.google.com'

    $sapisId = $null
    foreach ($pair in $Session.CookieHeader.Split(';')) {
        $trimmed = $pair.Trim()
        if ($trimmed -match '^SAPISID=(.+)$') {
            $sapisId = $Matches[1]
            break
        }
    }
    if (-not $sapisId) {
        throw 'SAPISID cookie not found in session. Re-authenticate with Connect-GoogleRecorder.'
    }

    $authToken = Get-SapisIdHash -SapisId $sapisId -Origin $recorderBase

    return @{
        'Origin'          = $recorderBase
        'Referer'         = "$recorderBase/"
        'Authorization'   = $authToken
        'x-goog-api-key'  = $Session.ApiKey
        'x-goog-authuser' = '0'
    }
}
