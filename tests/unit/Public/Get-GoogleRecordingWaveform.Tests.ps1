BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
}

Describe 'Get-GoogleRecordingWaveform' {
    AfterEach {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
    }

    It 'throws when not connected' {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
        Mock -ModuleName GoogleRecorderClient Test-Path { $false }

        { Get-GoogleRecordingWaveform -RecordingId 'some-id' } | Should -Throw '*Not connected*'
    }

    It 'calls GetWaveform RPC with the recording ID' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            param($Method, $Body)
            $Method | Should -Be 'GetWaveform'
            $Body | Should -Be '["test-id"]'
            return ,@(,@(,@(0.1, 0.3, 0.5, 0.8, 0.2)))
        }

        $result = Get-GoogleRecordingWaveform -RecordingId 'test-id'

        $result | Should -Not -BeNullOrEmpty
    }

    It 'returns an array of amplitude float values' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            return ,@(,@(,@(0.1, 0.3, 0.5, 0.8, 0.2)))
        }

        $result = Get-GoogleRecordingWaveform -RecordingId 'test-id'

        $result.Samples | Should -Not -BeNullOrEmpty
        $result.Samples.Count | Should -Be 5
        $result.Samples[0] | Should -Be 0.1
        $result.Samples[3] | Should -Be 0.8
        $result.PSTypeNames | Should -Contain 'GoogleRecorder.Waveform'
        $result.RecordingId | Should -Be 'test-id'
    }

    It 'accepts RecordingId from pipeline by property name' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            return ,@(,@(,@(0.5)))
        }

        $input = [PSCustomObject]@{ RecordingId = 'pipe-id' }
        $result = $input | Get-GoogleRecordingWaveform

        $result.RecordingId | Should -Be 'pipe-id'
    }
}
