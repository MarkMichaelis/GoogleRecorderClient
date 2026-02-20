# Path Parameter Standardization Design

**Date:** 2026-02-19
**Status:** Approved
**Scope:** Save-GoogleRecordingAudio, Get-GoogleRecordingTranscript

## Problem

The -OutputPath parameter on Save-GoogleRecordingAudio and Get-GoogleRecordingTranscript has several gaps:

1. No relative-path resolution - relative paths may resolve incorrectly if [Environment]::CurrentDirectory differs from PowerShell's $PWD.
2. No parent-directory validation - passing a path with a nonexistent parent directory produces confusing .NET errors.
3. No overwrite protection - silently overwrites existing files with no warning.
4. No ShouldProcess support - users expect -WhatIf/-Confirm on commands that write to disk.
5. No ValidateNotNullOrEmpty on the -OutputPath parameter.
6. Duplicated resolve logic - Resolve-AudioOutputPath and Resolve-TranscriptOutputPath are nearly identical.

## Design

### 1. Shared Private Helper: Resolve-OutputFilePath

Replace both Resolve-AudioOutputPath and Resolve-TranscriptOutputPath with a single private helper.

Location: src/GoogleRecorderClient/Private/Resolve-OutputFilePath.ps1

Parameters:
- OutputPath (string, mandatory) - raw user-supplied path
- BaseName (string, mandatory) - e.g. RecordingId
- Extension (string, mandatory) - e.g. '.m4a', '.txt'
- Cmdlet (PSCmdlet, mandatory) - caller's $PSCmdlet for path resolution
- Force (switch) - allow overwriting existing files

Behavior:
1. Resolve path via $Cmdlet.GetUnresolvedProviderPathFromPSPath($OutputPath).
2. If resolved path is an existing directory, append "{BaseName}{Extension}" via Join-Path.
3. Validate parent directory exists. If not, throw "Directory not found: {parentPath}".
4. If file exists and -Force not set, throw "File already exists: {path}. Use -Force to overwrite."
5. Return resolved absolute file path.

### 2. -Force Switch

Add [switch]$Force to both Save-GoogleRecordingAudio and Get-GoogleRecordingTranscript. Pass through to Resolve-OutputFilePath.

### 3. ShouldProcess Support

- Save-GoogleRecordingAudio: Add SupportsShouldProcess, ConfirmImpact = 'Medium'. Wrap Invoke-WebRequest in $PSCmdlet.ShouldProcess($filePath, 'Download audio file').
- Get-GoogleRecordingTranscript: Add SupportsShouldProcess. Wrap Set-Content in $PSCmdlet.ShouldProcess($filePath, 'Save transcript').

### 4. ValidateNotNullOrEmpty on -OutputPath

Add [ValidateNotNullOrEmpty()] to both -OutputPath parameters.

### 5. Remove Old Helpers

Delete inline Resolve-AudioOutputPath and Resolve-TranscriptOutputPath functions.

## Files Changed

| File | Action |
|---|---|
| src/GoogleRecorderClient/Private/Resolve-OutputFilePath.ps1 | New - shared path resolution helper |
| tests/unit/Private/Resolve-OutputFilePath.Tests.ps1 | New - unit tests |
| src/GoogleRecorderClient/Public/Save-GoogleRecordingAudio.ps1 | Add -Force, ShouldProcess, ValidateNotNullOrEmpty, use Resolve-OutputFilePath |
| src/GoogleRecorderClient/Public/Get-GoogleRecordingTranscript.ps1 | Add -Force, ShouldProcess, ValidateNotNullOrEmpty, use Resolve-OutputFilePath |
| tests/unit/Public/Save-GoogleRecordingAudio.Tests.ps1 | Update tests for new behavior |
| tests/unit/Public/Get-GoogleRecordingTranscript.Tests.ps1 | Update tests for new behavior |
| docs/product-spec.md | Update Save Audio and Transcript sections |

## Testing Strategy

### Resolve-OutputFilePath Unit Tests
- Directory input: appends BaseName.Extension
- File input: returns as-is (after resolution)
- Nonexistent parent directory: throws terminating error
- Existing file without -Force: throws
- Existing file with -Force: returns path (no error)
- Relative path: resolves correctly via GetUnresolvedProviderPathFromPSPath

### Save-GoogleRecordingAudio Unit Tests
- -WhatIf: does not download
- Existing file without -Force: throws
- Existing file with -Force: overwrites successfully

### Get-GoogleRecordingTranscript Unit Tests
- -OutputPath with -WhatIf: does not write file
- Existing file without -Force: throws
- -OutputPath implies -AsText behavior (text output to file)

## What Stays the Same
- Parameter name remains -OutputPath
- Rename-GoogleRecording already has ShouldProcess - no changes needed
- Directory-vs-file detection via Test-Path -PathType Container
