BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
    . (Join-Path $PSScriptRoot '..' '..' 'helpers' 'TestData.ps1')
}

Describe 'Format-RawRecording' {
    Context 'basic field mapping' {
        It 'maps Title from index 1' {
            $raw = New-FakeRawRecording -Title 'My Recording'
            $result = InModuleScope GoogleRecorderClient -ArgumentList @(, $raw) {
                param($r)
                Format-RawRecording -RawRecording $r
            }

            $result.Title | Should -Be 'My Recording'
        }

        It 'maps RecordingId from index 13' {
            $raw = New-FakeRawRecording -Id 'abc-123'
            $result = InModuleScope GoogleRecorderClient -ArgumentList @(, $raw) {
                param($r)
                Format-RawRecording -RawRecording $r
            }

            $result.RecordingId | Should -Be 'abc-123'
        }

        It 'maps Location from index 6' {
            $raw = New-FakeRawRecording -Location 'Seattle, WA'
            $result = InModuleScope GoogleRecorderClient -ArgumentList @(, $raw) {
                param($r)
                Format-RawRecording -RawRecording $r
            }

            $result.Location | Should -Be 'Seattle, WA'
        }

        It 'maps Latitude and Longitude' {
            $raw = New-FakeRawRecording -Lat 48.5 -Lon -120.3
            $result = InModuleScope GoogleRecorderClient -ArgumentList @(, $raw) {
                param($r)
                Format-RawRecording -RawRecording $r
            }

            $result.Latitude  | Should -Be 48.5
            $result.Longitude | Should -Be -120.3
        }

        It 'builds the Url from RecordingId' {
            $raw = New-FakeRawRecording -Id 'rec-xyz'
            $result = InModuleScope GoogleRecorderClient -ArgumentList @(, $raw) {
                param($r)
                Format-RawRecording -RawRecording $r
            }

            $result.Url | Should -Be 'https://recorder.google.com/rec-xyz'
        }

        It 'returns a Recording instance' {
            $raw = New-FakeRawRecording
            $result = InModuleScope GoogleRecorderClient -ArgumentList @(, $raw) {
                param($r)
                Format-RawRecording -RawRecording $r
            }

            $result.PSTypeNames | Should -Contain 'Recording'
        }
    }

    Context 'timestamp and duration conversion' {
        It 'converts Created timestamp to DateTime' {
            $raw = New-FakeRawRecording -CreatedSeconds 1771181693
            $result = InModuleScope GoogleRecorderClient -ArgumentList @(, $raw) {
                param($r)
                Format-RawRecording -RawRecording $r
            }

            $result.Created | Should -BeOfType [datetime]
        }

        It 'formats Duration as mm:ss' {
            $raw = New-FakeRawRecording -DurationSeconds '978'
            $result = InModuleScope GoogleRecorderClient -ArgumentList @(, $raw) {
                param($r)
                Format-RawRecording -RawRecording $r
            }

            $result.Duration | Should -Be '16:18'
        }

        It 'returns ??:?? when duration is null' {
            $raw = New-FakeRawRecording
            $raw[3] = $null
            $result = InModuleScope GoogleRecorderClient -ArgumentList @(, $raw) {
                param($r)
                Format-RawRecording -RawRecording $r
            }

            $result.Duration | Should -Be '??:??'
        }
    }

    Context 'speaker extraction' {
        It 'extracts named speakers' {
            $raw = New-FakeRawRecording -SpeakerEntries @('1 Elisabeth', '2 Mark')
            $result = InModuleScope GoogleRecorderClient -ArgumentList @(, $raw) {
                param($r)
                Format-RawRecording -RawRecording $r
            }

            $result.Speakers | Should -Contain 'Elisabeth'
            $result.Speakers | Should -Contain 'Mark'
        }

        It 'creates Speaker N for unnamed speakers' {
            $raw = New-FakeRawRecording -SpeakerEntries @('1', '2 Named', '3')
            $result = InModuleScope GoogleRecorderClient -ArgumentList @(, $raw) {
                param($r)
                Format-RawRecording -RawRecording $r
            }

            $result.Speakers | Should -Contain 'Speaker 1'
            $result.Speakers | Should -Contain 'Named'
            $result.Speakers | Should -Contain 'Speaker 3'
        }

        It 'returns empty array when no speakers' {
            $raw = New-FakeRawRecording
            $raw[20] = $null
            $result = InModuleScope GoogleRecorderClient -ArgumentList @(, $raw) {
                param($r)
                Format-RawRecording -RawRecording $r
            }

            $result.Speakers | Should -HaveCount 0
        }
    }
}
