function Set-GoogleRecordingSpeaker {
    <#
    .SYNOPSIS
        Reassigns transcript segments to a target speaker (existing or new).

    .DESCRIPTION
        Opens an EditingService session, calls SwitchSpeaker, saves the audio,
        and closes the session. Supports resolving recordings by ID or title,
        and either choosing an existing speaker ID or creating a new speaker
        name. Respects -WhatIf / -Confirm.

    .PARAMETER RecordingId
        Recording UUID to edit. Accepts pipeline input by property name.

    .PARAMETER Title
        Recording title or wildcard pattern. Alias: Name.

    .PARAMETER SegmentIndex
        Transcript segment indices to reassign.

    .PARAMETER TargetSpeakerId
        Existing speaker number to assign the segments to.

    .PARAMETER TargetSpeakerName
        Display name for a new speaker to create and assign.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByIdExisting')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByIdExisting', ValueFromPipelineByPropertyName)]
        [Parameter(Mandatory, ParameterSetName = 'ByIdNew', ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$RecordingId,

        [Parameter(Mandatory, ParameterSetName = 'ByTitleExisting', Position = 0)]
        [Parameter(Mandatory, ParameterSetName = 'ByTitleNew', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [SupportsWildcards()]
        [string]$Title,

        [Parameter(Mandatory, ParameterSetName = 'ByIdExisting')]
        [Parameter(Mandatory, ParameterSetName = 'ByTitleExisting')]
        [Parameter(Mandatory, ParameterSetName = 'ByIdNew')]
        [Parameter(Mandatory, ParameterSetName = 'ByTitleNew')]
        [int[]]$SegmentIndex,

        [Parameter(Mandatory, ParameterSetName = 'ByIdExisting')]
        [Parameter(Mandatory, ParameterSetName = 'ByTitleExisting')]
        [int]$TargetSpeakerId,

        [Parameter(Mandatory, ParameterSetName = 'ByIdNew')]
        [Parameter(Mandatory, ParameterSetName = 'ByTitleNew')]
        [ValidateNotNullOrEmpty()]
        [string]$TargetSpeakerName
    )

    process {
        Assert-RecorderSession

        $recordings = @()
        if ($PSCmdlet.ParameterSetName -like 'ByTitle*') {
            $recordings = Resolve-RecordingByTitle -Title $Title
        }
        else {
            $recordings = @(Get-GoogleRecording -RecordingId $RecordingId)
        }

        foreach ($rec in $recordings) {
            $targetId = $rec.RecordingId

            if (-not $PSCmdlet.ShouldProcess("Recording '$targetId'", 'Switch speaker assignment')) {
                continue
            }

            $segmentList = ($SegmentIndex -join ',')
            if ($PSCmdlet.ParameterSetName -like '*Existing') {
                $targetPayload = "[[${TargetSpeakerId}]]"
            }
            else {
                $targetPayload = "[`"$TargetSpeakerName`"]"
            }

            Invoke-EditingSessionAction -RecordingId $targetId -Action {
                param($SessionId)

                $switchBody = "[`"$SessionId`",[$segmentList],$targetPayload]"
                Invoke-EditingRpc -Method 'SwitchSpeaker' -Body $switchBody
            }
        }
    }
}
