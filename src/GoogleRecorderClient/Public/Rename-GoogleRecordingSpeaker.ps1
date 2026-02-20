function Rename-GoogleRecordingSpeaker {
    <#
    .SYNOPSIS
        Renames a speaker label on a Google Recorder recording.

    .DESCRIPTION
        Opens an EditingService session for the recording, calls RenameSpeaker,
        saves the audio, and closes the session. Supports resolving recordings
        by ID or title and respects -WhatIf / -Confirm.

    .PARAMETER RecordingId
        Recording UUID to update. Accepts pipeline input by property name.

    .PARAMETER Title
        Recording title or wildcard pattern. Alias: Name.

    .PARAMETER SpeakerId
        The speaker number to rename.

    .PARAMETER NewName
        The new display name for the speaker.
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
        [int]$SpeakerId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$NewName
    )

    process {
        Assert-RecorderSession

        $recordings = @()
        if ($PSCmdlet.ParameterSetName -eq 'ByTitle') {
            $recordings = Resolve-RecordingByTitle -Title $Title
        }
        else {
            $recordings = @(Get-GoogleRecording -RecordingId $RecordingId)
        }

        foreach ($rec in $recordings) {
            $targetId    = $rec.RecordingId
            $targetTitle = $rec.Title

            if (-not $PSCmdlet.ShouldProcess("Recording '$targetId'", "Rename speaker $SpeakerId to '$NewName'")) {
                continue
            }

            $sessionId = $null
            try {
                $openBody   = "[`"$targetId`"]"
                $openResult = Invoke-EditingRpc -Method 'OpenSession' -Body $openBody
                if ($openResult -is [string]) {
                    $sessionId = $openResult
                }
                elseif ($openResult -is [System.Collections.IEnumerable]) {
                    $sessionId = ($openResult | Select-Object -First 1)
                }

                if (-not $sessionId) {
                    throw "Failed to open editing session for recording '$targetId'."
                }

                $renameBody = "[`"$($sessionId)`",[[[$SpeakerId],`"$NewName`"]]]"
                $renameResult = Invoke-EditingRpc -Method 'RenameSpeaker' -Body $renameBody

                $saveBody = "[`"$($sessionId)`",[[[`"$targetTitle`"]],[`"$targetId`"]]]"
                $null = Invoke-EditingRpc -Method 'SaveAudio' -Body $saveBody

                if ($null -ne $renameResult) {
                    $renameResult
                }
            }
            finally {
                if ($sessionId) {
                    $closeBody = "[`"$sessionId`"]"
                    $null = Invoke-EditingRpc -Method 'CloseSession' -Body $closeBody
                }
            }
        }
    }
}
