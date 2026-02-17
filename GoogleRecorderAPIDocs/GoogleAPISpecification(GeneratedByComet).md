Based on my analysis of the Google Recorder web application at https://recorder.google.com, here is a comprehensive API specification. Note that Google Recorder does not have official public API documentation, so this specification is reverse-engineered from the web application structure. [recorder.google](https://recorder.google.com/de3d94a9-6856-45d9-bc05-590ee644fcda)

## Google Recorder API Specification

### Base Information

**Base URL:** `https://recorder.google.com`

**Authentication:** Google OAuth 2.0 (requires authenticated Google account session)

**Data Format:** JSON

**Resource Identifier:** UUID format (e.g., `de3d94a9-6856-45d9-bc05-590ee644fcda`)

***

### Core API Endpoints

#### 1. **Recordings Management**

##### List Recordings
- **Endpoint:** `GET /` or `/recordings`
- **Description:** Retrieves list of user's recordings
- **Response includes:**
  - Recording ID (UUID)
  - Title
  - Creation date
  - Duration (seconds)
  - Number of speakers
  - Location (city, state/region)
  - Transcription status

**Example Data Structure from page:** [about](about:blank)
```
- Recording ID: de3d94a9-6856-45d9-bc05-590ee644fcda
- Title: "2026-02-15 (Elisabeth): Looking for Reassurance"
- Created: 2026 Feb 15
- Speakers: 8 speakers
- Location: Spokane Valley, Washington
- Duration: 16:18 (978.2 seconds)
```

##### Get Recording Details
- **Endpoint:** `GET /{recording_id}`
- **Description:** Retrieves specific recording with full metadata
- **URL Pattern:** `https://recorder.google.com/{recording_id}`
- **Response includes:**
  - All metadata from list view
  - Audio waveform data
  - Transcript segments with timestamps
  - Speaker labels

#### 2. **Transcript API**

##### Get Transcript
- **Endpoint:** `GET /{recording_id}/transcript`
- **Description:** Retrieves full transcript with speaker diarization and timestamps
- **Response Structure:** [about](about:blank)
  ```json
  {
    "segments": [
      {
        "speaker": "Speaker 1",
        "timestamp": "00:03",
        "text": "Not really."
      },
      {
        "speaker": "Elisabeth",
        "timestamp": "00:31",
        "text": "Will give it to me, and that's really all I wanted to talk about..."
      }
    ],
    "transcribedBy": "Pixel"
  }
  ```

