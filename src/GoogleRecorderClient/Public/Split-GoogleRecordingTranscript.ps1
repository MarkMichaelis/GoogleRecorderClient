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
            $targetId    = $rec.RecordingId
            $targetTitle = $rec.Title

            if (-not $PSCmdlet.ShouldProcess("Recording '$targetId'", 'Split transcript')) {
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

                $positionList = ($Position -join ',')
                $splitBody = "[`"$($sessionId)`",[$positionList]]"
                $splitResult = Invoke-EditingRpc -Method 'SplitTranscription' -Body $splitBody

                $saveBody = "[`"$($sessionId)`",[[[`"$targetTitle`"]],[`"$targetId`"]]]"
                $null = Invoke-EditingRpc -Method 'SaveAudio' -Body $saveBody

                if ($null -ne $splitResult) {
                    $splitResult
                }
            }
            finally {
                if ($sessionId) {
                    $closeBody = "[`"$($sessionId)`"]"
                    $null = Invoke-EditingRpc -Method 'CloseSession' -Body $closeBody
                }
            }
        }
    }
}
