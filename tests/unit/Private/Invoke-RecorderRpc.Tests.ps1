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

    It 'uses PlaybackService RPC path by default' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SID=abc; HSID=def; SAPISID=mno/pqr'
                ApiKey       = 'fake-key'
                Email        = 'test@example.com'
                BaseUrl      = 'https://pixelrecorder-pa.clients6.google.com'
            }
        }

        $script:CapturedUrl = $null

        Mock -ModuleName GoogleRecorderClient Get-SapisIdHash { 'auth-token' }
        Mock -ModuleName GoogleRecorderClient New-RecorderWebSession { New-Object Microsoft.PowerShell.Commands.WebRequestSession }
        Mock -ModuleName GoogleRecorderClient Invoke-WebRequest {
            param($Uri)
            $script:CapturedUrl = $Uri
            # Return minimal response payload
            return @{ Content = [System.Text.Encoding]::UTF8.GetBytes('[]') }
        }

        InModuleScope GoogleRecorderClient {
            Invoke-RecorderRpc -Method 'GetRecordingList' -Body '[[0,0],10]'
        }

        $script:CapturedUrl | Should -Be 'https://pixelrecorder-pa.clients6.google.com/$rpc/java.com.google.wireless.android.pixel.recorder.protos.PlaybackService/GetRecordingList'
    }

    It 'uses EditingService RPC path when -Service is provided' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SID=abc; HSID=def; SAPISID=mno/pqr'
                ApiKey       = 'fake-key'
                Email        = 'test@example.com'
                BaseUrl      = 'https://pixelrecorder-pa.clients6.google.com'
            }
        }

        $script:CapturedUrl = $null

        Mock -ModuleName GoogleRecorderClient Get-SapisIdHash { 'auth-token' }
        Mock -ModuleName GoogleRecorderClient New-RecorderWebSession { New-Object Microsoft.PowerShell.Commands.WebRequestSession }
        Mock -ModuleName GoogleRecorderClient Invoke-WebRequest {
            param($Uri)
            $script:CapturedUrl = $Uri
            return @{ Content = [System.Text.Encoding]::UTF8.GetBytes('[]') }
        }

        InModuleScope GoogleRecorderClient {
            Invoke-RecorderRpc -Service 'EditingService' -Method 'OpenSession' -Body '["x"]'
        }

        $script:CapturedUrl | Should -Be 'https://pixelrecorder-pa.clients6.google.com/$rpc/java.com.google.wireless.android.pixel.recorder.sharedclient.audioediting.protos.EditingService/OpenSession'
    }
}
