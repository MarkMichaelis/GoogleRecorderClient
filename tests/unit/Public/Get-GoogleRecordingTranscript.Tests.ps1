BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
}

Describe 'Get-GoogleRecordingTranscript' {
    AfterEach {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
    }

    It 'throws when not connected' {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
        Mock -ModuleName GoogleRecorderClient Test-Path { $false }

        { Get-GoogleRecordingTranscript -RecordingId 'some-id' } | Should -Throw '*Not connected*'
    }

    It 'calls GetTranscription RPC with the recording ID' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            param($Method, $Body)
            $Method | Should -Be 'GetTranscription'
            $Body | Should -Be '["test-id"]'
            # Return a minimal transcript response
            return ,@(
                ,@(
                    ,@(
                        ,@(
                            @('hello', 'Hello,', '3620', '3860', $null, $null, @(1, 1)),
                            @('world', 'world.', '3860', '4100', $null, $null, @(1, 1))
                        )
                    )
                )
            )
        }

        $result = Get-GoogleRecordingTranscript -RecordingId 'test-id'

        $result | Should -Not -BeNullOrEmpty
    }

    It 'returns transcript word objects with expected properties' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            return ,@(
                ,@(
                    ,@(
                        ,@(
                            @('hello', 'Hello,', '3620', '3860', $null, $null, @(1, 1)),
                            @('world', 'world.', '3860', '4100', $null, $null, @(1, 2))
                        )
                    )
                )
            )
        }

        $result = @(Get-GoogleRecordingTranscript -RecordingId 'test-id')

        $result.Count | Should -BeGreaterOrEqual 1
        $result[0].PSTypeNames | Should -Contain 'GoogleRecorder.TranscriptWord'
        $result[0].Word | Should -Be 'Hello,'
        $result[0].StartMs | Should -Be 3620
        $result[0].EndMs | Should -Be 3860
        $result[0].SpeakerId | Should -Be 1
    }

    It 'returns plain text with -AsText switch' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            return ,@(
                ,@(
                    ,@(
                        ,@(
                            @('hello', 'Hello,', '3620', '3860', $null, $null, @(1, 1)),
                            @('world', 'world.', '3860', '4100', $null, $null, @(1, 1))
                        )
                    )
                )
            )
        }

        $result = Get-GoogleRecordingTranscript -RecordingId 'test-id' -AsText

        $result | Should -BeOfType [string]
        $result | Should -BeLike '*Hello,*world.*'
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
                    ,@(
                        ,@(
                            @('hello', 'Hello,', '3620', '3860', $null, $null, @(1, 1)),
                            @('world', 'world.', '3860', '4100', $null, $null, @(1, 1))
                        )
                    )
                )
            )
        }

        $input = [PSCustomObject]@{ RecordingId = 'pipe-id' }
        $result = $input | Get-GoogleRecordingTranscript

        $result | Should -Not -BeNullOrEmpty
    }
}
