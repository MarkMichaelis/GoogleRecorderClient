function Resolve-RecordingByTitle {
    <#
    .SYNOPSIS
        Resolves recordings by title with wildcard support.

    .DESCRIPTION
        Fetches all recordings via Get-GoogleRecording and filters them
        by the Title parameter using PowerShell -like wildcard matching.
        Throws if no recordings match.

    .PARAMETER Title
        The title or wildcard pattern to match against recording titles.
        Supports * (any characters) and ? (single character) wildcards.
    #>
    [CmdletBinding()]
    [OutputType('Recording')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Title
    )

    $allRecordings = Get-GoogleRecording

    $matched = @($allRecordings | Where-Object { $_.Title -like $Title })

    if ($matched.Count -eq 0) {
        throw "No recording found matching title '$Title'."
    }

    return $matched
}
