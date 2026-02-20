function Get-SapisIdHash {
    <#
    .SYNOPSIS
        Computes the SAPISIDHASH authorization token required by Google APIs.

    .DESCRIPTION
        Google APIs that use cookie-based authentication require an
        Authorization header of the form:
            SAPISIDHASH <unix_timestamp>_<sha1_hex>
        where the SHA-1 input is:  "<timestamp> <SAPISID_value> <origin>"

    .PARAMETER SapisId
        The value of the SAPISID cookie.

    .PARAMETER Origin
        The origin URL (e.g. https://recorder.google.com).

    .OUTPUTS
        [string] The full Authorization header value.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$SapisId,

        [Parameter(Mandatory)]
        [string]$Origin
    )

    $timestamp = [long][Math]::Floor(([DateTimeOffset]::UtcNow).ToUnixTimeSeconds())
    $hashInput = "$timestamp $SapisId $Origin"

    $sha1      = [System.Security.Cryptography.SHA1]::Create()
    try {
        $bytes = $sha1.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hashInput))
        $hex   = ($bytes | ForEach-Object { $_.ToString('x2') }) -join ''
    }
    finally {
        $sha1.Dispose()
    }

    return "SAPISIDHASH ${timestamp}_${hex}"
}
