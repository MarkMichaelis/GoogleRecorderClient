function Split-GoogleRecordingTranscript {
    <#
    .SYNOPSIS
        Splits a transcript segment at the specified position.

    .DESCRIPTION
        Opens an EditingService session, calls SplitTranscription with the
        provided position array, saves the audio, and closes the session.
        Supports resolving recordings by ID or title. Respects -WhatIf.

    .PARAMETER RecordingId
        Recording UUID to edit. Accepts pipeline input by property name.

    .PARAMETER Title
        Recording title or wildcard pattern. Alias: Name.

    .PARAMETER Position
        Transcript split position (segment/word indices).
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

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [Parameter(Mandatory, ParameterSetName = 'ByTitle')]
        [int[]]$Position
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

            if (-not $PSCmdlet.ShouldProcess("Recording '$targetId'", 'Split transcript')) {
                continue
            }

            Invoke-EditingSessionAction -RecordingId $targetId -Action {
                param($SessionId)

                $positionList = ($Position -join ',')
                $splitBody = "[`"$SessionId`",[$positionList]]"
                Invoke-EditingRpc -Method 'SplitTranscription' -Body $splitBody
            }
        }
    }
}
