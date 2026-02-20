function Invoke-RecorderRpc {
    <#
    .SYNOPSIS
        Calls a Google Recorder PlaybackService gRPC-Web method.

    .DESCRIPTION
        Sends a POST request to the Google Recorder API using the captured
        session cookies and API key. The request/response format is
        application/json+protobuf (JSON arrays mapped to protobuf fields).

    .PARAMETER Method
        The RPC method name (e.g. 'GetRecordingList', 'GetRecordingInfo').

    .PARAMETER Body
        The JSON request body string.

    .PARAMETER Service
        The Recorder gRPC service to call. Defaults to PlaybackService. Use
        EditingService for edit-session RPCs.

    .OUTPUTS
        Parsed JSON response (arrays).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$Body,

        [ValidateNotNullOrEmpty()]
        [string]$Service = 'PlaybackService'
    )

    $session = $script:RecorderSession
    if (-not $session) {
        throw 'Not connected to Google Recorder. Run Connect-GoogleRecorder first.'
    }

    $rpcPaths = @{
        'PlaybackService' = '/$rpc/java.com.google.wireless.android.pixel.recorder.protos.PlaybackService'
        'EditingService'  = '/$rpc/java.com.google.wireless.android.pixel.recorder.sharedclient.audioediting.protos.EditingService'
    }

    $rpcPathPrefix = $rpcPaths[$Service]
    if (-not $rpcPathPrefix) {
        $known = ($rpcPaths.Keys | Sort-Object) -join ', '
        throw "Unknown service '$Service'. Supported services: $known."
    }
    $contentType   = 'application/json+protobuf'
    $recorderBase  = 'https://recorder.google.com'

    $url = "$($session.BaseUrl)$rpcPathPrefix/$Method"

    # Extract SAPISID cookie for authorization hash
    $sapisId = $null
    foreach ($pair in $session.CookieHeader.Split(';')) {
        $trimmed = $pair.Trim()
        if ($trimmed -match '^SAPISID=(.+)$') {
            $sapisId = $Matches[1]
            break
        }
    }
    if (-not $sapisId) {
        throw 'SAPISID cookie not found in session. Re-authenticate with Connect-GoogleRecorder.'
    }

    $authToken  = Get-SapisIdHash -SapisId $sapisId -Origin $recorderBase
    $webSession = New-RecorderWebSession -CookieHeader $session.CookieHeader

    $headers = @{
        'Origin'           = $recorderBase
        'Referer'          = "$recorderBase/"
        'Authorization'    = $authToken
        'x-goog-api-key'   = $session.ApiKey
        'x-goog-authuser'  = '0'
        'x-user-agent'     = 'grpc-web-javascript/0.1'
    }

    try {
        $raw = Invoke-WebRequest -Uri $url -Method POST `
            -Headers $headers -Body $Body -ContentType $contentType `
            -WebSession $webSession -UseBasicParsing
        # Content-Type application/json+protobuf is not recognised as text,
        # so .Content is byte[]. Decode to UTF-8 before JSON parsing.
        $text = [System.Text.Encoding]::UTF8.GetString($raw.Content)
        $parsed = $text | ConvertFrom-Json -Depth 20 -NoEnumerate
        return ,$parsed
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 401 -or $statusCode -eq 403) {
            throw "Authentication failed (HTTP $statusCode). Your session may have expired. Run Connect-GoogleRecorder to re-authenticate."
        }
        throw
    }
}
