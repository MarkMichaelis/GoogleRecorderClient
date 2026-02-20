function Connect-GoogleRecorder {
    <#
    .SYNOPSIS
        Authenticates to Google Recorder and stores the session for subsequent commands.

    .DESCRIPTION
        Opens Chrome in an incognito window pointed at recorder.google.com.
        After the user logs in and presses ENTER, the command captures session
        cookies via Chrome DevTools Protocol and fetches the API key from the
        /clientconfig endpoint.

    .PARAMETER Force
        Ignore any cached session and force a new browser login.

    .PARAMETER Manual
        Skip browser automation and prompt for manual cookie/API-key entry.

    .PARAMETER CookieHeader
        Provide the Cookie header value directly (for scripting / CI scenarios).

    .PARAMETER ApiKey
        Provide the API key directly (for scripting / CI scenarios).

    .EXAMPLE
        Connect-GoogleRecorder

    .EXAMPLE
        Connect-GoogleRecorder -Force

    .EXAMPLE
        Connect-GoogleRecorder -Manual
    #>
    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    param(
        [Parameter(ParameterSetName = 'Interactive')]
        [switch]$Force,

        [Parameter(ParameterSetName = 'Manual', Mandatory)]
        [switch]$Manual,

        [Parameter(ParameterSetName = 'Direct', Mandatory)]
        [string]$CookieHeader,

        [Parameter(ParameterSetName = 'Direct', Mandatory)]
        [string]$ApiKey
    )

    $cacheFile = Join-Path $script:ModuleRoot 'recorder-session.json'

    # --- Direct: caller provided cookie + key ---------------------------------
    if ($PSCmdlet.ParameterSetName -eq 'Direct') {
        $session = Resolve-ClientConfig -CookieHeader $CookieHeader -ApiKeyOverride $ApiKey
        $script:RecorderSession = $session
        Save-SessionCache -Session $session -Path $cacheFile
        Write-Host "Connected to Google Recorder as $($session.Email)." -ForegroundColor Green
        return
    }

    # --- Try cached session first ---------------------------------------------
    if (-not $Force -and (Test-Path $cacheFile)) {
        try {
            $cached = Get-Content -Path $cacheFile -Raw | ConvertFrom-Json
            $session = @{
                CookieHeader = $cached.CookieHeader
                ApiKey       = $cached.ApiKey
                Email        = $cached.Email
                BaseUrl      = $cached.BaseUrl
            }
            $null = Invoke-ClientConfigRequest -CookieHeader $session.CookieHeader
            $script:RecorderSession = $session
            Write-Host "Restored cached session for $($session.Email)." -ForegroundColor Green
            return
        }
        catch {
            Write-Verbose "Cached session invalid or expired: $_"
            Remove-Item -Path $cacheFile -Force -ErrorAction SilentlyContinue
        }
    }

    # --- Manual entry ---------------------------------------------------------
    if ($Manual) {
        $session = Get-AuthViaManualEntry
        $script:RecorderSession = $session
        Save-SessionCache -Session $session -Path $cacheFile
        Write-Host 'Connected to Google Recorder.' -ForegroundColor Green
        return
    }

    # --- Browser-based login --------------------------------------------------
    $session = Get-AuthViaPlaywright
    if (-not $session) {
        throw 'Authentication failed. Run Connect-GoogleRecorder -Manual to enter cookies by hand.'
    }
    $script:RecorderSession = $session
    Save-SessionCache -Session $session -Path $cacheFile
    Write-Host "Connected to Google Recorder as $($session.Email)." -ForegroundColor Green
}


# ─── Internal helpers ────────────────────────────────────────────────────────

