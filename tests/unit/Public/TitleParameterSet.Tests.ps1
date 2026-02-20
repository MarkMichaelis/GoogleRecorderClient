BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
    . (Join-Path $PSScriptRoot '..' '..' 'helpers' 'TestData.ps1')
}

# Tests that every cmdlet accepting RecordingId also has Title/Name support
Describe 'Title parameter set on <CmdletName>' -ForEach @(
    @{ CmdletName = 'Get-GoogleRecordingTranscript' }
    @{ CmdletName = 'Get-GoogleRecordingAudioTag' }
    @{ CmdletName = 'Get-GoogleRecordingShare' }
    @{ CmdletName = 'Get-GoogleRecordingWaveform' }
    @{ CmdletName = 'Save-GoogleRecordingAudio' }
    @{ CmdletName = 'Rename-GoogleRecording' }
) {
    It '<CmdletName> has a ByTitle parameter set' {
        $cmd = Get-Command $CmdletName
        $cmd.ParameterSets.Name | Should -Contain 'ByTitle'
    }

    It '<CmdletName> Title parameter has Position 0' {
        $cmd = Get-Command $CmdletName
        $titleParam = $cmd.Parameters['Title']
        $titleParam | Should -Not -BeNullOrEmpty
        $byTitleAttr = $titleParam.Attributes | Where-Object {
            $_ -is [System.Management.Automation.ParameterAttribute] -and
            $_.ParameterSetName -eq 'ByTitle'
        }
        $byTitleAttr.Position | Should -Be 0
    }

    It '<CmdletName> Title parameter has Name alias' {
        $cmd = Get-Command $CmdletName
        $titleParam = $cmd.Parameters['Title']
        $titleParam.Aliases | Should -Contain 'Name'
    }

    It '<CmdletName> RecordingId requires explicit parameter name' {
        $cmd = Get-Command $CmdletName
        $recIdParam = $cmd.Parameters['RecordingId']
        # RecordingId should not have a Position (or Position should be Int32.MinValue)
        $paramAttr = $recIdParam.Attributes | Where-Object {
            $_ -is [System.Management.Automation.ParameterAttribute]
        } | Select-Object -First 1
        $paramAttr.Position | Should -BeLessThan 0
    }
}
