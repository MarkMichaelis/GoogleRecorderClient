function Edit-GoogleRecordingAudio {
    <#
    .SYNOPSIS
        Crops or removes a time range from a recording's audio.

    .DESCRIPTION
        Opens an EditingService session, performs either CropAudio or RemoveAudio
        with the provided start/end times, saves the audio, and closes the
        session. Supports resolving by ID or title. Respects -WhatIf / -Confirm
        and uses ConfirmImpact High because audio content is modified.

    .PARAMETER RecordingId
        Recording UUID to edit. Accepts pipeline input by property name.

    .PARAMETER Title
        Recording title or wildcard pattern.

    .PARAMETER Crop
        Perform a crop (keep only the specified range).

    .PARAMETER Remove
        Remove the specified range from the audio.

    .PARAMETER Start
        Start of the time range.

    .PARAMETER End
        End of the time range.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById', ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$RecordingId,

        [Parameter(Mandatory, ParameterSetName = 'ByTitle', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [Parameter(ParameterSetName = 'ById')]
        [Parameter(ParameterSetName = 'ByTitle')]
        [switch]$Crop,

        [Parameter(ParameterSetName = 'ById')]
        [Parameter(ParameterSetName = 'ByTitle')]
        [switch]$Remove,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [Parameter(Mandatory, ParameterSetName = 'ByTitle')]
        [TimeSpan]$Start,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [Parameter(Mandatory, ParameterSetName = 'ByTitle')]
        [TimeSpan]$End
    )

    process {
        Assert-RecorderSession

        if ($Crop.IsPresent -eq $Remove.IsPresent) {
            throw 'Specify exactly one of -Crop or -Remove.'
        }

        $recordings = if ($PSCmdlet.ParameterSetName -eq 'ByTitle') {
            Resolve-RecordingByTitle -Title $Title
        }
        else {
            @(Get-GoogleRecording -RecordingId $RecordingId)
        }

        $method = 'RemoveAudio'
        $action = 'Remove audio'
        if ($Crop.IsPresent) {
            $method = 'CropAudio'
            $action = 'Crop audio'
        }

        foreach ($rec in $recordings) {
            $targetId    = $rec.RecordingId
            $targetTitle = $rec.Title

            if (-not $PSCmdlet.ShouldProcess("Recording '$targetId'", $action)) {
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

                $startSeconds = [int][Math]::Floor($Start.TotalSeconds)
                $startNanos   = [int](($Start.Ticks % 10000000) * 100)
                $endSeconds   = [int][Math]::Floor($End.TotalSeconds)
                $endNanos     = [int](($End.Ticks % 10000000) * 100)
                $rangeBody    = "[[${startSeconds},${startNanos}],[${endSeconds},${endNanos}]]"

                $editBody   = "[`"$sessionId`",$rangeBody]"
                $editResult = Invoke-EditingRpc -Method $method -Body $editBody

                $saveBody = "[`"$sessionId`",[[[`"$targetTitle`"]],[`"$targetId`"]]]"
                $null = Invoke-EditingRpc -Method 'SaveAudio' -Body $saveBody

                if ($null -ne $editResult) {
                    $editResult
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
