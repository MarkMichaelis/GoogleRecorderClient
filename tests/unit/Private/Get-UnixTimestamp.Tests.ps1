BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
}

Describe 'Get-UnixTimestamp' {
    It 'returns an array with two elements' {
        $result = InModuleScope GoogleRecorderClient { Get-UnixTimestamp }

        $result.Count | Should -Be 2
    }

    It 'returns a recent Unix timestamp in seconds' {
        $before = [long]([DateTimeOffset]::UtcNow).ToUnixTimeSeconds()
        $result = InModuleScope GoogleRecorderClient { Get-UnixTimestamp }
        $after  = [long]([DateTimeOffset]::UtcNow).ToUnixTimeSeconds()

        $result[0] | Should -BeGreaterOrEqual $before
        $result[0] | Should -BeLessOrEqual $after
    }

    It 'returns nanoseconds between 0 and 999000000' {
        $result = InModuleScope GoogleRecorderClient { Get-UnixTimestamp }

        $result[1] | Should -BeGreaterOrEqual 0
        $result[1] | Should -BeLessOrEqual 999000000
    }

    It 'returns nanoseconds as a multiple of 1000000 (millisecond precision)' {
        $result = InModuleScope GoogleRecorderClient { Get-UnixTimestamp }

        ($result[1] % 1000000) | Should -Be 0
    }
}
