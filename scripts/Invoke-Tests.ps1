<#
.SYNOPSIS
    Runs the GoogleRecorderClient unit and functional test suites.

.DESCRIPTION
    Ensures a valid Google Recorder session exists before running tests.
    First checks for cached credentials; if they are valid, proceeds
    directly to the test suites. If no valid cache exists, launches a
    browser in a separate terminal window for interactive authentication.

    Use -Force to skip the cache check and always launch the browser.

.PARAMETER Force
    Skip cached credential check and force a new browser authentication.

.PARAMETER UnitOnly
    Run only the unit tests (skip functional tests).

.PARAMETER FunctionalOnly
    Run only the functional tests (skip unit tests).

.EXAMPLE
    .\scripts\Invoke-Tests.ps1

.EXAMPLE
    .\scripts\Invoke-Tests.ps1 -Force

.EXAMPLE
    .\scripts\Invoke-Tests.ps1 -UnitOnly
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$UnitOnly,
    [switch]$FunctionalOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot   = Split-Path $PSScriptRoot -Parent
$modulePath = Join-Path $repoRoot 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
$cacheFile  = Join-Path $repoRoot 'src' 'GoogleRecorderClient' 'recorder-session.json'

# ─── Import the module ────────────────────────────────────────────────────────
Get-Module GoogleRecorderClient -All | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module $modulePath -Force -ErrorAction Stop
Write-Host 'Module imported successfully.' -ForegroundColor Green

# ─── Authenticate ─────────────────────────────────────────────────────────────

function Test-CachedSession {
    <#
    .SYNOPSIS
        Tests whether the cached session file is valid by calling clientconfig.
        Returns $true if the cache is usable, $false otherwise.
        Does NOT launch any browser or prompt for input.
    #>
    if (-not (Test-Path $cacheFile)) { return $false }
    try {
        $cached = Get-Content -Path $cacheFile -Raw | ConvertFrom-Json
        if (-not $cached.CookieHeader -or -not $cached.ApiKey) { return $false }

        # Validate the session by calling Connect with Direct parameters (no browser)
        Connect-GoogleRecorder -CookieHeader $cached.CookieHeader -ApiKey $cached.ApiKey -ErrorAction Stop
        return $true
    }
    catch {
        Write-Verbose "Cached session validation failed: $_"
        return $false
    }
}

if ($Force) {
    # -Force: always launch browser in a separate terminal, skip cache entirely
    Write-Host 'Force flag set — launching browser for authentication.' -ForegroundColor Yellow
}
elseif (Test-CachedSession) {
    # Cache is valid — no browser, no prompt, just run tests
    Write-Host 'Cached session is valid — proceeding directly to tests.' -ForegroundColor Green
}
else {
    # No valid cache — launch browser in a separate terminal window
    Write-Host 'No valid cached credentials found.' -ForegroundColor Yellow
}

# Only launch the browser if we don't already have a valid session
if ($Force -or -not (Test-Path variable:script:RecorderSession) -or -not $script:RecorderSession) {
    # Check module-level session (set by Test-CachedSession on success)
    $hasSession = $false
    try {
        $hasSession = [bool](Get-Module GoogleRecorderClient | ForEach-Object {
            & $_ { $script:RecorderSession }
        })
    } catch { }

    if (-not $hasSession) {
        Write-Host '' -ForegroundColor Yellow
        Write-Host '╔══════════════════════════════════════════════════════════╗' -ForegroundColor Yellow
        Write-Host '║  Browser authentication required.                       ║' -ForegroundColor Yellow
        Write-Host '║  A new terminal window will open for authentication.    ║' -ForegroundColor Yellow
        Write-Host '║  Log in, then close the browser to continue.           ║' -ForegroundColor Yellow
        Write-Host '╚══════════════════════════════════════════════════════════╝' -ForegroundColor Yellow
        Write-Host ''

        $connectArgs = if ($Force) { '-Force' } else { '' }
        $authScript = @"
`$ErrorActionPreference = 'Stop'
Import-Module '$modulePath' -Force
Connect-GoogleRecorder $connectArgs
Write-Host ''
Write-Host 'Authentication complete. You can close this window.' -ForegroundColor Green
pause
"@

        $tempScript = Join-Path ([System.IO.Path]::GetTempPath()) 'GoogleRecorder-Auth.ps1'
        $authScript | Set-Content -Path $tempScript -Encoding UTF8

        $authProcess = Start-Process pwsh -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempScript`"" -PassThru
        Write-Host 'Waiting for authentication to complete...' -ForegroundColor DarkGray
        $authProcess.WaitForExit()
        Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue

        if ($authProcess.ExitCode -ne 0) {
            Write-Error 'Authentication failed. Cannot run tests.'
            return
        }

        # Re-import module and load the newly cached session
        Get-Module GoogleRecorderClient -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module $modulePath -Force -ErrorAction Stop
        Connect-GoogleRecorder -ErrorAction Stop
        Write-Host 'Session loaded after browser authentication.' -ForegroundColor Green
    }
}

# ─── Run lint ─────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host '═══ Running ScriptAnalyzer ═══' -ForegroundColor Cyan
$lintResults = Invoke-ScriptAnalyzer -Path (Join-Path $repoRoot 'src') -Recurse -Severity Warning
if ($lintResults) {
    Write-Host "ScriptAnalyzer found $($lintResults.Count) warning(s):" -ForegroundColor Yellow
    $lintResults | Format-Table -AutoSize
}
else {
    Write-Host 'No lint warnings.' -ForegroundColor Green
}

# ─── Run tests ────────────────────────────────────────────────────────────────
$testPaths = @()
if (-not $FunctionalOnly) {
    $testPaths += Join-Path $repoRoot 'tests' 'unit'
}
if (-not $UnitOnly) {
    $testPaths += Join-Path $repoRoot 'tests' 'functional'
}

Write-Host ''
Write-Host "═══ Running Pester Tests ═══" -ForegroundColor Cyan
Write-Host "Paths: $($testPaths -join ', ')" -ForegroundColor DarkGray

Invoke-Pester -Path $testPaths -Output Detailed
