Based on the visual data and functionality observed in the Google Recorder web interface, I have reverse-engineered a conceptual API specification.

**⚠️ Important Note:** Google Recorder does not currently offer a public, documented API. The specification below is a **hypothetical reconstruction** based on the data structures visible in the UI. To build a working extension, you will likely need to inspect the actual network traffic (using Chrome DevTools) to confirm endpoint names (which often use Google's internal `batchexecute` protocol or Protobufs) or use DOM scraping/injection.

### **Base URL**

`https://recorder.google.com/_/RecorderWebUi` (Hypothetical internal root)

### **Authentication**

* **Type:** Session-based (Cookies)
* **Mechanism:** The extension would likely need to rely on the user's active Google session cookies (`__Secure-3PSID`, etc.) or an OAuth 2.0 token with appropriate scopes if available.

---

### **Resources & Endpoints**

#### **1. Recordings List**

Retrieves the sidebar list of recordings with metadata.

* **Endpoint:** `GET /recordings`
* **Parameters:**
* `limit` (int): Number of items to return (e.g., 50).
* `pageToken` (string): For pagination.


* **Response:**
```json
{
  "recordings": [
    {
      "id": "de3d94a9-6856-45d9-bc05-590ee644fcda",
      "title": "2026-02-15 (Elisabeth): Looking for Reassurance",
      "created_at": "2026-02-15T16:18:00Z",
      "duration_ms": 978000,
      "speaker_count": 8,
      "location": {
        "name": "Spokane Valley, Washington",
        "lat": 47.67,
        "long": -117.24
      },
      "preview_text": "Not really. Is this something you'd like to talk about?..."
    },
    {
      "id": "uuid-for-second-recording",
      "title": "2026-02-01 (Elisabeth) - Mark Being Fully Present",
      "created_at": "2026-02-01T03:44:00Z",
      "speaker_count": 3
    }
  ],
  "nextPageToken": "abc123xyz"
}

```



#### **2. Get Recording Details (Transcript & Audio)**

Retrieves the full data for a specific recording ID found in the URL.

* **Endpoint:** `GET /recordings/{recordingId}`
* **Example Call:** `GET /recordings/de3d94a9-6856-45d9-bc05-590ee644fcda`
* **Response:**
```json
{
  "id": "de3d94a9-6856-45d9-bc05-590ee644fcda",
  "metadata": {
    "title": "2026-02-15 (Elisabeth): Looking for Reassurance",
    "date_recorded": "2026-02-15",
    "location": "Spokane Valley, Washington"
  },
  "media": {
    "audio_url": "https://recorder.google.com/playback/blob/de3d94a9...",
    "waveform_data": [0.1, 0.5, 0.2, 0.8, ...] // Array of amplitudes for the visualizer
  },
  "transcript": [
    {
      "timestamp_ms": 3000,
      "display_time": "00:03",
      "speaker_id": "Speaker 1",
      "speaker_label": "Speaker 1",
      "text": "Not really."
    },
    {
      "timestamp_ms": 23000,
      "display_time": "00:23",
      "speaker_id": "Speaker 1",
      "speaker_label": "Speaker 1",
      "text": "Is this something you'd like to talk about?"
    },
    {
      "timestamp_ms": 31000,
      "display_time": "00:31",
      "speaker_id": "Speaker 2",
      "speaker_label": "Elisabeth",
      "text": "Will give it to me, and that's really all I wanted to talk about. I need reassurance because I feel like."
    }
  ],
  "speakers": {
    "Speaker 1": { "color": "#HEXCODE", "is_user": true },
    "Speaker 2": { "color": "#HEXCODE", "name": "Elisabeth" }
  }
}

```



#### **3. Search Recordings**

Performs a search query against the transcript content.

* **Endpoint:** `GET /search`
* **Parameters:**
* `q` (string): Search query (e.g., "reassurance").


* **Response:**
```json
{
  "results": [
    {
      "recordingId": "de3d94a9-6856-45d9-bc05-590ee644fcda",
      "snippet": "I've asked for **reassurance**. You will give it to me...",
      "timestamp_ms": 29000
    }
  ]
}

```



---

### **Data Models**

**`RecordingSummary`**
| Field | Type | Description |
| :--- | :--- | :--- |
| `id` | UUID | Unique identifier (e.g., from URL) |
| `title` | String | User-defined title or auto-generated date |
| `date` | ISO8601 | Date of recording |
| `speakers` | Integer | Number of distinct speakers detected |

**`TranscriptSegment`**
| Field | Type | Description |
| :--- | :--- | :--- |
| `timestamp` | String | Format `MM:SS` or milliseconds |
| `speaker` | String | Label (e.g., "Elisabeth", "Speaker 1") |
| `content` | String | The actual transcribed text |

---
