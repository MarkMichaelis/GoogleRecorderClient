# EditingService Implementation Plan

**Goal:** Implement PowerShell cmdlets for the Google Recorder EditingService (§8 of RealAPISpecification.md) — session-based editing of speakers, transcript, and audio.

**Architecture:** The EditingService uses a different gRPC service package than PlaybackService. `Invoke-RecorderRpc` must be extended with a `-Service` parameter (defaulting to `PlaybackService`) to support the new RPC path prefix. All editing operations require an open session — a private `Invoke-EditingSessionAction` helper manages the OpenSession → action → SaveAudio → CloseSession lifecycle so individual cmdlets stay simple.

**Tech Stack:** PowerShell (Pester for tests), existing `Invoke-RecorderRpc` infrastructure.

---

## Pre-requisite: Extend Invoke-RecorderRpc for EditingService

### Task 0: Add `-Service` parameter to `Invoke-RecorderRpc`

**Files:**
- Modify: `src/GoogleRecorderClient/Private/Invoke-RecorderRpc.ps1`
- Test: `tests/unit/Private/Invoke-RecorderRpc.Tests.ps1`

**Step 1: Write failing test**
Add test that calls `Invoke-RecorderRpc -Service 'EditingService' -Method 'OpenSession' -Body '["x"]'` and verify the URL uses the EditingService path prefix:
```
/$rpc/java.com.google.wireless.android.pixel.recorder.sharedclient.audioediting.protos.EditingService/OpenSession
```

**Step 2: Run test → FAIL** (no `-Service` parameter exists)

**Step 3: Implement**
Add `[string]$Service = 'PlaybackService'` parameter. Map service names to RPC path prefixes:
```powershell
$rpcPaths = @{
    'PlaybackService' = '/$rpc/java.com.google.wireless.android.pixel.recorder.protos.PlaybackService'
    'EditingService'  = '/$rpc/java.com.google.wireless.android.pixel.recorder.sharedclient.audioediting.protos.EditingService'
}
$rpcPathPrefix = $rpcPaths[$Service]
```

**Step 4: Run test → PASS**

**Step 5: Verify** existing PlaybackService tests still pass (default behavior unchanged).

**Commit:** `feat(rpc): add -Service parameter to Invoke-RecorderRpc for EditingService support`

---

## Cmdlet 1: Rename-GoogleRecordingSpeaker

Renames a speaker label on a recording. Wraps the full edit session lifecycle: OpenSession → RenameSpeaker → SaveAudio → CloseSession.

### Task 1a: Private helper — `Invoke-EditingRpc`

**Files:**
- Create: `src/GoogleRecorderClient/Private/Invoke-EditingRpc.ps1`
- Test: `tests/unit/Private/Invoke-EditingRpc.Tests.ps1`

Thin wrapper that calls `Invoke-RecorderRpc -Service 'EditingService'`. Keeps the public cmdlets from repeating the `-Service` argument.

```powershell
function Invoke-EditingRpc {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][string]$Body
    )
    Invoke-RecorderRpc -Service 'EditingService' -Method $Method -Body $Body
}
```

**Commit:** `feat(editing): add Invoke-EditingRpc private helper`

---

### Task 1b: Public cmdlet — `Rename-GoogleRecordingSpeaker`

**Files:**
- Create: `src/GoogleRecorderClient/Public/Rename-GoogleRecordingSpeaker.ps1`
- Test: `tests/unit/Public/Rename-GoogleRecordingSpeaker.Tests.ps1`

**Parameters:**
| Parameter | Type | Mandatory | Description |
|---|---|---|---|
| `-RecordingId` | string | Yes (ById) | Recording UUID. Pipeline input by property name. |
| `-Title` | string | Yes (ByTitle) | Resolve recording by title/wildcard. Alias: `Name`. |
| `-SpeakerId` | int | Yes | Speaker number from the recording's speakers array. |
| `-NewName` | string | Yes | New display name for the speaker. |

**Behavior:**
1. `Assert-RecorderSession`
2. `ShouldProcess` check (ConfirmImpact = 'Medium')
3. `OpenSession` with RecordingId
4. `RenameSpeaker` with session ID, speaker ID, new name
5. `SaveAudio` with session ID, recording title, recording ID
6. `CloseSession` with session ID (in `finally` block)
7. Return updated speaker list

