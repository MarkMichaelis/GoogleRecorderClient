# Voiceprint Speaker Identification — Design

**Date:** 2026-02-19
**Status:** Approved

## Problem

Google Recorder labels all speakers as "Speaker X" by default. Users manually rename
speakers in some recordings, but new recordings start fresh with generic labels. There
is no way to carry speaker identities across recordings.

## Goal

Use audio from recordings where speakers have been manually named to build local voice
fingerprints. Automatically identify unnamed speakers in new recordings by comparing
their voice against the fingerprint database, then rename them via the API.

## Architecture

```
                        ┌─────────────────┐
  Recordings with       │  1. Download     │     ┌──────────────┐
  named speakers   ───► │     audio +      │ ──► │ 2. Python:   │
  (reference)           │     AudioTag     │     │   extract    │
                        │     timeline     │     │   segments,  │
                        └─────────────────┘     │   compute    │
                                                │   embeddings │
                                                └──────┬───────┘
                                                       │
                                                       ▼
                                              ┌────────────────┐
                                              │ 3. Voiceprint  │
                                              │    Database    │
                                              │  (local JSON)  │
                                              └────────┬───────┘
                                                       │
                        ┌─────────────────┐            │
  New recording with    │  4. Download     │            │
  "Speaker X" labels ─► │     audio +      │ ──► Compare embeddings
                        │     AudioTag     │     ──► Match results
                        └─────────────────┘     ──► Rename via API
```

### Separation of Concerns

- **PowerShell** — API interaction, database management, orchestration, user-facing cmdlets.
- **Python** — Audio processing only: extract segments, compute embeddings, compare vectors.

The Python script is a thin compute helper; all logic lives in PowerShell.

## Cmdlets

### `Register-GoogleRecorderVoiceprint`

Builds/updates the voiceprint database from recordings with named speakers.

```
Register-GoogleRecorderVoiceprint [-RecordingId <string>] [-Title <string>]
```

1. Gets recording metadata (speaker names + IDs).
2. Gets AudioTag timeline (when each speaker is active).
3. Downloads audio to a temp file.
4. Calls Python: compute embedding for each named speaker's segments.
5. Stores embeddings in the voiceprint database.
6. Skips unnamed "Speaker X" entries.
7. If a speaker already exists, averages the new embedding with the existing one
   (more samples = better accuracy).

**Output:** Summary of which speakers were registered/updated.

### `Find-GoogleRecordingSpeaker`

Identifies unnamed speakers by comparing against the voiceprint database (read-only).

```
Find-GoogleRecordingSpeaker [-RecordingId <string>] [-Title <string>] [-Threshold <double>]
```

1. Gets recording metadata — identifies speakers still named "Speaker X".
2. Gets AudioTag timeline for unnamed speakers.
3. Downloads audio to a temp file.
4. Calls Python: compute embedding for each unnamed speaker.
5. Compares each embedding against the voiceprint database (cosine similarity).
6. Returns matches above the threshold (default: 0.75).

**Output:** Objects with `SpeakerId`, `CurrentName`, `MatchedName`, `Confidence`.

Does NOT rename — read-only so the user can review.

### `Update-GoogleRecordingSpeaker`

Applies matches by renaming speakers via the API.

```
Find-GoogleRecordingSpeaker 'My Meeting' | Update-GoogleRecordingSpeaker [-WhatIf]
```

1. Takes match objects from `Find-GoogleRecordingSpeaker` as pipeline input.
2. Calls `Rename-GoogleRecordingSpeaker` (EditingService) for each match.
3. Supports `-WhatIf` / `-Confirm`.

### End-to-End Workflow

```powershell
# One-time: build voiceprints from recordings you've already labeled
Get-GoogleRecording -First 20 | Register-GoogleRecorderVoiceprint

# For a new recording: identify and rename
Find-GoogleRecordingSpeaker 'Today''s Meeting'
# Review the output, then:
Find-GoogleRecordingSpeaker 'Today''s Meeting' | Update-GoogleRecordingSpeaker
```

### Finding Recordings with Unnamed Speakers

No dedicated cmdlet — use existing tools:

```powershell
Get-GoogleRecording -First 50 | Where-Object { $_.Speakers -match '^Speaker \d+$' }
```

## Voiceprint Database

- Location: `~/.google-recorder/voiceprints.json`
- Format:
  ```json
  {
    "Elisabeth": { "embedding": [0.12, -0.34, ...], "sampleCount": 3 },
    "Mark": { "embedding": [0.56, 0.78, ...], "sampleCount": 1 }
  }
  ```
- `sampleCount` tracks how many recordings contributed (for weighted averaging).

## Python Helper Script

Location: `src/GoogleRecorderClient/Scripts/voiceprint.py`

### Command: `embed`

```bash
python voiceprint.py embed --audio recording.m4a --segments segments.json
```

