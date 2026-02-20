# GoogleRecorderClient — Product Specification

## Overview

GoogleRecorderClient is a **PowerShell module** that interfaces with the Google Recorder gRPC-Web API at `recorder.google.com`. It provides cmdlets for browser-based authentication and recording management.

## Features

### 1. Authentication (`Connect-GoogleRecorder`)

Authenticates the user to Google Recorder and stores session data for subsequent commands.

**Modes:**

| Mode | Trigger | Description |
|---|---|---|
| Interactive (default) | `Connect-GoogleRecorder` | Launches Chrome via .NET Playwright with a persistent browser profile. User logs in once; subsequent runs reuse the saved session. |
| Force re-auth | `-Force` | Clears the saved browser profile and forces a new login. |
| Manual entry | `-Manual` | Opens `recorder.google.com` in a browser and prompts the user to paste cookies and API key from DevTools. |
| Direct | `-CookieHeader`, `-ApiKey` | Accepts credentials directly for scripting/CI scenarios. |

**Acceptance Criteria:**

- Session cookies, API key, email, and base URL are captured automatically after interactive login.
- Cached sessions are restored on module reload without re-launching a browser.
- SAPISIDHASH authorization token is computed on every API call from the SAPISID cookie.
- `Connect-GoogleRecorder -Force` clears all cached state and forces re-authentication.
- Falls back to manual entry if Playwright or .NET SDK is not available.

### 2. Session Disconnection (`Disconnect-GoogleRecorder`)

Clears the in-memory session and deletes the cached session file on disk so that subsequent commands require a fresh `Connect-GoogleRecorder`.

**Acceptance Criteria:**

- After disconnection, API commands throw a descriptive error (no auto-reconnect possible since cache is deleted).
- The persisted `recorder-session.json` file is always deleted on disconnect.

### 3. Auto-Connect from Cache (`Assert-RecorderSession`)

All public functions that require authentication automatically attempt to restore the session from cached credentials before throwing an error. No browser is launched and no user interaction is required if valid cached credentials exist.

**Acceptance Criteria:**

- If no in-memory session exists, checks for a cached `recorder-session.json` file.
- If cache is valid, silently restores the session via `Connect-GoogleRecorder`.
- If cache is missing or invalid, throws "Not connected to Google Recorder. Run Connect-GoogleRecorder first."
- Never launches a browser or prompts for input during auto-connect.

### 4. List Recordings (`Get-GoogleRecording`)

Retrieves the authenticated user's recordings with metadata.

**Parameters:**

| Parameter | Default | Description |
|---|---|---|
| `-PageSize` | 10 | Number of recordings per API page (1–100). |
| `-MaxPages` | 100 | Maximum pages to retrieve. |
| `-First` | *(all)* | Stop after N recordings. |

**Acceptance Criteria:**

- Returns `Recording` objects with: RecordingId, Title, Created, Duration, Location, Latitude, Longitude, Speakers, Url.
- Pagination is automatic cursor-based using the last recording's timestamp.
- Named speakers are extracted (e.g., "Elisabeth", "Mark"); unnamed speakers show as "Speaker N".
- Default table view shows Created, Duration, Title.
- Requires an active session; auto-connects from cache if needed.

### 5. Get Recording by ID (`Get-GoogleRecording -RecordingId`)

Retrieves a single recording's detailed information via the `GetRecordingInfo` RPC.

**Parameters:**

| Parameter | Description |
|---|---|
| `-RecordingId` | UUID of the recording to retrieve. Accepts pipeline input by property name. |

**Acceptance Criteria:**

- Calls `GetRecordingInfo` with the recording ID.
- Returns a `Recording` object with an `AudioDownloadUrl` property.
- Throws when the recording is not found.
- Accepts `RecordingId` from pipeline (e.g., `Get-GoogleRecording -First 1 | Get-GoogleRecording`).

### 6. Get Transcript (`Get-GoogleRecordingTranscript`)

Retrieves word-level transcripts for a recording via the `GetTranscription` RPC.

**Parameters:**

| Parameter | Description |
|---|---|
| `-RecordingId` | UUID of the recording. Accepts pipeline input by property name. |
| `-AsText` | Return the transcript as a single plain text string instead of word objects. |
| `-OutputPath` | File path or directory to save the transcript as text. If a directory, auto-generates `{RecordingId}.txt`. Implies `-AsText`. |
| `-Force` | Overwrite the output file if it already exists. |

**Acceptance Criteria:**

- Returns `GoogleRecorder.TranscriptWord` objects with Word, RawWord, StartMs, EndMs, SpeakerId.
- With `-AsText`, returns a space-joined string of all words.
- With `-OutputPath`, saves the transcript text to a file.
- Validates parent directory exists; throws if missing.
- Without `-Force`, throws if the output file already exists.
- Supports `-WhatIf` and `-Confirm` when saving to a file.
- Resolves relative paths correctly via `GetUnresolvedProviderPathFromPSPath`.
- Writes a warning when no transcript is found.
- Supports pipeline: `Get-GoogleRecording -First 1 | Get-GoogleRecordingTranscript -AsText`.

