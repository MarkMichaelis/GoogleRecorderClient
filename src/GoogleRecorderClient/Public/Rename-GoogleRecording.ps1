function Rename-GoogleRecording {
    <#
    .SYNOPSIS
        Renames a Google Recorder recording.

    .DESCRIPTION
        Calls the UpdateRecordingTitle API to change the title of a recording.
        This is a mutating operation — use -WhatIf or -Confirm for safety.

        Requires an active session — run Connect-GoogleRecorder first.

    .PARAMETER RecordingId
        The UUID of the recording to rename.

    .PARAMETER NewTitle
        The new title for the recording.

    .EXAMPLE
        Rename-GoogleRecording -RecordingId 'de3d94a9-...' -NewTitle 'My Recording'

    .PARAMETER Title
        A title or wildcard pattern to resolve recordings by name. Alias: Name.

    .EXAMPLE
        Get-GoogleRecording -First 1 | Rename-GoogleRecording -NewTitle 'Updated Title'
        # Pipes a recording object and renames it.

    .EXAMPLE
        Rename-GoogleRecording 'Old Title' -NewTitle 'New Title'
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
        [string]$NewTitle
    )

    process {
        Assert-RecorderSession

        if ($PSCmdlet.ParameterSetName -eq 'ByTitle') {
            $resolved = Resolve-RecordingByTitle -Title $Title
            foreach ($rec in $resolved) {
                Rename-GoogleRecording -RecordingId $rec.RecordingId -NewTitle $NewTitle
            }
            return
        }

        if ($PSCmdlet.ShouldProcess("Recording '$RecordingId'", "Rename to '$NewTitle'")) {
            $body = "[`"$RecordingId`",`"$NewTitle`"]"
            Invoke-RecorderRpc -Method 'UpdateRecordingTitle' -Body $body
        }
    }
}
