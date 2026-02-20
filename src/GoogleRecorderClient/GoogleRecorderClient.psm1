#Requires -Version 5.1

<#
.SYNOPSIS
    GoogleRecorderClient — PowerShell module for Google Recorder.

.DESCRIPTION
    Provides cmdlets to authenticate with Google Recorder (recorder.google.com)
    and interact with recordings via the undocumented gRPC-Web API.

    Public commands:
      Connect-GoogleRecorder    — Log in and capture session cookies.
      Disconnect-GoogleRecorder — Clear the current session.
      Get-GoogleRecording       — List recordings with metadata.
#>

# ─── Module-scoped state ─────────────────────────────────────────────────────

# Root path of the module (used for caching session files)
$script:ModuleRoot = $PSScriptRoot

# In-memory session hashtable (populated by Connect-GoogleRecorder)
#   Keys: CookieHeader, ApiKey, Email, BaseUrl
$script:RecorderSession = $null

# ─── Dot-source class definitions ────────────────────────────────────────────

# Classes must be loaded before any functions that reference them.
$classPath = Join-Path $PSScriptRoot 'Classes'
if (Test-Path $classPath) {
    Get-ChildItem -Path $classPath -Filter '*.ps1' -Recurse | ForEach-Object {
        . $_.FullName
    }
}

# Register Id as an alias for RecordingId on Recording
Update-TypeData -TypeName 'Recording' `
    -MemberType AliasProperty -MemberName 'Id' -Value 'RecordingId' `
    -Force -ErrorAction SilentlyContinue

# ─── Dot-source function files ───────────────────────────────────────────────

# Private helpers (not exported)
$privatePath = Join-Path $PSScriptRoot 'Private'
if (Test-Path $privatePath) {
    Get-ChildItem -Path $privatePath -Filter '*.ps1' -Recurse | ForEach-Object {
        . $_.FullName
    }
}

# Public commands (exported)
$publicPath = Join-Path $PSScriptRoot 'Public'
if (Test-Path $publicPath) {
    Get-ChildItem -Path $publicPath -Filter '*.ps1' -Recurse | ForEach-Object {
        . $_.FullName
    }
}

# ─── Default format for Recording objects ────────────────────────────────────

Update-FormatData -PrependPath (Join-Path $PSScriptRoot 'GoogleRecorderClient.Format.ps1xml') -ErrorAction SilentlyContinue

# ─── Export public functions ─────────────────────────────────────────────────

Export-ModuleMember -Function @(
    'Connect-GoogleRecorder'
    'Disconnect-GoogleRecorder'
    'Edit-GoogleRecordingAudio'
    'Get-GoogleRecorderLabel'
    'Get-GoogleRecording'
    'Get-GoogleRecordingAudioTag'
    'Get-GoogleRecordingShare'
    'Get-GoogleRecordingTranscript'
    'Get-GoogleRecordingWaveform'
    'Remove-GoogleRecording'
    'Rename-GoogleRecording'
    'Rename-GoogleRecordingSpeaker'
    'Save-GoogleRecordingAudio'
    'Set-GoogleRecordingSpeaker'
    'Split-GoogleRecordingTranscript'
    'Test-GoogleRecorderSearch'
)
