BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
}

Describe 'Format-RecorderDuration' {
    It 'formats seconds as mm:ss' {
        $result = InModuleScope GoogleRecorderClient {
            Format-RecorderDuration @('125', 0)
        }

        $result | Should -Be '02:05'
    }

    It 'formats durations over an hour as hh:mm:ss' {
        $result = InModuleScope GoogleRecorderClient {
            Format-RecorderDuration @('3725', 0)
        }

        $result | Should -Be '01:02:05'
    }

    It 'formats exactly one hour' {
        $result = InModuleScope GoogleRecorderClient {
            Format-RecorderDuration @('3600', 0)
        }

        $result | Should -Be '01:00:00'
    }

    It 'formats zero seconds' {
        $result = InModuleScope GoogleRecorderClient {
            Format-RecorderDuration @('0', 0)
        }

        $result | Should -Be '00:00'
    }

    It 'formats under one minute' {
        $result = InModuleScope GoogleRecorderClient {
            Format-RecorderDuration @('45', 0)
        }

        $result | Should -Be '00:45'
    }

    It 'formats exactly one minute' {
        $result = InModuleScope GoogleRecorderClient {
            Format-RecorderDuration @('60', 0)
        }

        $result | Should -Be '01:00'
    }
}
