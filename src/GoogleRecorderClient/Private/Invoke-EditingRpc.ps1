function Invoke-EditingRpc {
    <#
    .SYNOPSIS
        Calls the Recorder EditingService gRPC-Web API.

    .DESCRIPTION
        Thin wrapper over Invoke-RecorderRpc that fixes the -Service parameter
        to EditingService so callers do not repeat it.

    .PARAMETER Method
        The EditingService RPC method name.

    .PARAMETER Body
        The JSON request body string.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$Body
    )

    Invoke-RecorderRpc -Service 'EditingService' -Method $Method -Body $Body
}
