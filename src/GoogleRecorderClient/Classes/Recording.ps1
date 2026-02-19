<#
.SYNOPSIS
    Represents a Google Recorder recording with typed properties.

.DESCRIPTION
    Strongly-typed class used throughout the GoogleRecorderClient module
    to represent a recording returned from the Google Recorder API.
    An 'Id' alias property is registered via Update-TypeData in the
    module loader for convenient short-hand access to RecordingId.
    Exported as type name 'Recording'.
#>

class Recording {
    [string]$RecordingId
    [string]$Title
    $Created  # [datetime] or $null
    [string]$Duration
    [double]$Latitude
    [double]$Longitude
    [string]$Location
    [string[]]$Speakers
    [string]$Url
    [string]$AudioDownloadUrl

    Recording() {
        $this.Speakers = @()
    }

    [string] ToString() {
        return $this.Title
    }
}
