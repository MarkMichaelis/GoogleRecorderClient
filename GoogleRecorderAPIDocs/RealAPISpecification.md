# Google Recorder — Real API Specification (Reverse-Engineered from HAR)

> **Source:** Captured from `recorder.google.com` network traffic (February 2026).
> **Protocol:** gRPC-Web over HTTP/2+ with `application/json+protobuf` payloads.

---

## 1. Client Configuration

Before calling any data API, the web app fetches runtime configuration.

| Field | Value |
|---|---|
| **Endpoint** | `GET https://recorder.google.com/clientconfig` |
| **Auth** | Google session cookies (browser) |
| **Response prefix** | `)]}'\n` (Google anti-XSSI prefix — strip before parsing JSON) |

### Response Body

```json
{
  "apiKey": "<REDACTED — fetched at runtime from /clientconfig>",
  "email": "<user-email>",
  "firstPartyApiUrl": "https://pixelrecorder-pa.clients6.google.com",
  "fileDownloadUrl": "https://pixelrecorder-pa.googleapis.com"
}
```

| Field | Purpose |
|---|---|
| `apiKey` | Sent as `x-goog-api-key` header on every RPC call |
| `firstPartyApiUrl` | Base URL for all PlaybackService and EditingService RPCs |
| `fileDownloadUrl` | Base URL for raw audio file downloads |

---

## 2. Authentication & Required Headers

All RPC calls share the same header set. Authentication is session-cookie–based.

### Required Headers

| Header | Value | Notes |
|---|---|---|
| `Content-Type` | `application/json+protobuf` | Not regular JSON |
| `Origin` | `https://recorder.google.com` | CORS |
| `Referer` | `https://recorder.google.com/` | CORS |
| `x-goog-api-key` | *(from clientconfig)* | API key |
| `x-goog-authuser` | `0` | Google account index |
| `x-user-agent` | `grpc-web-javascript/0.1` | gRPC-Web identifier |

### Browser-Specific Headers (observed but may not be required)

| Header | Value |
|---|---|
| `x-browser-channel` | `stable` |
| `x-browser-copyright` | `Copyright 2026 Google LLC. All Rights reserved.` |
| `x-browser-validation` | `mbKdpV8Df6MeX3t+QoahfSgokv4=` |
| `x-browser-year` | `2026` |
| `x-client-data` | *(base64-encoded Chrome client data)* |

### Cookie Authentication

The API authenticates via Google session cookies set on `*.google.com`. Key cookies include:
- `SID`, `HSID`, `SSID`, `APISID`, `SAPISID`
- `__Secure-1PSID`, `__Secure-3PSID`
- `__Secure-1PAPISID`, `__Secure-3PAPISID`

These are set when the user logs in at `accounts.google.com` and are sent automatically by the browser for same-site requests to `*.clients6.google.com`.

---

## 3. RPC Base URL & Pattern

**Base URL:** `https://pixelrecorder-pa.clients6.google.com`

**PlaybackService RPC pattern:**
```
POST /$rpc/java.com.google.wireless.android.pixel.recorder.protos.PlaybackService/{MethodName}
```

**EditingService RPC pattern:**
```
POST /$rpc/java.com.google.wireless.android.pixel.recorder.sharedclient.audioediting.protos.EditingService/{MethodName}
```

**Response format:** `application/json+protobuf; charset=UTF-8`

All request/response bodies are JSON arrays that map to protobuf field positions (not named fields).

---

## 4. API Methods

### 4.1 GetRecordingList

Retrieves a paginated list of the user's recordings.

| Field | Value |
|---|---|
| **Method** | `POST` |
| **Path** | `/$rpc/java.com.google.wireless.android.pixel.recorder.protos.PlaybackService/GetRecordingList` |

#### Request Body

```json
[[timestamp_seconds, timestamp_nanos], page_size]
```

| Index | Type | Description |
|---|---|---|
| `[0]` | `[int, int]` | Cursor timestamp: `[unix_seconds, nanoseconds]`. First call uses current time. Subsequent calls use the `created_at` of the last recording from the previous page. |
| `[1]` | `int` | Page size (observed: `10`) |

