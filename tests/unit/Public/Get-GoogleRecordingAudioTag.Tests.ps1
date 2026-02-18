BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
}

Describe 'Get-GoogleRecordingAudioTag' {
    AfterEach {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
    }

    It 'throws when not connected' {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }

        { Get-GoogleRecordingAudioTag -RecordingId 'some-id' } | Should -Throw '*Not connected*'
    }

    It 'calls GetAudioTag RPC with the recording ID' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            param($Method, $Body)
            $Method | Should -Be 'GetAudioTag'
            $Body | Should -Be '["test-id"]'
            return ,@(
                ,@(
                    @(0, '0', 0),
                    @(1, '3169', 0.052),
                    @(2, '5400', 0.12)
                )
            )
        }

        $result = @(Get-GoogleRecordingAudioTag -RecordingId 'test-id')

        $result | Should -Not -BeNullOrEmpty
    }

    It 'returns audio tag objects with SpeakerId, TimestampMs, and Amplitude' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            return ,@(
                ,@(
                    @(0, '0', 0),
                    @(1, '3169', 0.052),
                    @(2, '5400', 0.12)
                )
            )
        }

        $result = @(Get-GoogleRecordingAudioTag -RecordingId 'test-id')

        $result.Count | Should -Be 3
        $result[0].PSTypeNames | Should -Contain 'GoogleRecorder.AudioTag'
        $result[0].SpeakerId   | Should -Be 0
        $result[0].TimestampMs | Should -Be 0
        $result[0].Amplitude   | Should -Be 0
        $result[1].SpeakerId   | Should -Be 1
        $result[1].TimestampMs | Should -Be 3169
        $result[1].Amplitude   | Should -Be 0.052
    }

    It 'accepts RecordingId from pipeline by property name' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            return ,@(
                ,@(
                    @(0, '0', 0),
                    @(1, '3169', 0.052)
                )
            )
        }

        $input = [PSCustomObject]@{ RecordingId = 'pipe-id' }
        $result = @($input | Get-GoogleRecordingAudioTag)

        $result.Count | Should -Be 2
    }
}
