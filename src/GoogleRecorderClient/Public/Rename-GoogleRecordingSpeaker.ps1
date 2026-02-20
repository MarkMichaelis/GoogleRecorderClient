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
            $targetId = $rec.RecordingId

            if (-not $PSCmdlet.ShouldProcess("Recording '$targetId'", "Rename speaker $SpeakerId to '$NewName'")) {
                continue
            }

            Invoke-EditingSessionAction -RecordingId $targetId -Action {
                param($SessionId)

                $renameBody = "[`"$SessionId`",[[[$SpeakerId],`"$NewName`"]]]"
                Invoke-EditingRpc -Method 'RenameSpeaker' -Body $renameBody
            }
        }
    }
}
