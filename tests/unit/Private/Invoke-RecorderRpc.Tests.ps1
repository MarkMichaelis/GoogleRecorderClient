BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
}

Describe 'Invoke-RecorderRpc' {
    BeforeEach {
        # Set a fake session in module scope
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SID=abc; HSID=def; SAPISID=mno/pqr'
                ApiKey       = 'fake-key'
                Email        = 'test@example.com'
                BaseUrl      = 'https://pixelrecorder-pa.clients6.google.com'
            }
        }
    }

    AfterEach {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
    }

    It 'throws when no session is active' {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }

        {
            InModuleScope GoogleRecorderClient {
                Invoke-RecorderRpc -Method 'GetRecordingList' -Body '[[0,0],10]'
            }
        } | Should -Throw '*Not connected*'
    }

    It 'throws when SAPISID cookie is missing' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SID=abc; HSID=def'
                ApiKey       = 'key'
                Email        = 'x@y.com'
                BaseUrl      = 'https://example.com'
            }
        }

        {
            InModuleScope GoogleRecorderClient {
                Invoke-RecorderRpc -Method 'GetRecordingList' -Body '[[0,0],10]'
            }
        } | Should -Throw '*SAPISID*'
    }
}
