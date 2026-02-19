BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
}

Describe 'Rename-GoogleRecording' {
    AfterEach {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
    }

    It 'throws when not connected' {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
        Mock -ModuleName GoogleRecorderClient Test-Path { $false }

        { Rename-GoogleRecording -RecordingId 'some-id' -NewTitle 'New' } |
            Should -Throw '*Not connected*'
    }

    It 'calls UpdateRecordingTitle RPC with recording ID and new title' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            param($Method, $Body)
            $Method | Should -Be 'UpdateRecordingTitle'
            $Body | Should -Be '["rec-123","My New Title"]'
            return $null
        }

        Rename-GoogleRecording -RecordingId 'rec-123' -NewTitle 'My New Title'

        Should -Invoke -ModuleName GoogleRecorderClient Invoke-RecorderRpc -Times 1 -Exactly
    }

    It 'validates that NewTitle is not null or empty' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        { Rename-GoogleRecording -RecordingId 'rec-123' -NewTitle '' } |
            Should -Throw
    }

    It 'accepts RecordingId from pipeline by property name' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc { return $null }

        $input = [PSCustomObject]@{ RecordingId = 'pipe-id' }
        $input | Rename-GoogleRecording -NewTitle 'Piped Title'

        Should -Invoke -ModuleName GoogleRecorderClient Invoke-RecorderRpc -Times 1 -Exactly
    }

    It 'supports -WhatIf without calling the API' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc { return $null }

        Rename-GoogleRecording -RecordingId 'rec-123' -NewTitle 'Test' -WhatIf

        Should -Invoke -ModuleName GoogleRecorderClient Invoke-RecorderRpc -Times 0 -Exactly
    }
}