**API calls (in order):**
```
EditingService/OpenSession       → ["recording_id"]
EditingService/RenameSpeaker     → ["session_id", [[[speaker_id], "new_name"]]]
EditingService/SaveAudio         → ["session_id", [[["title"]], ["recording_id"]]]
EditingService/CloseSession      → ["session_id"]
```

**Step 1: Write failing test** — mock `Invoke-EditingRpc` for all 4 calls, verify correct method names and body payloads.

**Step 2: Run test → FAIL**

**Step 3: Implement the cmdlet**

**Step 4: Run test → PASS**

**Commit:** `feat(speakers): add Rename-GoogleRecordingSpeaker cmdlet`

---

## Cmdlet 2: Set-GoogleRecordingSpeaker (SwitchSpeaker)

Reassigns transcript segments to a different speaker.

### Task 2: Public cmdlet — `Set-GoogleRecordingSpeaker`

**Files:**
- Create: `src/GoogleRecorderClient/Public/Set-GoogleRecordingSpeaker.ps1`
- Test: `tests/unit/Public/Set-GoogleRecordingSpeaker.Tests.ps1`

**Parameters:**
| Parameter | Type | Mandatory | Description |
|---|---|---|---|
| `-RecordingId` | string | Yes (ById) | Recording UUID. |
| `-Title` | string | Yes (ByTitle) | Resolve by title/wildcard. Alias: `Name`. |
| `-SegmentIndex` | int[] | Yes | Transcript segment indices to reassign. |
| `-TargetSpeakerId` | int | Yes (BySpeakerId) | Existing speaker number. |
| `-TargetSpeakerName` | string | Yes (ByNewSpeaker) | Create a new speaker with this name. |

**Behavior:** OpenSession → SwitchSpeaker → SaveAudio → CloseSession.

**Commit:** `feat(speakers): add Set-GoogleRecordingSpeaker cmdlet`

---

## Cmdlet 3: Split-GoogleRecordingTranscript (SplitTranscription)

Splits a transcript segment at a position.

### Task 3: Public cmdlet — `Split-GoogleRecordingTranscript`

**Files:**
- Create: `src/GoogleRecorderClient/Public/Split-GoogleRecordingTranscript.ps1`
- Test: `tests/unit/Public/Split-GoogleRecordingTranscript.Tests.ps1`

**Parameters:**
| Parameter | Type | Mandatory | Description |
|---|---|---|---|
| `-RecordingId` | string | Yes (ById) | Recording UUID. |
| `-Title` | string | Yes (ByTitle) | Resolve by title/wildcard. Alias: `Name`. |
| `-Position` | int[] | Yes | Split position data (segment/word indices). |

**Behavior:** OpenSession → SplitTranscription → SaveAudio → CloseSession.

**Commit:** `feat(transcript): add Split-GoogleRecordingTranscript cmdlet`

---

## Cmdlet 4: Edit-GoogleRecordingAudio — CropAudio

Crops audio to a time range.

### Task 4: Public cmdlet — `Edit-GoogleRecordingAudio` with `-Crop`

**Files:**
- Create: `src/GoogleRecorderClient/Public/Edit-GoogleRecordingAudio.ps1`
- Test: `tests/unit/Public/Edit-GoogleRecordingAudio.Tests.ps1`

**Parameters:**
| Parameter | Type | Mandatory | Description |
|---|---|---|---|
| `-RecordingId` | string | Yes (ById) | Recording UUID. |
| `-Title` | string | Yes (ByTitle) | Resolve by title/wildcard. Alias: `Name`. |
| `-Crop` | switch | Yes (CropSet) | Crop mode — keep audio between Start and End. |
| `-Remove` | switch | Yes (RemoveSet) | Remove mode — delete audio between Start and End. |
| `-Start` | TimeSpan | Yes | Start of the time range. |
| `-End` | TimeSpan | Yes | End of the time range. |

**Behavior:**
- `-Crop`: OpenSession → CropAudio → SaveAudio → CloseSession.
- `-Remove`: OpenSession → RemoveAudio → SaveAudio → CloseSession.

