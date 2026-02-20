BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
}

Describe 'New-RecorderWebSession' {
    It 'returns a WebRequestSession' {
        $result = InModuleScope GoogleRecorderClient {
            New-RecorderWebSession -CookieHeader 'SID=abc; HSID=def'
        }

        $result | Should -BeOfType [Microsoft.PowerShell.Commands.WebRequestSession]
    }

    It 'populates the CookieContainer with cookies' {
        $result = InModuleScope GoogleRecorderClient {
            New-RecorderWebSession -CookieHeader 'SID=abc; HSID=def; SSID=ghi'
        }

        $cookies = $result.Cookies.GetCookies('https://www.google.com')
        $cookies.Count | Should -Be 3
    }

    It 'correctly parses cookie name and value' {
        $result = InModuleScope GoogleRecorderClient {
            New-RecorderWebSession -CookieHeader 'SAPISID=mno/pqr; OTHER=val'
        }

        $cookies = $result.Cookies.GetCookies('https://www.google.com')
        $sapisid = $cookies | Where-Object Name -eq 'SAPISID'
        $sapisid.Value | Should -Be 'mno/pqr'
    }

    It 'uses .google.com domain by default' {
        $result = InModuleScope GoogleRecorderClient {
            New-RecorderWebSession -CookieHeader 'SID=abc'
        }

        $cookies = $result.Cookies.GetCookies('https://www.google.com')
        $cookies[0].Domain | Should -Be '.google.com'
    }

    It 'accepts a custom domain' {
        $result = InModuleScope GoogleRecorderClient {
            New-RecorderWebSession -CookieHeader 'SID=abc' -Domain '.example.com'
        }

        $cookies = $result.Cookies.GetCookies('https://www.example.com')
        $cookies.Count | Should -Be 1
        $cookies[0].Domain | Should -Be '.example.com'
    }

    It 'skips empty entries from trailing semicolons' {
        $result = InModuleScope GoogleRecorderClient {
            New-RecorderWebSession -CookieHeader 'SID=abc; ; HSID=def;'
        }

        $cookies = $result.Cookies.GetCookies('https://www.google.com')
        $cookies.Count | Should -Be 2
    }

    It 'handles cookies with equals signs in value' {
        $result = InModuleScope GoogleRecorderClient {
            New-RecorderWebSession -CookieHeader 'TOKEN=abc=def=ghi'
        }

        $cookies = $result.Cookies.GetCookies('https://www.google.com')
        $cookies[0].Value | Should -Be 'abc=def=ghi'
    }
}
