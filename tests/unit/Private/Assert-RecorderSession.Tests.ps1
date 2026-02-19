BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
}

Describe 'Assert-RecorderSession' {
    AfterEach {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
    }

    It 'does nothing when session already exists' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }

            { Assert-RecorderSession } | Should -Not -Throw
        }
    }

    It 'throws when no session and no cache file' {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
        Mock -ModuleName GoogleRecorderClient Test-Path { $false }

        InModuleScope GoogleRecorderClient {
            { Assert-RecorderSession } | Should -Throw '*Not connected*'
        }
    }

    It 'auto-connects from cache when session is null but cache exists' {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
        Mock -ModuleName GoogleRecorderClient Test-Path { $true }

        # The mock sets the session on the module-scoped variable, simulating
        # what the real Connect-GoogleRecorder does internally.
        Mock -ModuleName GoogleRecorderClient Connect-GoogleRecorder {
            & (Get-Module GoogleRecorderClient) {
                $script:RecorderSession = @{
                    CookieHeader = 'SAPISID=cached'; ApiKey = 'k'
                    Email = 'cached@test.com'; BaseUrl = 'https://example.com'
                }
            }
        }

        InModuleScope GoogleRecorderClient {
            { Assert-RecorderSession } | Should -Not -Throw
            $script:RecorderSession.Email | Should -Be 'cached@test.com'
        }
    }

    It 'throws when cache exists but Connect-GoogleRecorder fails' {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
        Mock -ModuleName GoogleRecorderClient Test-Path { $true }
        Mock -ModuleName GoogleRecorderClient Connect-GoogleRecorder { throw 'Cache invalid' }

        InModuleScope GoogleRecorderClient {
            { Assert-RecorderSession } | Should -Throw '*Not connected*'
        }
    }
}
