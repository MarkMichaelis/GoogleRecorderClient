function New-RecorderWebSession {
    <#
    .SYNOPSIS
        Creates a WebRequestSession with a CookieContainer populated from a cookie header string.

    .DESCRIPTION
        Parses a semicolon-delimited cookie header (e.g. "SID=abc; HSID=def; ...")
        into a System.Net.CookieContainer and returns a
        Microsoft.PowerShell.Commands.WebRequestSession ready for use with
        Invoke-WebRequest / Invoke-RestMethod -WebSession.

    .PARAMETER CookieHeader
        The raw Cookie header string.

    .PARAMETER Domain
        The cookie domain (default: .google.com).

    .OUTPUTS
        [Microsoft.PowerShell.Commands.WebRequestSession]
    #>
    [Diagnostics.CodeAnalysis.SuppressMessage('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates only an in-memory WebRequestSession; no external state change.')]
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Microsoft.PowerShell.Commands.WebRequestSession])]
    param(
        [Parameter(Mandatory)]
        [string]$CookieHeader,

        [string]$Domain = '.google.com'
    )

    if (-not $PSCmdlet.ShouldProcess("$Domain", 'Create WebRequestSession from cookie header')) {
        return
    }

    $container = [System.Net.CookieContainer]::new()

    foreach ($pair in $CookieHeader.Split(';')) {
        $trimmed = $pair.Trim()
        if (-not $trimmed) { continue }

        $eqIndex = $trimmed.IndexOf('=')
        if ($eqIndex -le 0) { continue }

        $name  = $trimmed.Substring(0, $eqIndex).Trim()
        $value = $trimmed.Substring($eqIndex + 1).Trim()

        $cookie = [System.Net.Cookie]::new($name, $value, '/', $Domain)
        $container.Add($cookie)
    }

    $webSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
    $webSession.Cookies = $container
    return $webSession
}
