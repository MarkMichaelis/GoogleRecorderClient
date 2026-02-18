BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
}

Describe 'ConvertFrom-ProtoTimestamp' {
    It 'converts unix seconds to local DateTime' {
        $result = InModuleScope GoogleRecorderClient {
            ConvertFrom-ProtoTimestamp @('1771181693', 323000000)
        }

        $result | Should -BeOfType [datetime]
        # Verify the UTC equivalent is correct regardless of local timezone
        $utc = $result.ToUniversalTime()
        $utc.Year  | Should -Be 2026
        $utc.Month | Should -Be 2
        $utc.Day   | Should -Be 15
    }

    It 'handles zero timestamp (epoch)' {
        $result = InModuleScope GoogleRecorderClient {
            ConvertFrom-ProtoTimestamp @('0', 0)
        }

        $utc = $result.ToUniversalTime()
        $utc | Should -Be ([datetime]::new(1970, 1, 1, 0, 0, 0, [System.DateTimeKind]::Utc))
    }

    It 'handles string seconds (as returned by API)' {
        $result = InModuleScope GoogleRecorderClient {
            ConvertFrom-ProtoTimestamp @('1000000000', 0)
        }

        $result | Should -BeOfType [datetime]
        $utc = $result.ToUniversalTime()
        $utc.Year | Should -Be 2001
    }
}