**First-page example:** `[[1771308476,693000000],10]`
**Second-page example:** `[[1769552393,168000000],10]` *(last recording's created_at from page 1)*

#### Response Body

```json
[
  [
    [recording_1],
    [recording_2],
    ...
  ],
  has_more
]
```

| Index | Type | Description |
|---|---|---|
| `[0]` | `array` | Array of recording arrays |
| `[1]` | `int` | `1` if more pages available (absent/omitted if no more) |

#### Recording Array Structure (each item in the list)

| Index | Type | Description | Example |
|---|---|---|---|
| `[0]` | `string` | Internal UUID | `"fad92ac5-2ed3-489a-bc27-268e3c5d4a92"` |
| `[1]` | `string` | Title | `"2026-02-15 (Elisabeth): Looking for Reassurance"` |
| `[2]` | `[string, int]` | Created timestamp `[unix_seconds_str, nanos]` | `["1771181693", 323000000]` |
| `[3]` | `[string, int]` | Duration `[seconds_str, nanos]` | `["978", 200000000]` |
| `[4]` | `float` | Latitude | `47.6290925` |
| `[5]` | `float` | Longitude | `-117.2159544` |
| `[6]` | `string` | Location name | `"Spokane Valley, Washington"` |
| `[7]` | `null` | *(unknown)* | |
| `[8]` | `array` | Audio config: `[codec, mime, sampleRate, channels, bitrate, ...]` | `[2,"audio/mp4a-latm",48000,1,128000,4800,2,10]` |
| `[9]` | `array\|null` | Tags (AI-extracted topics) | `[[["Ai",15.683,"TagsExtractor"],...]]` |
| `[10]` | `array` | Speaker segment timestamps | `[[[106,1],[163,0],...]]` |
| `[11]` | `string` | Secondary UUID | `"6f7e5af0-4bf0-40ca-afef-f209c3f65921"` |
| `[12]` | `null` | *(unknown)* | |
| `[13]` | `string` | **Recording ID** (used in URLs and other API calls) | `"de3d94a9-6856-45d9-bc05-590ee644fcda"` |
| `[14]` | `null\|int` | Possibly favorite flag (`1` = favorited) | |
| `[15]` | `null` | *(unknown)* | |
| `[16]` | `null` | *(unknown)* | |
| `[17]` | `null` | *(unknown)* | |
| `[18]` | `int` | Status/version (always `5` in observations) | `5` |
| `[19]` | `int` | Transcription type (`1` = single speaker?, `2` = multi-speaker) | `2` |
| `[20]` | `array` | Speakers: `[[[speaker_num, speaker_name?], ...]]` | `[[[1],[2,"Elisabeth"],[3,"Mark"]]]` |
| `[21]` | `null` | *(unknown)* | |
| `[22]` | `array` | Language segments `[[[lang_code, duration_ms_str]], ...]` | `[[["en-US","338600"]],[["da-DK","3450"]]]` |
| `[23]` | `array` | *(empty array observed)* | `[]` |
| `[24]` | `array` | Summary/stats: `[[[0],[1]], has_summary, has_X, score1, score2]` | `[[[0],[1]],1,1,47.413616,0.55281126]` |

---

### 4.2 GetRecordingInfo

Retrieves full metadata for a single recording.

| Field | Value |
|---|---|
| **Path** | `/$rpc/.../PlaybackService/GetRecordingInfo` |

#### Request Body

```json
["recording_id_uuid"]
```

#### Response Body

```json
[
  [recording_array],   // Same structure as GetRecordingList items
  1,                   // ?(always 1)
  null,
  "https://usercontent.recorder.google.com/download/playback/{recording_id}",
  1
]
```

The recording array is the same structure documented in §4.1, with an appended audio download URL.

**Audio download URL pattern:**
```
https://usercontent.recorder.google.com/download/playback/{recording_id}
```

---

### 4.3 GetTranscription

Retrieves the full word-level transcript for a recording.

| Field | Value |
|---|---|
| **Path** | `/$rpc/.../PlaybackService/GetTranscription` |

#### Request Body

```json
["recording_id_uuid"]
```

#### Response Body

Deeply nested array of transcript segments. Structure:

```
[                           // Root
  [                         // Segments container
    [                       // Segment (one per utterance)
      [                     // Words in this segment
        [
          "word",           // [0] Raw word
          "Word,",          // [1] Formatted word (with punctuation) or null
          "3620",           // [2] Start time (milliseconds, as string)
          "3860",           // [3] End time (milliseconds, as string)
          null,             // [4] Unknown
          null,             // [5] Unknown
          [1, 1]            // [6] [unknown_flag, speaker_id]
        ],
        ...more words
      ]
    ],
    ...more segments
  ]
]
```

Speaker IDs in `[6][1]` map to the speaker numbers in the recording's speakers array.

---

### 4.4 ListLabels

Retrieves all available labels/tags for the user's recordings.

| Field | Value |
|---|---|
| **Path** | `/$rpc/.../PlaybackService/ListLabels` |

#### Request Body

```json
[]
```

#### Response Body

```json
[[["favorite","favorite"]]]
```

Structure: `[[[label_id, label_display_name], ...]]`

---

### 4.5 GetShareList

Retrieves sharing information for a recording.

| Field | Value |
|---|---|
| **Path** | `/$rpc/.../PlaybackService/GetShareList` |

#### Request Body

```json
["recording_id_uuid"]
```

#### Response Body

```json
[]
```

Empty array if no shares exist.

---

### 4.6 GetAudioTag

Retrieves speaker-activity timeline with amplitude data for a recording. Each entry represents a speaker's audio activity at a particular timestamp with its amplitude.

| Field | Value |
|---|---|
| **Path** | `/$rpc/.../PlaybackService/GetAudioTag` |

#### Request Body

```json
["recording_id_uuid"]
```

#### Response Body

Array of speaker-activity tuples:

```json
[
  [
    [speaker_id, "timestamp_ms_str", amplitude_float],
    [speaker_id, "timestamp_ms_str", amplitude_float],
    ...
  ]
]
```

| Tuple Index | Type | Description |
|---|---|---|
| `[0]` | `int` | Speaker ID (`0` = silence/gap, `1`+ = active speaker) |
| `[1]` | `string` | Timestamp in milliseconds (as string) |
| `[2]` | `float` | Amplitude (`0.0` for silence, `0.0–1.0` for speech) |

**Example entries:**
```json
[0,"0",0]           // Silence at 0 ms
[1,"3169",0.052]    // Speaker 1 at 3169 ms, amplitude 0.052
[2,"5400",0.12]     // Speaker 2 at 5400 ms, amplitude 0.12
```

Speaker IDs correspond to the speaker numbers in the recording's speakers array (`[20]`).

---

### 4.7 GetWaveform

Retrieves waveform amplitude samples for audio visualization. Returns a large array of amplitude values used to render the waveform scrubber in the UI.

| Field | Value |
|---|---|
| **Path** | `/$rpc/.../PlaybackService/GetWaveform` |

#### Request Body

```json
["recording_id_uuid"]
```

#### Response Body

Large array of waveform amplitude samples (observed response size: ~78 KB uncompressed):

```json
[
  [
    [amplitude_float, amplitude_float, amplitude_float, ...]
  ]
]
```

Each value is a `float` representing the audio amplitude at evenly-spaced time intervals across the recording duration. Used by the web client to render the waveform timeline.

---

### 4.8 GetGlobalSearchReadiness

Checks whether global search across all recordings is available for the user.

| Field | Value |
|---|---|
| **Path** | `/$rpc/.../PlaybackService/GetGlobalSearchReadiness` |

#### Request Body

```json
[]
```

*(No parameters — empty array.)*

#### Response Body

```json
[1]
```

| Index | Type | Description |
|---|---|---|
| `[0]` | `int` | `1` = search is ready/available, absent or `0` = not ready |

---

### 4.9 UpdateRecordingTitle

Renames a recording by setting a new title.

| Field | Value |
|---|---|
| **Path** | `/$rpc/.../PlaybackService/UpdateRecordingTitle` |

#### Request Body

```json
["recording_id_uuid", "New Title"]
```

| Index | Type | Description |
|---|---|---|
| `[0]` | `string` | Recording ID (index `[13]` from recording array) |
| `[1]` | `string` | New title |

#### Response Body

Empty on success. Throws gRPC error on failure.

---

### 4.10 UpdateRecordingLabels

Adds or removes labels (e.g. "favorite") on a recording.

| Field | Value |
|---|---|
| **Path** | `/$rpc/.../PlaybackService/UpdateRecordingLabels` |

#### Request Body

```json
["recording_id_uuid", {label_map}]
```

| Index | Type | Description |
|---|---|---|
| `[0]` | `string` | Recording ID |
| `[1]` | `map` | Label key → value map. Observed keys: `"favorite"`. Values: `1` = add label, `2` = remove label. |

#### Response Body

```json
[null, [active_labels], [[label_id, label_display_name], ...]]
```

| Index | Type | Description |
|---|---|---|
| `[1]` | `array` | Set of currently-active label IDs on the recording |
| `[2]` | `array` | Full label list (same structure as ListLabels response) |

---

### 4.11 DeleteRecordingList

Deletes one or more recordings.

| Field | Value |
|---|---|
| **Path** | `/$rpc/.../PlaybackService/DeleteRecordingList` |

#### Request Body

```json
[["recording_id_uuid_1", "recording_id_uuid_2", ...]]
```

| Index | Type | Description |
|---|---|---|
| `[0]` | `array<string>` | Array of Recording IDs to delete |

#### Response Body

```json
[status]
```

| Index | Type | Description |
|---|---|---|
| `[0]` | `int` | `1` = success |

---

### 4.12 Search

Performs a global search across all recordings by keyword.

| Field | Value |
|---|---|
| **Path** | `/$rpc/.../PlaybackService/Search` |

#### Request Body

```json
["search_query", null, null, null, 10]
```

| Index | Type | Description |
|---|---|---|
| `[0]` | `string` | Search query text |
| `[4]` | `int` | Page size (observed: `10`) |

Additional optional fields: timestamp filter (`[1]`), label filter (`[6]`), sort order (`[7]`).

The `Search` method is also registered on a separate search-specific client prototype (`QJ.prototype.search`), but the RPC path and payload format are the same.

#### Response Body

Array of matching recording results with highlighted transcript matches.

---

### 4.13 SingleRecordingSearch

Searches within a single recording's transcript.

| Field | Value |
|---|---|
| **Path** | `/$rpc/.../PlaybackService/SingleRecordingSearch` |

#### Request Body

```json
["recording_id_uuid", "search_query"]
```

| Index | Type | Description |
|---|---|---|
| `[0]` | `string` | Recording ID |
| `[1]` | `string` | Search query text |

Optional fields: timestamp filter (`[3]`), label filter (`[4]`).

#### Response Body

Array of matching transcript segments within the recording.

---

### 4.14 ChangeShareState

Changes the sharing visibility state of a recording (e.g. enabling/disabling link sharing).

| Field | Value |
|---|---|
| **Path** | `/$rpc/.../PlaybackService/ChangeShareState` |

#### Request Body

```json
["recording_id_uuid", state]
```

| Index | Type | Description |
|---|---|---|
| `[0]` | `string` | Recording ID |
| `[1]` | `int` | Share state: `1` = enable sharing, `2` = disable sharing |

#### Response Body

```json
[state]
```

| Index | Type | Description |
|---|---|---|
| `[0]` | `int` | `2` = confirmed state change |

---

### 4.15 WriteShareList

Creates or updates sharing settings (recipients, permissions) for a recording.

| Field | Value |
|---|---|
| **Path** | `/$rpc/.../PlaybackService/WriteShareList` |

#### Request Body

```json
["recording_id_uuid", [recipients], visibility, extra_field]
```

| Index | Type | Description |
|---|---|---|
| `[0]` | `string` | Recording ID |
| `[1]` | `array` | Array of recipient objects, each containing `[null, null, email, access_level]` where `access_level` is `2` (observed). |
| `[2]` | *(unknown)* | Visibility / permission level |
| `[3]` | *(unknown)* | Additional sharing parameter |

#### Response Body

Returns updated share list (same structure as `GetShareList` when populated).

---

### 4.16 BlockPerson

Blocks a person from accessing a shared recording.

| Field | Value |
|---|---|
| **Path** | `/$rpc/.../PlaybackService/BlockPerson` |

#### Request Body

```json
["share_id", "recording_id_uuid"]
```

| Index | Type | Description |
|---|---|---|
| `[0]` | `string` | The share/person identifier to block |
| `[1]` | `string` | Recording ID |

#### Response Body

Confirmation of block operation.

---

### 4.17 Monitoring / Analytics

The web app sends monitoring pings for telemetry. These are **not required** for data access.

#### 4.17.1 API Call Monitoring

| Field | Value |
|---|---|
| **Endpoint** | `POST https://recorder.google.com/api/monitoring/apicall` |
| **Content-Type** | `application/json` |
| **Response** | `204 No Content` |

**Request Body:**
```json
["recorder.monitoring.api", "PlaybackService", "listLabels", "200", 737.5]
```

| Index | Type | Description |
|---|---|---|
| `[0]` | `string` | Event type (always `"recorder.monitoring.api"`) |
| `[1]` | `string` | Service name (e.g., `"PlaybackService"`) |
| `[2]` | `string` | Method name (e.g., `"listLabels"`, `"getRecordingList"`) |
| `[3]` | `string` | HTTP status code (as string) |
| `[4]` | `float` | Request duration in milliseconds |

#### 4.17.2 Page View Monitoring

| Field | Value |
|---|---|
| **Endpoint** | `POST https://recorder.google.com/api/monitoring/pageview` |
| **Content-Type** | `application/json` |
| **Response** | `204 No Content` |

**Request Body:**
```json
["recorder.monitoring.pageview", "/:share_link"]
```

| Index | Type | Description |
|---|---|---|
| `[0]` | `string` | Event type (always `"recorder.monitoring.pageview"`) |
| `[1]` | `string` | Route pattern (e.g., `"/"`, `"/:share_link"`) |

---

## 5. Pagination

The `GetRecordingList` API uses cursor-based pagination:

1. **First request:** Use the current Unix timestamp (seconds + nanos) as the cursor.
2. **Subsequent requests:** Use the `created_at` timestamp (`[2]`) of the **last recording** from the previous page as the cursor.
3. **Detecting end:** When the response's `[1]` value is absent or not `1`, there are no more pages.

---

## 6. Key UUIDs

Each recording has multiple UUIDs:

| Field Index | Name | Purpose |
|---|---|---|
| `[0]` | Internal ID | Internal protobuf identifier |
| `[11]` | Secondary ID | Unknown purpose |
| `[13]` | **Recording ID** | Used in URLs (`recorder.google.com/{id}`) and for all per-recording API calls |

Always use index `[13]` when referencing a recording in API calls like `GetRecordingInfo`, `GetTranscription`, etc.

---

## 7. Audio Download

Audio files can be downloaded from:
```
https://usercontent.recorder.google.com/download/playback/{recording_id}
```

This also requires authenticated session cookies.

---

## 8. EditingService

A separate gRPC service for mutating recording content (audio, transcript, speakers). All editing operations require an active **edit session** — open a session, perform edits, then save and close.

**Service package:** `java.com.google.wireless.android.pixel.recorder.sharedclient.audioediting.protos.EditingService`

**RPC pattern:**
```
POST /$rpc/java.com.google.wireless.android.pixel.recorder.sharedclient.audioediting.protos.EditingService/{MethodName}
```

**Base URL:** Same as PlaybackService — `https://pixelrecorder-pa.clients6.google.com`

**Headers:** Same as PlaybackService (§2).

### 8.1 Edit Session Lifecycle

All editing operations follow this workflow:

1. **OpenSession** — acquire a session ID for the recording's share ID
2. **Perform edits** — RenameSpeaker, SwitchSpeaker, SplitTranscription, CropAudio, RemoveAudio (can be called multiple times; UndoEdit to revert)
3. **SaveAudio** — commit all pending edits
4. **CloseSession** — release the session

If edits are not saved before closing, changes are discarded.

---

### 8.2 OpenSession

Opens an editing session for a recording. Returns a session ID used by all subsequent editing calls.

| Field | Value |
|---|---|
| **Path** | `/$rpc/.../EditingService/OpenSession` |

#### Request Body

```json
["share_id"]
```

| Index | Type | Description |
|---|---|---|
| `[0]` | `string` | The recording's share ID (same as Recording ID, index `[13]`) |

#### Response Body

```json
["session_id"]
```

| Index | Type | Description |
|---|---|---|
| `[0]` | `string` | Session ID (used by all subsequent editing RPCs) |

**Error codes:**
- gRPC code `5` (NOT_FOUND): The share ID does not exist.

---

### 8.3 CloseSession

Closes an editing session, releasing server-side resources. Unsaved changes are discarded.

| Field | Value |
|---|---|
| **Path** | `/$rpc/.../EditingService/CloseSession` |

#### Request Body

```json
["session_id"]
```

| Index | Type | Description |
|---|---|---|
| `[0]` | `string` | Session ID from OpenSession |

#### Response Body

Empty on success.

**Error codes:**
- gRPC code `5`: Session ID expired or does not exist.

---

### 8.4 RenameSpeaker

Renames a speaker label within a recording. Requires an open edit session.

| Field | Value |
|---|---|
| **Path** | `/$rpc/.../EditingService/RenameSpeaker` |

#### Request Body

```json
["session_id", [[[speaker_id], "new_display_name"]]]
```

Nested structure (inferred from JS):

| Level | Description |
|---|---|
| `[0]` | `string` — Session ID |
| `[1]` | Wrapper containing speaker ID and new name |
| `[1][0]` | Speaker identifier object: `[[speaker_id]]` where `speaker_id` is the integer speaker number |
| `[1][1]` | New display name object: `["new_name"]` |

The JS constructs this as:
- Field 1: session ID (string)
- Field 2: rename payload containing:
  - Sub-field 1: speaker ID wrapper (`[[speaker_num]]`) — the speaker number from the recording's speakers array (`[20]`)
  - Sub-field 2: new name wrapper (`["new_display_name"]`)

#### Response Body

Returns the updated speakers list:

```json
[
  [
    [[speaker_id_bytes], "display_name"],
    [[speaker_id_bytes], "display_name"],
    ...
  ]
]
```

Each entry contains the speaker ID and its (possibly updated) display name. Parsed into `{ speakerId, displayName }` objects.

---

### 8.5 SwitchSpeaker

Reassigns a transcript segment to a different speaker. Requires an open edit session.

| Field | Value |
|---|---|
| **Path** | `/$rpc/.../EditingService/SwitchSpeaker` |

#### Request Body

```json
["session_id", [transcript_segment_ids], [target_speaker]]
```

| Level | Description |
|---|---|
| `[0]` | `string` — Session ID |
| `[1]` | Transcript segment identifiers (array of segment positions/IDs to reassign) |
| `[2]` | Target speaker specification — one of: `[[speaker_num]]` (existing speaker by number) or `["new_speaker_name"]` (new speaker by display name) |

#### Response Body

Returns the updated recording data (transcript + metadata) after the speaker switch.

---

### 8.6 SplitTranscription

Splits a transcript segment at a specified position. Requires an open edit session.

| Field | Value |
|---|---|
| **Path** | `/$rpc/.../EditingService/SplitTranscription` |

#### Request Body

```json
["session_id", [split_position_data]]
```

| Index | Type | Description |
|---|---|---|
| `[0]` | `string` | Session ID |
| `[1]` | `array` | Split position within the transcript (segment/word index) |

#### Response Body

Returns updated recording data with the transcript now split at the specified position.

---

### 8.7 CropAudio

Crops the audio to a specified time range, removing content outside the range. Requires an open edit session.

| Field | Value |
|---|---|
| **Path** | `/$rpc/.../EditingService/CropAudio` |

#### Request Body

```json
["session_id", [[start_seconds, start_nanos], [end_seconds, end_nanos]]]
```

| Level | Description |
|---|---|
| `[0]` | `string` — Session ID |
| `[1]` | Crop range containing start and end timestamps as protobuf Duration/Timestamp objects: `[seconds_int, nanoseconds_int]` |

The JS validates that the start time is before the end time before sending.

#### Response Body

Returns updated recording data with audio cropped to the specified range.

---

### 8.8 RemoveAudio

Removes a section of audio from the recording. Requires an open edit session.

| Field | Value |
|---|---|
| **Path** | `/$rpc/.../EditingService/RemoveAudio` |

#### Request Body

```json
["session_id", [[start_seconds, start_nanos], [end_seconds, end_nanos]]]
```

Structure is the same as CropAudio — specifies the time range to **remove**.

#### Response Body

Returns updated recording data with the specified audio section removed.

---

### 8.9 SaveAudio

Commits all pending edits in the current session. This persists the changes.

| Field | Value |
|---|---|
| **Path** | `/$rpc/.../EditingService/SaveAudio` |

#### Request Body

```json
["session_id", [[["title"]], ["recording_id_uuid"]]]
```

| Level | Description |
|---|---|
| `[0]` | `string` — Session ID |
| `[1]` | Save metadata containing the recording title and UUID |

The JS sends the current recording title and UUID so the server can associate the saved edits.

#### Response Body

```json
["new_share_id", status]
```

| Index | Type | Description |
|---|---|---|
| `[0]` | `string` | New share ID (may differ from the original if the recording was re-created) |
| `[1]` | `int` | Status — `2` indicates user storage exceeded |

**Error handling:**
- If `[0]` is empty and `[1]` is `2`: user storage quota exceeded.
- Session ID expired: `SESSION_ID_EXPIRED` error.

---

### 8.10 UndoEdit

Reverts the last edit operation within the current session. Requires an open edit session.

| Field | Value |
|---|---|
| **Path** | `/$rpc/.../EditingService/UndoEdit` |

#### Request Body

```json
["session_id"]
```

| Index | Type | Description |
|---|---|---|
| `[0]` | `string` | Session ID |

#### Response Body

Returns updated recording data after undoing the last operation.

---

### 8.11 EditingService Method Summary

| Method | Purpose | Mutating |
|---|---|---|
| `OpenSession` | Start an edit session for a recording | No |
| `CloseSession` | End an edit session (discards unsaved changes) | No |
| `RenameSpeaker` | Rename a speaker label | Yes |
| `SwitchSpeaker` | Reassign transcript segments to a different speaker | Yes |
| `SplitTranscription` | Split a transcript segment at a position | Yes |
| `CropAudio` | Crop audio to a time range | Yes |
| `RemoveAudio` | Remove a section of audio | Yes |
| `SaveAudio` | Commit all pending edits | Yes |
| `UndoEdit` | Revert the last edit | Yes |

---

## 9. Complete API Method Index

### PlaybackService Methods

| # | Method | Documented | Purpose |
|---|---|---|---|
| 1 | `GetRecordingList` | §4.1 | Paginated list of recordings |
| 2 | `GetRecordingInfo` | §4.2 | Full metadata for one recording |
| 3 | `GetTranscription` | §4.3 | Word-level transcript |
| 4 | `ListLabels` | §4.4 | Available labels/tags |
| 5 | `GetShareList` | §4.5 | Sharing info for a recording |
| 6 | `GetAudioTag` | §4.6 | Speaker-activity timeline |
| 7 | `GetWaveform` | §4.7 | Waveform amplitude data |
| 8 | `GetGlobalSearchReadiness` | §4.8 | Check if global search is available |
| 9 | `UpdateRecordingTitle` | §4.9 | Rename a recording |
| 10 | `UpdateRecordingLabels` | §4.10 | Add/remove labels |
| 11 | `DeleteRecordingList` | §4.11 | Delete recordings |
| 12 | `Search` | §4.12 | Global keyword search |
| 13 | `SingleRecordingSearch` | §4.13 | Search within one recording |
| 14 | `ChangeShareState` | §4.14 | Enable/disable sharing |
| 15 | `WriteShareList` | §4.15 | Update share recipients |
| 16 | `BlockPerson` | §4.16 | Block a person from a share |

### EditingService Methods

| # | Method | Documented | Purpose |
|---|---|---|---|
| 1 | `OpenSession` | §8.2 | Start editing session |
| 2 | `CloseSession` | §8.3 | End editing session |
| 3 | `RenameSpeaker` | §8.4 | Rename speaker label |
| 4 | `SwitchSpeaker` | §8.5 | Reassign transcript to speaker |
| 5 | `SplitTranscription` | §8.6 | Split transcript segment |
| 6 | `CropAudio` | §8.7 | Crop audio to range |
| 7 | `RemoveAudio` | §8.8 | Remove audio section |
| 8 | `SaveAudio` | §8.9 | Commit edits |
| 9 | `UndoEdit` | §8.10 | Revert last edit |
