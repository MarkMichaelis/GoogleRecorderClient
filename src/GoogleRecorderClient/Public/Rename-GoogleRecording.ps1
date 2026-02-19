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

    .EXAMPLE
        Get-GoogleRecording -First 1 | Rename-GoogleRecording -NewTitle 'Updated Title'
        # Pipes a recording object and renames it.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$RecordingId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$NewTitle
    )

    process {
        Assert-RecorderSession

        if ($PSCmdlet.ShouldProcess("Recording '$RecordingId'", "Rename to '$NewTitle'")) {
            $body = "[`"$RecordingId`",`"$NewTitle`"]"
            Invoke-RecorderRpc -Method 'UpdateRecordingTitle' -Body $body
        }
    }
}
