function Format-RawRecording {
    <#
    .SYNOPSIS
        Converts a raw protobuf-JSON recording array into a friendly PSCustomObject.

    .DESCRIPTION
        Maps positional array indices from the GetRecordingList / GetRecordingInfo
        response to named properties.

    .PARAMETER RawRecording
        A single recording array from the API response.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [object]$RawRecording
    )

    $title    = $RawRecording[1]
    $created  = if ($RawRecording[2]) { ConvertFrom-ProtoTimestamp $RawRecording[2] } else { $null }
    $duration = if ($RawRecording[3]) { Format-RecorderDuration $RawRecording[3] } else { '??:??' }
    $lat      = $RawRecording[4]
    $lon      = $RawRecording[5]
    $location = $RawRecording[6]
    $id       = $RawRecording[13]

    # Extract speaker names — API returns [["1","2 Name","3",...]].
    # Each entry is "index" or "index name".
    $speakers = @()
    if ($RawRecording.Count -gt 20 -and $RawRecording[20] -and $RawRecording[20][0]) {
        foreach ($entry in $RawRecording[20][0]) {
            $parts = ([string]$entry).Split(' ', 2)
            if ($parts.Count -gt 1 -and $parts[1]) {
                $speakers += $parts[1]
            }
            else {
                $speakers += "Speaker $($parts[0])"
            }
        }
    }

    [PSCustomObject]@{
        PSTypeName  = 'GoogleRecorder.Recording'
        RecordingId = $id
        Title       = $title
        Created     = $created
        Duration    = $duration
        Latitude    = $lat
        Longitude   = $lon
        Location    = $location
        Speakers    = $speakers
        Url         = "https://recorder.google.com/$id"
    }
}
