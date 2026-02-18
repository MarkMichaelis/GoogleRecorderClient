BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
}

Describe 'Connect-GoogleRecorder' {
    AfterEach {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
        # Clean up any cache file created during tests
        $cachePath = InModuleScope GoogleRecorderClient { Join-Path $script:ModuleRoot 'recorder-session.json' }
        if (Test-Path $cachePath) { Remove-Item $cachePath -Force -ErrorAction SilentlyContinue }
    }

    Context 'Direct parameter set' {
        It 'accepts -CookieHeader and -ApiKey parameters' {
            # Mock the clientconfig request to avoid real HTTP calls
            Mock -ModuleName GoogleRecorderClient Invoke-ClientConfigRequest {
                return @{
                    apiKey           = 'override-key'
                    email            = 'direct@example.com'
                    firstPartyApiUrl = 'https://pixelrecorder-pa.clients6.google.com'
                }
            }

            Connect-GoogleRecorder -CookieHeader 'SID=abc; HSID=def' -ApiKey 'my-key'

            $session = InModuleScope GoogleRecorderClient { $script:RecorderSession }
            $session | Should -Not -BeNullOrEmpty
            $session.ApiKey       | Should -Be 'my-key'
            $session.CookieHeader | Should -Be 'SID=abc; HSID=def'
            $session.Email        | Should -Be 'direct@example.com'
        }
    }

    Context 'session validation' {
        It 'stores session that allows subsequent Get-GoogleRecording' {
            Mock -ModuleName GoogleRecorderClient Invoke-ClientConfigRequest {
                return @{
                    apiKey           = 'test-key'
                    email            = 'test@example.com'
                    firstPartyApiUrl = 'https://pixelrecorder-pa.clients6.google.com'
                }
            }

            Connect-GoogleRecorder -CookieHeader 'SAPISID=test123' -ApiKey 'test-key'

            $session = InModuleScope GoogleRecorderClient { $script:RecorderSession }
            $session.CookieHeader | Should -Be 'SAPISID=test123'
            $session.BaseUrl      | Should -Be 'https://pixelrecorder-pa.clients6.google.com'
        }
    }
}