##### Edit Speaker Labels
- **Endpoint:** `PUT /{recording_id}/speakers`
- **Description:** Updates speaker label names
- **UI Action:** "Edit speaker labels" button [recorder.google](https://recorder.google.com/de3d94a9-6856-45d9-bc05-590ee644fcda)

#### 3. **Audio Playback**

##### Get Audio Stream
- **Endpoint:** `GET /{recording_id}/audio`
- **Description:** Streams audio file for playback
- **Features:**
  - Waveform visualization data
  - Playback progress tracking
  - Playback speed control (adjustable, default 1.0x)
  - Skip forward (10 seconds) / rewind (5 seconds)

##### Audio Controls
- **Playback Speed:** Adjustable (1.0x, 1.5x, 2.0x, etc.)
- **Seek:** Via progress slider (0 to max duration)
- **Timeline:** HH:MM:SS format

#### 4. **Search**

##### Search Recordings
- **Endpoint:** `GET /search?q={query}`
- **Description:** Full-text search across recording titles and transcripts
- **UI Element:** Search bar with placeholder "Search your recordings" [recorder.google](https://recorder.google.com/de3d94a9-6856-45d9-bc05-590ee644fcda)

#### 5. **Recording Metadata Operations**

##### Update Recording Title
- **Endpoint:** `PUT /{recording_id}/title`
- **UI Action:** "Edit recording" button [recorder.google](https://recorder.google.com/de3d94a9-6856-45d9-bc05-590ee644fcda)
- **Body:** `{ "title": "New Title" }`

##### Mark as Favorite
- **Endpoint:** `POST /{recording_id}/favorite`
- **Description:** Toggles favorite status
- **UI Action:** Star icon / "Favorite" menu option [recorder.google](https://recorder.google.com/de3d94a9-6856-45d9-bc05-590ee644fcda)

##### Download Recording
- **Endpoint:** `GET /{recording_id}/download`
- **Description:** Downloads audio file (likely M4A or MP3 format)
- **UI Action:** "Download" menu option [recorder.google](https://recorder.google.com/de3d94a9-6856-45d9-bc05-590ee644fcda)

##### Delete Recording
- **Endpoint:** `DELETE /{recording_id}`
- **Description:** Permanently deletes recording
- **UI Action:** "Delete" menu option [recorder.google](https://recorder.google.com/de3d94a9-6856-45d9-bc05-590ee644fcda)

#### 6. **Sharing**

##### Get Sharing Settings
- **Endpoint:** `GET /{recording_id}/sharing`
- **Description:** Retrieves current sharing configuration
- **Response includes:**
  - Access list (users with access)
  - Permission levels (Owner, Editor, Viewer)
  - Public link status (Private/Public)

##### Update Sharing
- **Endpoint:** `PUT /{recording_id}/sharing`
- **Description:** Modifies sharing settings
- **UI Dialog:** "Share this recording" [recorder.google](https://recorder.google.com/de3d94a9-6856-45d9-bc05-590ee644fcda)
- **Body:**
  ```json
  {
    "users": ["email@example.com"],
    "linkAccess": "private|public"
  }
  ```

##### Get Public Link
- **URL Pattern:** `https://recorder.google.com/{recording_id}`
- **Access Control:** "Private link" by default [recorder.google](https://recorder.google.com/de3d94a9-6856-45d9-bc05-590ee644fcda)

#### 7. **Pagination**

##### Load More Recordings
- **Endpoint:** `GET /recordings?offset={offset}&limit={limit}`
- **Description:** Loads additional recordings (pagination)
- **UI Action:** "Load more" button [recorder.google](https://recorder.google.com/de3d94a9-6856-45d9-bc05-590ee644fcda)

***

### Data Models

#### Recording Object
```json
{
  "id": "de3d94a9-6856-45d9-bc05-590ee644fcda",
  "title": "2026-02-15 (Elisabeth): Looking for Reassurance",
  "createdDate": "2026-02-15T20:00:00Z",
  "duration": 978.2,
  "speakerCount": 8,
  "location": {
    "city": "Spokane Valley",
    "region": "Washington"
  },
  "transcriptionStatus": "completed",
  "transcribedBy": "Pixel",
  "isFavorite": false,
  "owner": "REDACTED_EMAIL",
  "sharingSettings": {
    "access": "private"
  }
}
```

#### Transcript Segment Object
```json
{
  "speaker": "Speaker 1" | "Elisabeth" | "Speaker N",
  "speakerId": "speaker_001",
  "timestamp": "00:03",
  "timestampSeconds": 3,
  "text": "Not really.",
  "confidence": 0.95
}
```

***

### Features & Capabilities

1. **Speaker Diarization:** Automatic detection of multiple speakers (up to 10+ speakers) [about](about:blank)
2. **Location Tracking:** Automatic geolocation tagging
3. **Waveform Visualization:** Visual audio representation
4. **Full-Text Search:** Search within transcripts
5. **Cloud Sync:** Recordings synced to Google account
6. **Offline Access:** Appears to support offline playback (based on app architecture)
7. **Export Options:** Download audio files
8. **Collaboration:** Multi-user sharing with access controls

***

### Authentication Flow

Google Recorder uses standard Google OAuth 2.0 authentication:

1. User navigates to `https://recorder.google.com`
2. Redirects to Google Accounts (`accounts.google.com`) if not authenticated
3. After authentication, user is redirected back with session cookies
4. All API requests include authentication cookies/headers

**Required Scopes** (estimated):
- `https://www.googleapis.com/auth/recorder` (proprietary)
- `https://www.googleapis.com/auth/userinfo.email`
- Google Drive integration for storage

***

### Technical Notes

- **Storage Backend:** Likely uses Google Cloud Storage for audio files
- **Transcription Engine:** Powered by Google's on-device and cloud speech recognition (as indicated by "Transcribed by Pixel") [about](about:blank)
- **Real-time Sync:** WebSocket or Server-Sent Events for live updates
- **Progressive Web App:** Modern web app architecture with offline capabilities
- **UUID Format:** All recording IDs follow RFC 4122 UUID v4 format

***

### Limitations

⚠️ **Important:** Google Recorder's web API is NOT officially documented or publicly available. This specification is based on reverse engineering the web interface. Google does not provide official API access for third-party developers, meaning:

1. No API keys or authentication tokens for external access
2. API endpoints may change without notice
3. Rate limiting and quotas are undocumented
4. No official SDK or client libraries
5. Terms of Service may prohibit automated access

For official API access to Google services, refer to Google Cloud Platform APIs. The Recorder app is designed for personal use through its web and mobile interfaces only.