function Resolve-OutputFilePath {
    <#
    .SYNOPSIS
        Resolves and validates an output file path for saving content to disk.

    .DESCRIPTION
        Given an absolute output path, auto-generates a filename when a directory
        is provided, validates that the parent directory exists, and checks for
        existing files (unless -Force).

        The caller is responsible for converting relative/PSDrive paths to
        absolute paths before calling this function (typically via
        $PSCmdlet.GetUnresolvedProviderPathFromPSPath).

    .PARAMETER OutputPath
        An absolute file or directory path.

    .PARAMETER BaseName
        The base filename to use when OutputPath is a directory (e.g. a RecordingId).

    .PARAMETER Extension
        The file extension including the dot (e.g. '.m4a', '.txt').

    .PARAMETER Force
        Allow overwriting an existing file. Without this, an error is thrown
        if the target file already exists.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$OutputPath,
        [Parameter(Mandatory)][string]$BaseName,
        [Parameter(Mandatory)][string]$Extension,
        [switch]$Force
    )

    if (Test-Path -Path $OutputPath -PathType Container) {
        $OutputPath = Join-Path $OutputPath "$BaseName$Extension"
    }

    $parentDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path -Path $parentDir -PathType Container)) {
        throw "Directory not found: $parentDir"
    }

    if ((Test-Path -Path $OutputPath) -and -not $Force) {
        throw "File already exists: $OutputPath. Use -Force to overwrite."
    }

    return $OutputPath
}
