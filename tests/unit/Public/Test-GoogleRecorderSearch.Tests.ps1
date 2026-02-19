BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
}

Describe 'Test-GoogleRecorderSearch' {
    AfterEach {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
    }

    It 'throws when not connected' {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
        Mock -ModuleName GoogleRecorderClient Test-Path { $false }

        { Test-GoogleRecorderSearch } | Should -Throw '*Not connected*'
    }

    It 'calls GetGlobalSearchReadiness RPC with empty body' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            param($Method, $Body)
            $Method | Should -Be 'GetGlobalSearchReadiness'
            $Body | Should -Be '[]'
            return ,@(1)
        }

        $result = Test-GoogleRecorderSearch

        $result | Should -Not -BeNullOrEmpty
    }

    It 'returns $true when search is ready' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            return ,@(1)
        }

        $result = Test-GoogleRecorderSearch

        $result | Should -BeTrue
    }

    It 'returns $false when search is not ready' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            return ,@()
        }

        $result = Test-GoogleRecorderSearch

        $result | Should -BeFalse
    }

    It 'returns $false when response is 0' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            return ,@(0)
        }

        $result = Test-GoogleRecorderSearch

        $result | Should -BeFalse
    }
}