**ConfirmImpact:** `High` (destructive audio edits).

**Commit:** `feat(audio-edit): add Edit-GoogleRecordingAudio cmdlet (Crop/Remove)`

---

## Cmdlet 5: Remove-GoogleRecording (DeleteRecordingList)

Deletes one or more recordings. (Uses PlaybackService, not EditingService — but it's a missing mutating API.)

### Task 5: Public cmdlet — `Remove-GoogleRecording`

**Files:**
- Create: `src/GoogleRecorderClient/Public/Remove-GoogleRecording.ps1`
- Test: `tests/unit/Public/Remove-GoogleRecording.Tests.ps1`

**Parameters:**
| Parameter | Type | Mandatory | Description |
|---|---|---|---|
| `-RecordingId` | string[] | Yes (ById) | One or more recording UUIDs. Pipeline input. |
| `-Title` | string | Yes (ByTitle) | Resolve by title/wildcard. Alias: `Name`. |

**ConfirmImpact:** `High` (permanent deletion).

**API call:** `PlaybackService/DeleteRecordingList` → `[["id1","id2",...]]`

**Commit:** `feat(delete): add Remove-GoogleRecording cmdlet`

---

## Cmdlet 6: Search-GoogleRecording (Search + SingleRecordingSearch)

Global or per-recording keyword search. (Uses PlaybackService.)

### Task 6: Public cmdlet — `Search-GoogleRecording`

**Files:**
- Create: `src/GoogleRecorderClient/Public/Search-GoogleRecording.ps1`
- Test: `tests/unit/Public/Search-GoogleRecording.Tests.ps1`

**Parameters:**
| Parameter | Type | Mandatory | Description |
|---|---|---|---|
| `-Query` | string | Yes | Search keywords. |
| `-RecordingId` | string | No | If specified, search within this recording only (SingleRecordingSearch). |
| `-Title` | string | No (ByTitle) | Resolve by title/wildcard for single-recording search. |
| `-MaxResults` | int | No (default 10) | Maximum results to return. |

**Behavior:**
- Without `-RecordingId`: calls `Search` RPC (global).
- With `-RecordingId`: calls `SingleRecordingSearch` RPC (scoped).

**Commit:** `feat(search): add Search-GoogleRecording cmdlet`

---

## Module Registration

### Task 7: Export new cmdlets and update module manifest

**Files:**
- Modify: `src/GoogleRecorderClient/GoogleRecorderClient.psd1` — add new cmdlets to `FunctionsToExport`.
- Modify: `src/GoogleRecorderClient/GoogleRecorderClient.psm1` — dot-source new files if not auto-loaded.

**Commit:** `chore(module): export EditingService cmdlets`

---

## Implementation Order

| # | Task | Depends On | Est. Time |
|---|---|---|---|
| 0 | Extend `Invoke-RecorderRpc` with `-Service` | — | 5 min |
| 1a | `Invoke-EditingRpc` helper | Task 0 | 3 min |
| 1b | `Rename-GoogleRecordingSpeaker` | Task 1a | 10 min |
| 2 | `Set-GoogleRecordingSpeaker` | Task 1a | 10 min |
| 3 | `Split-GoogleRecordingTranscript` | Task 1a | 10 min |
| 4 | `Edit-GoogleRecordingAudio` (Crop/Remove) | Task 1a | 10 min |
| 5 | `Remove-GoogleRecording` | — | 5 min |
| 6 | `Search-GoogleRecording` | — | 10 min |
| 7 | Module registration | All above | 3 min |

**Total estimated:** ~65 minutes

---

## Out of Scope (deferred)

These PlaybackService write methods exist but are lower priority:

| API Method | Potential Cmdlet | Reason Deferred |
|---|---|---|
| `ChangeShareState` | `Set-GoogleRecordingShare` | Sharing management is niche |
| `WriteShareList` | `Set-GoogleRecordingShare -Recipients` | Complex sharing model |
| `BlockPerson` | `Block-GoogleRecordingPerson` | Rarely needed |
| `UpdateRecordingLabels` | `Set-GoogleRecordingLabel` | Labels are simple ("favorite" only observed) |

These can be added in a follow-up iteration once the core editing workflow is solid.