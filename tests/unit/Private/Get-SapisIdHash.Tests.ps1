BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
}

Describe 'Get-SapisIdHash' {
    It 'returns a string starting with SAPISIDHASH' {
        $result = InModuleScope GoogleRecorderClient {
            Get-SapisIdHash -SapisId 'testvalue' -Origin 'https://recorder.google.com'
        }

        $result | Should -Match '^SAPISIDHASH \d+_[0-9a-f]{40}$'
    }

    It 'contains a Unix timestamp in the result' {
        $before = [long]([DateTimeOffset]::UtcNow).ToUnixTimeSeconds()
        $result = InModuleScope GoogleRecorderClient {
            Get-SapisIdHash -SapisId 'val' -Origin 'https://example.com'
        }
        $after  = [long]([DateTimeOffset]::UtcNow).ToUnixTimeSeconds()

        $parts = $result.Split(' ')[1].Split('_')
        $ts = [long]$parts[0]
        $ts | Should -BeGreaterOrEqual $before
        $ts | Should -BeLessOrEqual $after
    }

    It 'produces a 40-character hex SHA-1 hash' {
        $result = InModuleScope GoogleRecorderClient {
            Get-SapisIdHash -SapisId 'sapisidvalue' -Origin 'https://recorder.google.com'
        }

        $hash = $result.Split('_')[1]
        $hash.Length | Should -Be 40
        $hash | Should -Match '^[0-9a-f]+$'
    }

    It 'produces different hashes for different SAPISID values' {
        $result1 = InModuleScope GoogleRecorderClient {
            Get-SapisIdHash -SapisId 'valueA' -Origin 'https://recorder.google.com'
        }
        $result2 = InModuleScope GoogleRecorderClient {
            Get-SapisIdHash -SapisId 'valueB' -Origin 'https://recorder.google.com'
        }

        $hash1 = $result1.Split('_')[1]
        $hash2 = $result2.Split('_')[1]
        $hash1 | Should -Not -Be $hash2
    }

    It 'produces different hashes for different origins' {
        $result1 = InModuleScope GoogleRecorderClient {
            Get-SapisIdHash -SapisId 'same' -Origin 'https://origin-a.com'
        }
        $result2 = InModuleScope GoogleRecorderClient {
            Get-SapisIdHash -SapisId 'same' -Origin 'https://origin-b.com'
        }

        $hash1 = $result1.Split('_')[1]
        $hash2 = $result2.Split('_')[1]
        $hash1 | Should -Not -Be $hash2
    }
}
