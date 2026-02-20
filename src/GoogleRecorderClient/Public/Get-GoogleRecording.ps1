function Get-GoogleRecording {
    <#
    .SYNOPSIS
        Retrieves recordings from Google Recorder.

    .DESCRIPTION
        Retrieves a paginated list of the authenticated user's recordings, or
        full details for a single recording by ID. Returns friendly objects with
        named properties like Title, Created, Duration, Location, and Speakers.

        When -RecordingId is specified, calls GetRecordingInfo for that single
        recording and includes the AudioDownloadUrl.

        Requires an active session — run Connect-GoogleRecorder first.

    .PARAMETER RecordingId
        The UUID of a specific recording to retrieve details for.

    .PARAMETER PageSize
        Number of recordings to fetch per API page. Default: 10.

    .PARAMETER MaxPages
        Maximum number of pages to retrieve. Default: 100 (effectively all recordings).

    .PARAMETER First
        Return only the first N recordings. Pagination stops once this count is reached.

    .EXAMPLE
        Get-GoogleRecording
        # Lists all recordings.

    .EXAMPLE
        Get-GoogleRecording -RecordingId 'de3d94a9-6856-45d9-bc05-590ee644fcda'
        # Gets details for a specific recording.

    .EXAMPLE
        Get-GoogleRecording -First 5
        # Lists the 5 most recent recordings.

    .PARAMETER Title
        A title or wildcard pattern to match recordings by name.
        Supports * and ? wildcards. Alias: Name.

    .EXAMPLE
        Get-GoogleRecording | Where-Object Location -like '*Spokane*'
        # Filters recordings by location.

    .EXAMPLE
        Get-GoogleRecording 'My Meeting'
        # Retrieves recordings matching the title 'My Meeting'.

    .EXAMPLE
        Get-GoogleRecording -Name 'Standup*'
        # Retrieves all recordings with titles matching 'Standup*'.
    #>
    [CmdletBinding(DefaultParameterSetName = 'List')]
    [OutputType('Recording')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById', ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$RecordingId,

        [Parameter(Mandatory, ParameterSetName = 'ByTitle', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [SupportsWildcards()]
        [string]$Title,

        [Parameter(ParameterSetName = 'List')]
        [ValidateRange(1, 100)]
        [int]$PageSize = 10,

        [Parameter(ParameterSetName = 'List')]
        [ValidateRange(1, 10000)]
        [int]$MaxPages = 100,

        [Parameter(ParameterSetName = 'List')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$First
    )

    process {
    Assert-RecorderSession

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        return Get-SingleRecording -RecordingId $RecordingId
    }

    if ($PSCmdlet.ParameterSetName -eq 'ByTitle') {
        return Resolve-RecordingByTitle -Title $Title
    }

    return Get-RecordingList -PageSize $PageSize -MaxPages $MaxPages -First $First
    }
}

function Get-SingleRecording {
    <#
    .SYNOPSIS
        Retrieves a single recording by ID via GetRecordingInfo.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RecordingId
    )

    $body   = "[`"$RecordingId`"]"
    $result = Invoke-RecorderRpc -Method 'GetRecordingInfo' -Body $body

    if (-not $result -or -not $result[0]) {
        throw "Recording '$RecordingId' not found."
    }

    $recording = Format-RawRecording -RawRecording $result[0]

    # Set audio download URL if present (index 3 in the response)
    if ($result.Count -gt 3 -and $result[3]) {
        $recording.AudioDownloadUrl = $result[3]
    }

    return $recording
}

function Get-RecordingList {
    <#
    .SYNOPSIS
        Retrieves a paginated list of recordings via GetRecordingList.
    #>
    [CmdletBinding()]
    param(
        [int]$PageSize = 10,
        [int]$MaxPages = 100,
        [int]$First
    )

    $allRecordings = [System.Collections.ArrayList]::new()
    $cursor = Get-UnixTimestamp
    $page   = 0

    do {
        $page++
        Write-Verbose "Fetching page $page (cursor: $($cursor[0]).$($cursor[1]))..."

        $body   = "[[$($cursor[0]),$($cursor[1])],$PageSize]"
        $result = Invoke-RecorderRpc -Method 'GetRecordingList' -Body $body

        if (-not $result -or -not $result[0]) {
            Write-Verbose 'Empty response — no more recordings.'
            break
        }

        $recordings = $result[0]
        foreach ($raw in $recordings) {
            $formatted = Format-RawRecording -RawRecording $raw
            [void]$allRecordings.Add($formatted)

            if ($First -and $allRecordings.Count -ge $First) {
                break
            }
        }

        if ($First -and $allRecordings.Count -ge $First) {
            break
        }

        # Check for more pages
        $hasMore = ($result.Count -gt 1) -and ($result[1] -eq 1)

        if ($hasMore -and $recordings.Count -gt 0) {
            $lastRecording = $recordings[$recordings.Count - 1]
            $createdAt     = $lastRecording[2]
            $cursor        = @([long]$createdAt[0], [int]$createdAt[1])
        }
        else {
            $hasMore = $false
        }

    } while ($hasMore -and $page -lt $MaxPages)

    if ($First) {
        return $allRecordings | Select-Object -First $First
    }

    return $allRecordings
}