### 7. List Labels (`Get-GoogleRecorderLabel`)

Retrieves all labels/tags available in the user's recording library via the `ListLabels` RPC.

**Acceptance Criteria:**

- Returns `GoogleRecorder.Label` objects with Id and Name properties.
- Returns empty output when no labels exist.

### 8. Get Share List (`Get-GoogleRecordingShare`)

Retrieves the sharing status for a recording via the `GetShareList` RPC.

**Parameters:**

| Parameter | Description |
|---|---|
| `-RecordingId` | UUID of the recording. Accepts pipeline input by property name. |

**Acceptance Criteria:**

- Returns `GoogleRecorder.Share` objects with share details.
- Returns empty output when no shares exist.

### 9. Get Audio Tags (`Get-GoogleRecordingAudioTag`)

Retrieves audio tag/speaker timeline data for a recording via the `GetAudioTag` RPC.

**Parameters:**

| Parameter | Description |
|---|---|
| `-RecordingId` | UUID of the recording. Accepts pipeline input by property name. |

**Acceptance Criteria:**

- Returns `GoogleRecorder.AudioTag` objects with SpeakerId, TimestampMs, and Amplitude.
- Returns empty output when no tags exist.

### 10. Get Waveform (`Get-GoogleRecordingWaveform`)

Retrieves waveform amplitude data for a recording via the `GetWaveform` RPC.

**Parameters:**

| Parameter | Description |
|---|---|
| `-RecordingId` | UUID of the recording. Accepts pipeline input by property name. |

**Acceptance Criteria:**

- Returns a `GoogleRecorder.Waveform` object with RecordingId and Samples (float array).

### 11. Rename Recording (`Rename-GoogleRecording`)

Renames a recording's title via the `UpdateRecordingTitle` RPC.

**Parameters:**

| Parameter | Description |
|---|---|
| `-RecordingId` | UUID of the recording. Accepts pipeline input by property name. |
| `-NewTitle` | The new title string. |

**Acceptance Criteria:**

- Calls `UpdateRecordingTitle` with the recording ID and new title.
- Supports `-WhatIf` and `-Confirm` via `SupportsShouldProcess`.
- Validates that `NewTitle` is not null or empty.

### 12. Save Audio (`Save-GoogleRecordingAudio`)

Downloads the audio file for a recording via direct HTTP download.

**Parameters:**

| Parameter | Description |
|---|---|
| `-RecordingId` | UUID of the recording. Accepts pipeline input by property name. |
| `-OutputPath` | Path to save the audio file. If a directory, auto-generates `{RecordingId}.m4a`. |
| `-Force` | Overwrite the output file if it already exists. |

**Acceptance Criteria:**

- Downloads from `https://usercontent.recorder.google.com/download/playback/{id}`.
- Uses session cookies and SAPISIDHASH authorization.
- Auto-generates filename as `{RecordingId}.m4a` when only a directory is given.
- Validates parent directory exists; throws if missing.
- Without `-Force`, throws if the output file already exists.
- Supports `-WhatIf` and `-Confirm`.
- Resolves relative paths correctly via `GetUnresolvedProviderPathFromPSPath`.

### 13. Test Search Readiness (`Test-GoogleRecorderSearch`)

Tests whether the user's recording library has been indexed for global search via the `GetGlobalSearchReadiness` RPC.

**Acceptance Criteria:**

- Returns `$true` when search is ready, `$false` otherwise.
- Takes no parameters beyond an active session.

## API Surface

### Exported Cmdlets

| Cmdlet | Synopsis |
|---|---|
| `Connect-GoogleRecorder` | Authenticate and store session. |
| `Disconnect-GoogleRecorder` | Clear the current session. |
| `Get-GoogleRecording` | List recordings or get a single recording by ID. |
| `Get-GoogleRecorderLabel` | List all labels/tags. |
| `Get-GoogleRecordingAudioTag` | Get audio tag/speaker timeline data. |
| `Get-GoogleRecordingShare` | Get sharing status for a recording. |
| `Get-GoogleRecordingTranscript` | Get word-level transcript or plain text. |
| `Get-GoogleRecordingWaveform` | Get waveform amplitude data. |
| `Rename-GoogleRecording` | Rename a recording's title. |
| `Save-GoogleRecordingAudio` | Download a recording's audio file. |
| `Test-GoogleRecorderSearch` | Test if search indexing is ready. |

### Private Helpers

