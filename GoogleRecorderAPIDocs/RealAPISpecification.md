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
| `firstPartyApiUrl` | Base URL for all PlaybackService RPCs |
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

**RPC pattern:**
```
POST /$rpc/java.com.google.wireless.android.pixel.recorder.protos.PlaybackService/{MethodName}
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

### 4.9 Monitoring / Analytics

The web app sends monitoring pings for telemetry. These are **not required** for data access.

#### 4.9.1 API Call Monitoring

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

#### 4.9.2 Page View Monitoring

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
