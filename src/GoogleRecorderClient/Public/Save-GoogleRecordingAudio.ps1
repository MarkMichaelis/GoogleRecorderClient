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

    .EXAMPLE
        Save-GoogleRecordingAudio -RecordingId 'de3d94a9-...' -OutputPath './audio.m4a'

    .EXAMPLE
        Save-GoogleRecordingAudio -RecordingId 'de3d94a9-...' -OutputPath './downloads/'
        # Saves as ./downloads/de3d94a9-....m4a

    .EXAMPLE
        Get-GoogleRecording -First 1 | Save-GoogleRecordingAudio -OutputPath './downloads/'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$RecordingId,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    process {
        if (-not $script:RecorderSession) {
            throw 'Not connected to Google Recorder. Run Connect-GoogleRecorder first.'
        }

        $session  = $script:RecorderSession
        $filePath = Resolve-AudioOutputPath -OutputPath $OutputPath -RecordingId $RecordingId
        $headers  = Build-AudioDownloadHeaders -Session $session

        $url = "https://usercontent.recorder.google.com/download/playback/$RecordingId"
        $webSession = New-RecorderWebSession -CookieHeader $session.CookieHeader

        Invoke-WebRequest -Uri $url -Method GET `
            -Headers $headers -WebSession $webSession `
            -OutFile $filePath -UseBasicParsing
    }
}

function Resolve-AudioOutputPath {
    <#
    .SYNOPSIS
        Resolves the output file path for an audio download.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$OutputPath,
        [Parameter(Mandatory)][string]$RecordingId
    )

    if (Test-Path -Path $OutputPath -PathType Container) {
        return Join-Path $OutputPath "$RecordingId.m4a"
    }
    return $OutputPath
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