| Function | Purpose |
|---|---|
| `Assert-RecorderSession` | Ensures a valid session; auto-connects from cache. |
| `Invoke-RecorderRpc` | Sends gRPC-Web POST requests to PlaybackService. |
| `Get-SapisIdHash` | Computes SAPISIDHASH authorization token. |
| `New-RecorderWebSession` | Creates a WebRequestSession with cookies. |
| `ConvertFrom-ProtoTimestamp` | Converts Unix seconds to DateTime. |
| `Format-RecorderDuration` | Formats seconds as mm:ss or hh:mm:ss. |
| `Format-RawRecording` | Maps raw API arrays to Recording objects. |
| `Get-UnixTimestamp` | Gets current Unix timestamp with nanoseconds. |
| `Resolve-OutputFilePath` | Validates and resolves output file paths (directory expansion, parent validation, overwrite protection). |

### Output Types

**`Recording`** — strongly-typed PowerShell class with:

| Property | Type | Description |
|---|---|---|
| RecordingId | string | UUID for API calls and URLs |
| Id | *(alias)* | Alias for RecordingId (registered via `Update-TypeData`) |
| Title | string | Recording title |
| Created | DateTime | Local creation timestamp |
| Duration | string | Formatted as mm:ss or hh:mm:ss |
| Latitude | double | GPS latitude |
| Longitude | double | GPS longitude |
| Location | string | Reverse-geocoded place name |
| Speakers | string[] | Identified speaker names |
| Url | string | Direct URL to recording |
| AudioDownloadUrl | string | Download URL (only from `-RecordingId` query) |

**`GoogleRecorder.TranscriptWord`** — word-level transcript entry:

| Property | Type | Description |
|---|---|---|
| Word | string | Display word (formatted) |
| RawWord | string | Raw word from API |
| StartMs | int | Start time in milliseconds |
| EndMs | int | End time in milliseconds |
| SpeakerId | int | Speaker identifier |

**`GoogleRecorder.Label`** — recording label/tag:

| Property | Type | Description |
|---|---|---|
| Id | string | Label identifier |
| Name | string | Label display name |

**`GoogleRecorder.Share`** — sharing entry:

| Property | Type | Description |
|---|---|---|
| *(varies)* | | Share details from API response |

**`GoogleRecorder.AudioTag`** — speaker audio tag:

| Property | Type | Description |
|---|---|---|
| SpeakerId | int | Speaker identifier |
| TimestampMs | int | Timestamp in milliseconds |
| Amplitude | double | Audio amplitude value |

**`GoogleRecorder.Waveform`** — waveform data:

| Property | Type | Description |
|---|---|---|
| RecordingId | string | Recording UUID |
| Samples | float[] | Amplitude sample array |

## Architecture

```
Connect-GoogleRecorder
  └─ PlaywrightAuth (.NET 10 console app)
       └─ Microsoft.Playwright → Chrome (persistent profile)
       └─ Outputs JSON: { cookieHeader, apiKey, email, baseUrl }
  └─ Session stored in $script:RecorderSession + recorder-session.json

Assert-RecorderSession (called by all public functions)
  └─ If session exists → return immediately
  └─ If cache file exists → Connect-GoogleRecorder (silent restore)
  └─ Otherwise → throw "Not connected"

Get-GoogleRecording [-RecordingId]
  └─ List mode → Get-RecordingList → GetRecordingList RPC (paginated)
  └─ ById mode → Get-SingleRecording → GetRecordingInfo RPC
  └─ Both → Format-RawRecording → Recording objects

Get-GoogleRecordingTranscript     → GetTranscription RPC
Get-GoogleRecorderLabel           → ListLabels RPC
Get-GoogleRecordingShare          → GetShareList RPC
Get-GoogleRecordingAudioTag       → GetAudioTag RPC
Get-GoogleRecordingWaveform       → GetWaveform RPC
Test-GoogleRecorderSearch         → GetGlobalSearchReadiness RPC
Rename-GoogleRecording            → UpdateRecordingTitle RPC
Save-GoogleRecordingAudio         → HTTP GET download (not RPC)

All RPC functions use:
  └─ Invoke-RecorderRpc (private)
       ├─ Get-SapisIdHash → Authorization: SAPISIDHASH header
       ├─ New-RecorderWebSession → CookieContainer
       └─ Invoke-WebRequest + ConvertFrom-Json
```

## Data Model

**Session** (module-scoped hashtable):

| Key | Source |
|---|---|
| CookieHeader | Playwright cookie capture |
| ApiKey | `/clientconfig` response |
| Email | `/clientconfig` response |
| BaseUrl | `/clientconfig` response (`firstPartyApiUrl`) |

## Known Limitations

- Requires .NET 10+ SDK and Google Chrome installed locally for interactive authentication.
- Uses undocumented Google Recorder API — may break if Google changes endpoints or auth requirements.
- Cookie-based auth expires; user must re-authenticate periodically.
- The `application/json+protobuf` response format requires manual JSON parsing (PowerShell's `Invoke-RestMethod` does not handle this content type correctly).
- The `[Parameter(Mandatory)][array]` combination in PowerShell fails when the array contains null elements; `[object]` is used instead.
