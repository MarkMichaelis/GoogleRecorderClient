function Search-GoogleRecording {
    <#
    .SYNOPSIS
        Searches Google Recorder transcripts.

    .DESCRIPTION
        Performs keyword search across all recordings or within a single
        recording. Uses the PlaybackService Search and SingleRecordingSearch
        RPCs. Requires an active session - run Connect-GoogleRecorder first.

    .PARAMETER Query
        Search keywords to match.

    .PARAMETER RecordingId
        Limit the search to a specific recording ID.

    .PARAMETER Title
        Resolve one or more recordings by title (supports wildcards) and search
        each match. Alias: Name.

    .PARAMETER MaxResults
        Maximum number of results for global search. Ignored when searching a
        specific recording. Default: 10.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Global')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Query,

        [Parameter(Mandatory, ParameterSetName = 'ById', ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$RecordingId,

        [Parameter(Mandatory, ParameterSetName = 'ByTitle')]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [SupportsWildcards()]
        [string]$Title,

        [Parameter(ParameterSetName = 'Global')]
        [ValidateRange(1, 1000)]
        [int]$MaxResults = 10
    )

    process {
        Assert-RecorderSession

        switch ($PSCmdlet.ParameterSetName) {
            'ById' {
                $body = "[`"$RecordingId`",`"$Query`"]"
                return Invoke-RecorderRpc -Method 'SingleRecordingSearch' -Body $body
            }

            'ByTitle' {
                $resolved = Resolve-RecordingByTitle -Title $Title
                $allResults = @()

                foreach ($rec in $resolved) {
                    $body = "[`"$($rec.RecordingId)`",`"$Query`"]"
                    $res  = Invoke-RecorderRpc -Method 'SingleRecordingSearch' -Body $body
                    if ($null -ne $res) {
                        $allResults += $res
                    }
                }

                return $allResults
            }

            default {
                $body = "[`"$Query`",null,null,null,$MaxResults]"
                return Invoke-RecorderRpc -Method 'Search' -Body $body
            }
        }
    }
}