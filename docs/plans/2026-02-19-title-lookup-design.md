# Title-Based Recording Lookup — Design

**Date:** 2026-02-19  
**Feature:** Allow recordings to be identified by Title (with wildcard support), not just RecordingId

## Problem

Currently all cmdlets that operate on individual recordings require a `RecordingId` (UUID). Users must first run `Get-GoogleRecording`, find the UUID, then pass it to other commands. This is friction-heavy.

## Design

### Approach: Dual Parameter Sets with Shared Resolution Helper

Every cmdlet that currently accepts `-RecordingId` will gain two parameter sets:

| Parameter Set | Parameters | Binding |
|---|---|---|
| `ByRecordingId` | `-RecordingId` (Mandatory, named) | Explicit `-RecordingId <uuid>` or pipeline by property name |
| `ByTitle` | `-Title` (Mandatory, Position=0, Alias='Name') | Positional: `Get-GoogleRecording "my recording"` |

**`Get-GoogleRecording`** is special — it already has `List`, `ById`. We add `ByTitle`:

| Set | Params |
|---|---|
| `List` (default) | `-PageSize`, `-MaxPages`, `-First` |
| `ById` | `-RecordingId` (Mandatory) |
| `ByTitle` | `-Title` (Position=0, Alias='Name', supports wildcards) |

### Title Resolution

A new **private** helper `Resolve-RecordingByTitle` will:

1. Call `Get-GoogleRecording` (list all) internally
2. Filter with `-like` (wildcard matching) on the `Title` property
3. Return matching `Recording` objects
4. Throw if no matches found

### Affected Cmdlets

1. `Get-GoogleRecording` — add `ByTitle` parameter set
2. `Get-GoogleRecordingTranscript` — add `ByTitle` parameter set
3. `Get-GoogleRecordingAudioTag` — add `ByTitle` parameter set
4. `Get-GoogleRecordingShare` — add `ByTitle` parameter set
5. `Get-GoogleRecordingWaveform` — add `ByTitle` parameter set
6. `Save-GoogleRecordingAudio` — add `ByTitle` parameter set
7. `Rename-GoogleRecording` — add `ByTitle` parameter set

### Wildcard Support

The `-Title` parameter accepts PowerShell wildcard patterns via `-like`:
- `Get-GoogleRecording "My Meeting*"` — starts with
- `Get-GoogleRecording "*Standup*"` — contains
- `Get-GoogleRecording "Sprint ? Review"` — single character wildcard

### Pipeline Behavior

When Title matches multiple recordings, each is processed through the pipeline (multiple outputs for `Get-GoogleRecording`, multiple RPC calls for other cmdlets).

### Name Alias

All `-Title` parameters will have `[Alias('Name')]` so users can use `-Name` interchangeably.

## File Changes

| File | Change |
|---|---|
| `src/.../Private/Resolve-RecordingByTitle.ps1` | NEW — shared title resolution helper |
| `src/.../Public/Get-GoogleRecording.ps1` | Add `ByTitle` parameter set |
| `src/.../Public/Get-GoogleRecordingTranscript.ps1` | Add `ByTitle` parameter set |
| `src/.../Public/Get-GoogleRecordingAudioTag.ps1` | Add `ByTitle` parameter set |
| `src/.../Public/Get-GoogleRecordingShare.ps1` | Add `ByTitle` parameter set |
| `src/.../Public/Get-GoogleRecordingWaveform.ps1` | Add `ByTitle` parameter set |
| `src/.../Public/Save-GoogleRecordingAudio.ps1` | Add `ByTitle` parameter set |
| `src/.../Public/Rename-GoogleRecording.ps1` | Add `ByTitle` parameter set |
| `tests/unit/Private/Resolve-RecordingByTitle.Tests.ps1` | NEW — unit tests |
| `tests/unit/Public/Get-GoogleRecording.ByTitle.Tests.ps1` | NEW — title lookup tests |
| Various existing test files | Add title parameter set tests |

## Decision Log

- **Positional binding on Title only** — RecordingId must be named (`-RecordingId <uuid>`) to disambiguate from Title
- **Wildcard via `-like`** — standard PowerShell pattern, no regex
- **Error on no match** — throw descriptive error when no recording matches the title pattern
- **Multiple matches flow through pipeline** — consistent with PowerShell conventions