function Invoke-ClientConfigRequest {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$CookieHeader)

    $raw = Invoke-WebRequest -Uri 'https://recorder.google.com/clientconfig' `
        -Headers @{ Cookie = $CookieHeader } -UseBasicParsing
    $body = $raw.Content
    # Strip XSSI prefix  )]}'\n
    if ($body.Length -gt 5 -and $body.Substring(0, 4) -eq ")]}'") {
        $nlPos = $body.IndexOf([char]10)
        if ($nlPos -ge 0) { $body = $body.Substring($nlPos + 1) }
    }
    return ($body | ConvertFrom-Json)
}

function Resolve-ClientConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CookieHeader,
        [string]$ApiKeyOverride
    )
    $config = Invoke-ClientConfigRequest -CookieHeader $CookieHeader
    return @{
        CookieHeader = $CookieHeader
        ApiKey       = if ($ApiKeyOverride) { $ApiKeyOverride } else { $config.apiKey }
        Email        = $config.email
        BaseUrl      = $config.firstPartyApiUrl
    }
}

function Save-SessionCache {
    param([hashtable]$Session, [string]$Path)
    $Session | ConvertTo-Json -Depth 4 | Set-Content -Path $Path -Encoding UTF8
    Write-Verbose "Session cached to $Path"
}

function Get-AuthViaManualEntry {
    Start-Process 'https://recorder.google.com'
    Write-Host @"

  +---------------------------------------------------------------+
  |  MANUAL AUTHENTICATION                                        |
  |                                                                |
  |  1. Log into Google Recorder in the browser that just opened   |
  |  2. Open DevTools (F12) -> Network tab                         |
  |  3. Refresh the page                                           |
  |  4. Click on the 'clientconfig' request                        |
  |  5. From the Response tab, copy the apiKey value               |
  |  6. From the Headers tab, copy the full Cookie header value    |
  +---------------------------------------------------------------+

"@ -ForegroundColor Yellow

    $apiKey       = Read-Host 'Paste the API key (apiKey from clientconfig response)'
    $cookieHeader = Read-Host 'Paste the full Cookie header value'
    if ([string]::IsNullOrWhiteSpace($apiKey) -or [string]::IsNullOrWhiteSpace($cookieHeader)) {
        throw 'API key and cookie header are both required.'
    }
    return @{
        CookieHeader = $cookieHeader.Trim()
        ApiKey       = $apiKey.Trim('"', ' ')
        Email        = '(manual entry)'
        BaseUrl      = 'https://pixelrecorder-pa.clients6.google.com'
    }
}


# ─── Playwright-based browser authentication (.NET) ──────────────────────────

function Get-AuthViaPlaywright {
    <#
    .SYNOPSIS
        Launches Chrome via .NET Playwright (PlaywrightAuth project),
        navigates to recorder.google.com, auto-detects login, then
        captures cookies and API config.
        Uses a persistent browser profile so the user only logs in once.
        Existing browser windows are left untouched.
    #>

    # Locate the PlaywrightAuth .csproj
    $repoRoot = Split-Path $script:ModuleRoot -Parent | Split-Path -Parent
    $projectPath = Join-Path $repoRoot 'src' 'PlaywrightAuth' 'PlaywrightAuth.csproj'
    if (-not (Test-Path $projectPath)) {
        $projectPath = Join-Path (Split-Path $script:ModuleRoot -Parent) 'src' 'PlaywrightAuth' 'PlaywrightAuth.csproj'
    }
    if (-not (Test-Path $projectPath)) {
        Write-Warning "PlaywrightAuth project not found at: $projectPath"
        Write-Host '  Falling back to manual entry.' -ForegroundColor Yellow
        return Get-AuthViaManualEntry
    }

    # Verify dotnet SDK is available
    $dotnetPath = Get-Command dotnet -ErrorAction SilentlyContinue
    if (-not $dotnetPath) {
        Write-Warning '.NET SDK (dotnet) is not installed or not in PATH.'
        Write-Host '  Falling back to manual entry.' -ForegroundColor Yellow
        return Get-AuthViaManualEntry
    }

    Write-Host ''
    Write-Host '=== Google Recorder Authentication ===' -ForegroundColor Cyan
    Write-Host 'Chrome will open with a saved profile.' -ForegroundColor DarkGray
    Write-Host 'If this is your first time, log into your Google account.' -ForegroundColor Yellow
    Write-Host 'On subsequent runs, your saved session will be reused automatically.' -ForegroundColor DarkGray
    Write-Host ''

    # Build arguments: dotnet run --project <path> -- [--force]
    $dotnetArgs = "run --project `"$projectPath`""
    if ($Force) {
        $dotnetArgs += ' -- --force'
    }

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $dotnetPath.Source
    $psi.Arguments = $dotnetArgs
    $psi.WorkingDirectory = Split-Path $projectPath -Parent
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi
    $process.EnableRaisingEvents = $true

    $stderrJob = Register-ObjectEvent -InputObject $process -EventName 'ErrorDataReceived' -Action {
        if ($null -ne $EventArgs.Data) {
            Write-Host "  $($EventArgs.Data)" -ForegroundColor DarkGray
        }
    }

    $process.Start() | Out-Null
    $process.BeginErrorReadLine()

    # Read all stdout (the JSON result)
    $stdout = $process.StandardOutput.ReadToEnd()
    $process.WaitForExit()

    $exitCode = $process.ExitCode
    Unregister-Event -SourceIdentifier $stderrJob.Name -ErrorAction SilentlyContinue
    $process.Dispose()

    if ($exitCode -ne 0) {
        Write-Warning "Playwright authentication failed (exit code $exitCode)."
        Write-Host '  Falling back to manual entry.' -ForegroundColor Yellow
        return Get-AuthViaManualEntry
    }

    if ([string]::IsNullOrWhiteSpace($stdout)) {
        Write-Warning 'Playwright returned no output.'
        Write-Host '  Falling back to manual entry.' -ForegroundColor Yellow
        return Get-AuthViaManualEntry
    }

    try {
        $result = $stdout | ConvertFrom-Json
    }
    catch {
        Write-Warning "Could not parse Playwright output: $_"
        Write-Host '  Falling back to manual entry.' -ForegroundColor Yellow
        return Get-AuthViaManualEntry
    }

    if (-not $result.cookieHeader -or -not $result.apiKey) {
        Write-Warning 'Playwright output is missing cookieHeader or apiKey.'
        Write-Host '  Falling back to manual entry.' -ForegroundColor Yellow
        return Get-AuthViaManualEntry
    }

    return @{
        CookieHeader = $result.cookieHeader
        ApiKey       = $result.apiKey
        Email        = $result.email
        BaseUrl      = $result.baseUrl
    }
}

