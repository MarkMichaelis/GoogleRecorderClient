BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
}

Describe 'Invoke-EditingRpc' {
    AfterEach {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
    }

    It 'forwards calls to Invoke-RecorderRpc using EditingService' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{ CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com' }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            param($Method, $Body, $Service)
            $Method  | Should -Be 'OpenSession'
            $Body    | Should -Be '["x"]'
            $Service | Should -Be 'EditingService'
            return 'ok'
        }

        $result = InModuleScope GoogleRecorderClient {
            Invoke-EditingRpc -Method 'OpenSession' -Body '["x"]'
        }

        $result | Should -Be 'ok'
        Should -Invoke -ModuleName GoogleRecorderClient Invoke-RecorderRpc -Times 1 -Exactly
    }
}
