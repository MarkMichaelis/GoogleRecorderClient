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

Clears the in-memory session and optionally deletes the cached session file.

**Acceptance Criteria:**

- After disconnection, API commands throw a descriptive error.
- `-ClearCache` removes the persisted `recorder-session.json` file.

### 3. List Recordings (`Get-GoogleRecording`)

Retrieves the authenticated user's recordings with metadata.

**Parameters:**

| Parameter | Default | Description |
|---|---|---|
| `-PageSize` | 10 | Number of recordings per API page (1–100). |
| `-MaxPages` | 100 | Maximum pages to retrieve. |
| `-First` | *(all)* | Stop after N recordings. |

**Acceptance Criteria:**

- Returns `GoogleRecorder.Recording` objects with: RecordingId, Title, Created, Duration, Location, Latitude, Longitude, Speakers, Url.
- Pagination is automatic cursor-based using the last recording's timestamp.
- Named speakers are extracted (e.g., "Elisabeth", "Mark"); unnamed speakers show as "Speaker N".
- Default table view shows Created, Duration, Title.
- Requires an active session; throws a clear error if not connected.

## API Surface

### Exported Cmdlets

| Cmdlet | Synopsis |
|---|---|
| `Connect-GoogleRecorder` | Authenticate and store session. |
| `Disconnect-GoogleRecorder` | Clear the current session. |
| `Get-GoogleRecording` | List recordings with metadata. |

### Output Types

**`GoogleRecorder.Recording`** — custom PSObject with:

| Property | Type | Description |
|---|---|---|
| RecordingId | string | UUID for API calls and URLs |
| Title | string | Recording title |
| Created | DateTime | Local creation timestamp |
| Duration | string | Formatted as mm:ss or hh:mm:ss |
| Latitude | double | GPS latitude |
| Longitude | double | GPS longitude |
| Location | string | Reverse-geocoded place name |
| Speakers | string[] | Identified speaker names |
| Url | string | Direct URL to recording |

## Architecture

```
Connect-GoogleRecorder
  └─ PlaywrightAuth (.NET 10 console app)
       └─ Microsoft.Playwright → Chrome (persistent profile)
       └─ Outputs JSON: { cookieHeader, apiKey, email, baseUrl }
  └─ Session stored in $script:RecorderSession + recorder-session.json

Get-GoogleRecording
  └─ Invoke-RecorderRpc (private)
       ├─ Get-SapisIdHash → Authorization: SAPISIDHASH header
       ├─ New-RecorderWebSession → CookieContainer
       └─ Invoke-WebRequest + ConvertFrom-Json
  └─ Format-RawRecording (private)
       ├─ ConvertFrom-ProtoTimestamp
       └─ Format-RecorderDuration
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
