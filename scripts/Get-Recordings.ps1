<#
.SYNOPSIS
    Lists recordings from Google Recorder via the undocumented gRPC-Web API.

.DESCRIPTION
    Opens a browser window for Google authentication, captures session cookies
    and the API key from the clientconfig endpoint, then calls GetRecordingList
    to retrieve all recordings with their metadata.

    Requires Selenium WebDriver (via the Selenium PowerShell module) and Chrome.

.PARAMETER PageSize
    Number of recordings to fetch per page. Default: 10.

.PARAMETER MaxPages
    Maximum number of pages to fetch. Default: 100 (effectively all).

.EXAMPLE
    .\Get-Recordings.ps1
    .\Get-Recordings.ps1 -PageSize 20 -MaxPages 5
#>

[CmdletBinding()]
param(
    [int]$PageSize = 10,
    [int]$MaxPages = 100
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─── Constants ───────────────────────────────────────────────────────────────

$RecorderBaseUrl    = 'https://recorder.google.com'
$ClientConfigUrl    = "$RecorderBaseUrl/clientconfig"
$RpcPathPrefix      = '/$rpc/java.com.google.wireless.android.pixel.recorder.protos.PlaybackService'
$ContentType        = 'application/json+protobuf'
$CookieCacheFile    = Join-Path $PSScriptRoot 'recorder-cookies.json'

# ─── Helper Functions ────────────────────────────────────────────────────────

function Get-UnixTimestamp {
    <#
    .SYNOPSIS Returns current time as [seconds, nanoseconds].
    #>
    $now = [DateTimeOffset]::UtcNow
    $seconds = $now.ToUnixTimeSeconds()
    $millis  = $now.ToUnixTimeMilliseconds()
    $nanos   = [int](($millis % 1000) * 1000000)
    return @($seconds, $nanos)
}

function ConvertFrom-ProtoTimestamp {
    <#
    .SYNOPSIS Converts a proto timestamp array to a DateTime.
    #>
    param([array]$Timestamp)
    $seconds = [long]$Timestamp[0]
    $epoch   = [DateTimeOffset]::FromUnixTimeSeconds($seconds)
    return $epoch.LocalDateTime
}

function Format-Duration {
    <#
    .SYNOPSIS Formats a proto duration array as mm:ss or hh:mm:ss.
    #>
    param([array]$Duration)
    $totalSeconds = [int]$Duration[0]
    $ts = [TimeSpan]::FromSeconds($totalSeconds)
    if ($ts.TotalHours -ge 1) {
        return $ts.ToString('hh\:mm\:ss')
    }
    return $ts.ToString('mm\:ss')
}

function Get-AuthViaBrowser {
    <#
    .SYNOPSIS Opens Chrome, lets user log in, then captures cookies and API key.
    .OUTPUTS Hashtable with CookieHeader and ApiKey.
    #>

    Write-Host "`n=== Google Recorder Authentication ===" -ForegroundColor Cyan
    Write-Host "A browser window will open. Please log into your Google account."
    Write-Host "Once you see the Recorder page with your recordings, press ENTER here to continue.`n"

    # Try Selenium first, fall back to manual cookie entry
    $useSelenium = $false
    try {
        Import-Module Selenium -ErrorAction Stop
        $useSelenium = $true
    }
    catch {
        Write-Host "Selenium module not found. Trying alternative approach..." -ForegroundColor Yellow
    }

    if ($useSelenium) {
        return Get-AuthViaSelenium
    }
    else {
        return Get-AuthViaManualBrowser
    }
}

function Get-AuthViaSelenium {
    <#
    .SYNOPSIS Uses Selenium WebDriver to automate cookie capture.
    #>
    $options = New-Object OpenQA.Selenium.Chrome.ChromeOptions
    $options.AddArgument('--disable-blink-features=AutomationControlled')

    $driver = New-Object OpenQA.Selenium.Chrome.ChromeDriver($options)
    try {
        $driver.Navigate().GoToUrl("$RecorderBaseUrl")

        Write-Host "Waiting for login... Press ENTER once you see your recordings." -ForegroundColor Yellow
        $null = Read-Host

        # Capture cookies
        $cookies = $driver.Manage().Cookies.AllCookies
        $cookieParts = @()
        foreach ($c in $cookies) {
            $cookieParts += "$($c.Name)=$($c.Value)"
        }
        $cookieHeader = $cookieParts -join '; '

        # Navigate to clientconfig to get the API key
        $driver.Navigate().GoToUrl($ClientConfigUrl)
        Start-Sleep -Seconds 2
        $body = $driver.FindElement([OpenQA.Selenium.By]::TagName('pre')).Text
        # Strip Google XSSI prefix
        if ($body.StartsWith(')]}')) {
            $body = $body.Substring($body.IndexOf("`n") + 1)
        }
        $config = $body | ConvertFrom-Json

        return @{
            CookieHeader = $cookieHeader
            ApiKey       = $config.apiKey
            Email        = $config.email
            BaseUrl      = $config.firstPartyApiUrl
        }
    }
    finally {
        $driver.Quit()
    }
}

function Get-AuthViaManualBrowser {
    <#
    .SYNOPSIS Falls back to manual cookie extraction via DevTools.
    #>
    # Open browser to recorder
    Start-Process "https://recorder.google.com"

    Write-Host @"

  ┌─────────────────────────────────────────────────────────────────┐
  │  MANUAL COOKIE EXTRACTION                                      │
  │                                                                 │
  │  1. Log into Google Recorder in the browser that just opened    │
  │  2. Open DevTools (F12) → Network tab                           │
  │  3. Refresh the page                                            │
  │  4. Click on the 'clientconfig' request                         │
  │  5. From the Response tab, copy the apiKey value                │
  │  6. From the Headers tab, copy the full Cookie header value     │
  └─────────────────────────────────────────────────────────────────┘

"@ -ForegroundColor Yellow

    $apiKey = Read-Host "Paste the API key (apiKey from clientconfig response)"
    $cookieHeader = Read-Host "Paste the full Cookie header value"

    if ([string]::IsNullOrWhiteSpace($apiKey) -or [string]::IsNullOrWhiteSpace($cookieHeader)) {
        throw "API key and cookie header are required."
    }

    return @{
        CookieHeader = $cookieHeader
        ApiKey       = $apiKey.Trim('"', ' ')
        Email        = '(manual)'
        BaseUrl      = 'https://pixelrecorder-pa.clients6.google.com'
    }
}

function Save-AuthCache {
    <#
    .SYNOPSIS Saves auth credentials to a local cache file.
    #>
    param([hashtable]$Auth)
    $Auth | ConvertTo-Json | Set-Content -Path $CookieCacheFile -Encoding UTF8
    Write-Host "Auth cached to $CookieCacheFile" -ForegroundColor DarkGray
}

function Get-AuthCache {
    <#
    .SYNOPSIS Loads cached auth credentials if available.
    #>
    if (Test-Path $CookieCacheFile) {
        try {
            $cached = Get-Content -Path $CookieCacheFile -Raw | ConvertFrom-Json
            # Convert PSObject back to hashtable
            $auth = @{
                CookieHeader = $cached.CookieHeader
                ApiKey       = $cached.ApiKey
                Email        = $cached.Email
                BaseUrl      = $cached.BaseUrl
            }
            Write-Host "Using cached auth for $($auth.Email)" -ForegroundColor DarkGray
            return $auth
        }
        catch {
            Write-Warning "Failed to load cached auth: $_"
        }
    }
    return $null
}

function Invoke-RecorderRpc {
    <#
    .SYNOPSIS Calls a PlaybackService RPC method.
    .PARAMETER Method The RPC method name (e.g., 'GetRecordingList').
    .PARAMETER Body The JSON request body string.
    .PARAMETER Auth The auth hashtable with CookieHeader, ApiKey, BaseUrl.
    .OUTPUTS Parsed JSON response.
    #>
    param(
        [string]$Method,
        [string]$Body,
        [hashtable]$Auth
    )

    $url = "$($Auth.BaseUrl)$RpcPathPrefix/$Method"

    $headers = @{
        'Content-Type'   = $ContentType
        'Origin'         = $RecorderBaseUrl
        'Referer'        = "$RecorderBaseUrl/"
        'x-goog-api-key' = $Auth.ApiKey
        'x-goog-authuser' = '0'
        'x-user-agent'   = 'grpc-web-javascript/0.1'
        'Cookie'         = $Auth.CookieHeader
    }

    $response = Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body $Body -ContentType $ContentType
    return $response
}

function Get-RecordingList {
    <#
    .SYNOPSIS Fetches all recordings with pagination.
    .PARAMETER Auth Auth hashtable.
    .PARAMETER PageSize Recordings per page.
    .PARAMETER MaxPages Maximum pages to fetch.
    .OUTPUTS Array of recording objects.
    #>
    param(
        [hashtable]$Auth,
        [int]$PageSize = 10,
        [int]$MaxPages = 100
    )

    $allRecordings = @()
    $cursor = Get-UnixTimestamp
    $page = 0

    do {
        $page++
        Write-Host "  Fetching page $page..." -ForegroundColor DarkGray

        $body = "[[$($cursor[0]),$($cursor[1])],$PageSize]"
        $result = Invoke-RecorderRpc -Method 'GetRecordingList' -Body $body -Auth $Auth

        if (-not $result -or -not $result[0]) {
            break
        }

        $recordings = $result[0]
        $allRecordings += $recordings

        # Check if there are more pages
        $hasMore = ($result.Count -gt 1) -and ($result[1] -eq 1)

        if ($hasMore -and $recordings.Count -gt 0) {
            # Use the last recording's created_at as cursor for next page
            $lastRecording = $recordings[$recordings.Count - 1]
            $createdAt = $lastRecording[2]
            $cursor = @([long]$createdAt[0], [int]$createdAt[1])
        }
        else {
            $hasMore = $false
        }

    } while ($hasMore -and $page -lt $MaxPages)

    return $allRecordings
}

function Format-Recording {
    <#
    .SYNOPSIS Converts a raw recording array into a friendly object.
    .PARAMETER RawRecording The raw protobuf-JSON array for one recording.
    .OUTPUTS PSCustomObject with named properties.
    #>
    param([array]$RawRecording)

    $title     = $RawRecording[1]
    $created   = if ($RawRecording[2]) { ConvertFrom-ProtoTimestamp $RawRecording[2] } else { $null }
    $duration  = if ($RawRecording[3]) { Format-Duration $RawRecording[3] } else { '??:??' }
    $location  = $RawRecording[6]
    $id        = $RawRecording[13]

    # Extract speaker names
    $speakers = @()
    if ($RawRecording[20] -and $RawRecording[20][0]) {
        foreach ($spk in $RawRecording[20][0]) {
            if ($spk.Count -gt 1 -and $spk[1]) {
                $speakers += $spk[1]
            }
            else {
                $speakers += "Speaker $($spk[0])"
            }
        }
    }

    return [PSCustomObject]@{
        RecordingId = $id
        Title       = $title
        Created     = $created
        Duration    = $duration
        Location    = $location
        Speakers    = ($speakers -join ', ')
        Url         = "https://recorder.google.com/$id"
    }
}

# ─── Main ────────────────────────────────────────────────────────────────────

Write-Host "`nGoogle Recorder - List Recordings`n" -ForegroundColor Cyan

# Authenticate (try cache first)
$auth = Get-AuthCache
if (-not $auth) {
    $auth = Get-AuthViaBrowser
    Save-AuthCache $auth
}

Write-Host "Authenticated as: $($auth.Email)" -ForegroundColor Green
Write-Host "Fetching recordings...`n"

# Fetch all recordings
$rawRecordings = Get-RecordingList -Auth $auth -PageSize $PageSize -MaxPages $MaxPages

if (-not $rawRecordings -or $rawRecordings.Count -eq 0) {
    Write-Warning "No recordings found. Your auth may have expired — delete $CookieCacheFile and re-run."
    exit 1
}

# Format and display
$recordings = $rawRecordings | ForEach-Object { Format-Recording $_ }

Write-Host "`nFound $($recordings.Count) recording(s):`n" -ForegroundColor Green

$recordings | Format-Table -AutoSize -Property @(
    'Created',
    'Duration',
    'Title',
    'Speakers',
    'Location'
)

# Also output to pipeline for further processing
$recordings
