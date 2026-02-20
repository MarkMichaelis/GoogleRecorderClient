function Remove-GoogleRecording {
    <#
    .SYNOPSIS
        Deletes one or more recordings.

    .DESCRIPTION
        Calls the PlaybackService DeleteRecordingList RPC to permanently delete
        recordings. Supports deleting by recording ID or resolving by title
        (wildcard). Respects -WhatIf / -Confirm; ConfirmImpact is High.

    .PARAMETER RecordingId
        One or more recording UUIDs to delete. Accepts pipeline input by
        property name.

    .PARAMETER Title
        Recording title or wildcard pattern to resolve recordings for
        deletion.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById', ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]]$RecordingId,

        [Parameter(Mandatory, ParameterSetName = 'ByTitle', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [SupportsWildcards()]
        [string]$Title
    )

    process {
        Assert-RecorderSession

        $ids = @()

        if ($PSCmdlet.ParameterSetName -eq 'ByTitle') {
            $resolved = Resolve-RecordingByTitle -Title $Title
            $ids = @($resolved | ForEach-Object { $_.RecordingId })
        }
        else {
            $ids = @($RecordingId)
        }

        if (-not $ids -or $ids.Count -eq 0) {
            return
        }

        $payload = '[[' + (($ids | ForEach-Object { '"' + $_ + '"' }) -join ',') + ']]'

        $targetDesc = "Recording IDs: $($ids -join ', ')"
        if ($PSCmdlet.ShouldProcess($targetDesc, 'Delete recordings')) {
            Invoke-RecorderRpc -Method 'DeleteRecordingList' -Body $payload
        }
    }
}