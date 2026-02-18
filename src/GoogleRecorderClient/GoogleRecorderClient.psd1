@{
    # Module identity
    RootModule        = 'GoogleRecorderClient.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'a3f7c8e1-4d2b-4f6a-9e01-3c5d7b8a2f10'
    Author            = 'GoogleRecorderClient Contributors'
    CompanyName       = ''
    Copyright         = '(c) 2026. All rights reserved.'
    Description       = 'PowerShell module for interacting with Google Recorder (recorder.google.com). Provides authentication and recording management via the undocumented gRPC-Web API.'

    # Requirements
    PowerShellVersion = '5.1'

    # Functions to export
    FunctionsToExport = @(
        'Connect-GoogleRecorder'
        'Disconnect-GoogleRecorder'
        'Get-GoogleRecording'
        'Get-GoogleRecorderLabel'
        'Get-GoogleRecordingTranscript'
        'Get-GoogleRecordingWaveform'
        'Save-GoogleRecordingAudio'
        'Test-GoogleRecorderSearch'
    )

    # Other exports (none)
    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()

    # Formats
    FormatsToProcess   = @('GoogleRecorderClient.Format.ps1xml')

    # Module metadata
    PrivateData = @{
        PSData = @{
            Tags         = @('Google', 'Recorder', 'Audio', 'Transcription', 'gRPC')
            LicenseUri   = ''
            ProjectUri   = ''
            ReleaseNotes = 'Initial release — Connect, Disconnect, Get-GoogleRecording.'
        }
    }
}
