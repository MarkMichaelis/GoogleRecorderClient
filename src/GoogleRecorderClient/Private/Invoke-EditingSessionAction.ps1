function Invoke-EditingSessionAction {
    <#
    .SYNOPSIS
        Manages the EditingService session lifecycle for a single action.

    .DESCRIPTION
        Opens an editing session, executes the provided action scriptblock,
        saves changes, and closes the session. CloseSession runs in a finally
        block to ensure cleanup even on error.

    .PARAMETER RecordingId
        The UUID of the recording to edit.

    .PARAMETER Action
        A scriptblock that receives the session ID as its first parameter.
        It should perform the editing operation and return any result.

    .OUTPUTS
        The return value of the Action scriptblock.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RecordingId,

        [Parameter(Mandatory)]
        [scriptblock]$Action
    )

    $recording = Get-GoogleRecording -RecordingId $RecordingId
    $recordingTitle = $recording.Title

    $sessionId = $null
    try {
        $openResult = Invoke-EditingRpc -Method 'OpenSession' -Body "[`"$RecordingId`"]"
        $sessionId = @($openResult)[0]

        $result = & $Action $sessionId

        $saveBody = "[`"$sessionId`",[[[`"$recordingTitle`"]],[`"$RecordingId`"]]]"
        $null = Invoke-EditingRpc -Method 'SaveAudio' -Body $saveBody

        return ,$result
    }
    finally {
        if ($sessionId) {
            $null = Invoke-EditingRpc -Method 'CloseSession' -Body "[`"$sessionId`"]"
        }
    }
}