Input `segments.json`:
```json
{
  "speakers": {
    "1": { "name": "Elisabeth", "ranges": [[3169, 5400], [12000, 15000]] },
    "2": { "name": "Speaker 2", "ranges": [[5400, 8000]] }
  }
}
```

Output (stdout JSON): speaker name → 256-dimensional d-vector embedding.

### Command: `compare`

```bash
python voiceprint.py compare --unknown unknown.json --database voiceprints.json
```

Output (stdout JSON): array of `{ speakerId, currentName, matchedName, confidence }`.

### Audio Segment Extraction

Uses `ffmpeg` via subprocess to extract time ranges from m4a. Concatenates all ranges
for a speaker into one clip, feeds to `resemblyzer` for embedding.

Minimum audio threshold: **3 seconds** of total speech per speaker. Below that, returns
`null` and PowerShell warns the user.

## Dependencies

| Dependency | Purpose | Install |
|---|---|---|
| Python 3.8+ | Runtime | System |
| `resemblyzer` | Speaker embeddings (d-vector model) | `pip install resemblyzer` |
| `numpy` | Vector math (pulled by resemblyzer) | Automatic |
| `ffmpeg` | Audio segment extraction | System (winget/brew/apt) |

### Dependency Validation

Private helper `Assert-VoiceprintDependencies` runs before any voiceprint cmdlet:
1. Checks `python --version` (or `python3`).
2. Checks `ffmpeg -version`.
3. Checks `python -c "import resemblyzer"`.

Errors are actionable: "FFmpeg not found. Install with: winget install ffmpeg".

## Error Handling

- Python exits non-zero on failure; stderr contains the error.
- PowerShell reads stderr and throws a descriptive error.
- Temp audio files cleaned up in `finally` blocks.
- Resemblyzer model auto-downloads on first use (~50 MB, one-time).

## Testing Strategy

### Unit Tests (Pester)

| Test File | What It Tests |
|---|---|
| `Register-GoogleRecorderVoiceprint.Tests.ps1` | Mocks API + Python; verifies segments JSON from AudioTag; verifies DB write/update; verifies unnamed "Speaker X" entries are skipped |
| `Find-GoogleRecordingSpeaker.Tests.ps1` | Mocks API + Python; verifies threshold filtering; verifies output properties; verifies already-named speakers excluded from matching |
| `Update-GoogleRecordingSpeaker.Tests.ps1` | Mocks `Rename-GoogleRecordingSpeaker`; verifies pipeline input; verifies `-WhatIf` |
| `Assert-VoiceprintDependencies.Tests.ps1` | Mocks dependency checks; verifies actionable error messages |
| `Invoke-VoiceprintScript.Tests.ps1` | Mocks Python subprocess; verifies JSON round-trip, error handling, temp file cleanup |

### Python Tests (pytest)

| Test File | What It Tests |
|---|---|
| `tests/python/test_voiceprint_embed.py` | Embedding extraction with synthetic WAV; output shape (256-d); min-duration threshold returns null |
| `tests/python/test_voiceprint_compare.py` | Cosine similarity; identical embeddings → 1.0; orthogonal → ~0.0; output JSON format |

### Functional Test (Pester)

`tests/functional/Voiceprint.Tests.ps1`:

**Cross-recording speaker identification:**
- Recording A has "Elisabeth" (named) and "Speaker 2" (unnamed).
- Recording B has "Speaker 1" (unnamed) and "Speaker 2" (unnamed).
- Elisabeth in A is the same person as Speaker 1 in B.
- Register voiceprints from Recording A → only "Elisabeth" is registered.
- Find matches in Recording B → Speaker 1 matched to "Elisabeth" with confidence > 0.75.

**Unnamed speaker detection:**
- Verify recordings with all-unnamed speakers produce no registrations from `Register-*`.
- Verify `Find-*` correctly identifies which speakers need matching.

Requires Python + ffmpeg installed. Tagged to run only when dependencies are available.

## Implementation Tasks

1. **`Assert-VoiceprintDependencies`** — private helper for dependency checks.
2. **`Invoke-VoiceprintScript`** — private helper to call Python, handle JSON I/O, temp files.
3. **`voiceprint.py`** — Python script with `embed` and `compare` commands.
4. **`Register-GoogleRecorderVoiceprint`** — public cmdlet.
5. **`Find-GoogleRecordingSpeaker`** — public cmdlet.
6. **`Update-GoogleRecordingSpeaker`** — public cmdlet.
7. **Module registration** — export new cmdlets in `.psd1`.
8. **Product spec update** — document new features.

## Out of Scope

- Dedicated `-HasUnnamedSpeakers` switch on `Get-GoogleRecording` (use `Where-Object` pattern).
- Cloud-based speaker recognition (Azure, etc.).
- Real-time / streaming identification.
