BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
}

Describe 'Get-GoogleRecordingShare' {
    AfterEach {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
    }

    It 'throws when not connected' {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
        Mock -ModuleName GoogleRecorderClient Test-Path { $false }

        { Get-GoogleRecordingShare -RecordingId 'some-id' } | Should -Throw '*Not connected*'
    }

    It 'calls GetShareList RPC with the recording ID' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            param($Method, $Body)
            $Method | Should -Be 'GetShareList'
            $Body | Should -Be '["rec-id"]'
            return ,@()
        }

        $result = @(Get-GoogleRecordingShare -RecordingId 'rec-id')

        $result.Count | Should -Be 0
    }

    It 'returns share objects when shares exist' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            # Hypothetical share response structure
            return ,@(,@(,@('user@example.com', 'viewer')))
        }

        $result = @(Get-GoogleRecordingShare -RecordingId 'rec-id')

        $result | Should -Not -BeNullOrEmpty
    }

    It 'accepts RecordingId from pipeline by property name' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc { return ,@() }

        $input = [PSCustomObject]@{ RecordingId = 'pipe-id' }
        $result = @($input | Get-GoogleRecordingShare)

        $result.Count | Should -Be 0
    }
}
