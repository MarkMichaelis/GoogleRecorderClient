# Shared test data factories for GoogleRecorderClient tests

function New-FakeRawRecording {
    <#
    .SYNOPSIS
        Creates a fake raw recording array matching the API protobuf-JSON format.
    #>
    param(
        [string]$Id = 'test-recording-id',
        [string]$Title = 'Test Recording',
        [long]$CreatedSeconds = 1771181693,
        [int]$CreatedNanos = 323000000,
        [string]$DurationSeconds = '978',
        [int]$DurationNanos = 200000000,
        [double]$Lat = 47.629,
        [double]$Lon = -117.216,
        [string]$Location = 'Spokane Valley, Washington',
        [string[]]$SpeakerEntries = @('1 Elisabeth', '2 Mark')
    )

    # Build 25-element array matching the API Recording Array Structure
    $raw = [object[]]::new(25)
    $raw[0]  = 'internal-uuid-000'
    $raw[1]  = $Title
    $raw[2]  = @($CreatedSeconds.ToString(), $CreatedNanos)
    $raw[3]  = @($DurationSeconds, $DurationNanos)
    $raw[4]  = $Lat
    $raw[5]  = $Lon
    $raw[6]  = $Location
    $raw[7]  = $null
    $raw[8]  = @(2, 'audio/mp4a-latm', 48000, 1, 128000, 4800, 2, 10)
    $raw[9]  = $null
    $raw[10] = @(@('0 1', '100 0'))
    $raw[11] = 'secondary-uuid-000'
    $raw[12] = $null
    $raw[13] = $Id
    $raw[14] = $null
    $raw[15] = $null
    $raw[16] = $null
    $raw[17] = $null
    $raw[18] = 5
    $raw[19] = 2
    $raw[20] = @(, $SpeakerEntries)
    $raw[21] = $null
    $raw[22] = @(@('en-US', '338600'))
    $raw[23] = @()
    $raw[24] = @(@('0', '1'), 1, 1, 47.41, 0.55)

    return , $raw
}

function New-FakeSession {
    <#
    .SYNOPSIS
        Creates a fake RecorderSession hashtable for testing.
    #>
    param(
        [string]$ApiKey = 'fake-api-key',
        [string]$Email  = 'test@example.com',
        [string]$BaseUrl = 'https://pixelrecorder-pa.clients6.google.com',
        [string]$CookieHeader = 'SID=abc; HSID=def; SSID=ghi; APISID=jkl; SAPISID=mno/pqr'
    )

    return @{
        CookieHeader = $CookieHeader
        ApiKey       = $ApiKey
        Email        = $Email
        BaseUrl      = $BaseUrl
    }
}
