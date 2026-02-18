BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
}

Describe 'Get-GoogleRecorderLabel' {
    AfterEach {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
    }

    It 'throws when not connected' {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }

        { Get-GoogleRecorderLabel } | Should -Throw '*Not connected*'
    }

    It 'calls ListLabels RPC with empty body' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            param($Method, $Body)
            $Method | Should -Be 'ListLabels'
            $Body | Should -Be '[]'
            return ,@(,@(,@('favorite', 'favorite')))
        }

        $result = @(Get-GoogleRecorderLabel)

        $result | Should -Not -BeNullOrEmpty
    }

    It 'returns label objects with Id and Name properties' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            return ,@(,@(,@('favorite', 'favorite')))
        }

        $result = @(Get-GoogleRecorderLabel)

        $result.Count | Should -Be 1
        $result[0].Id | Should -Be 'favorite'
        $result[0].Name | Should -Be 'favorite'
        $result[0].PSTypeNames | Should -Contain 'GoogleRecorder.Label'
    }

    It 'returns empty array when no labels exist' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc { return ,@() }

        $result = @(Get-GoogleRecorderLabel)

        $result.Count | Should -Be 0
    }
}
