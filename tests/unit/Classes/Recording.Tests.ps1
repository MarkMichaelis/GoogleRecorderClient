BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
}

Describe 'Recording class' {
    Context 'instantiation' {
        It 'can be created with New-Object' {
            $type = InModuleScope GoogleRecorderClient {
                $r = [Recording]::new()
                $r.GetType().Name
            }

            $type | Should -Be 'Recording'
        }

        It 'has Recording in PSTypeNames' {
            $recording = InModuleScope GoogleRecorderClient {
                [Recording]::new()
            }

            $recording.PSTypeNames | Should -Contain 'Recording'
        }
    }

    Context 'properties' {
        It 'has RecordingId property' {
            $recording = InModuleScope GoogleRecorderClient {
                $r = [Recording]::new()
                $r.RecordingId = 'test-123'
                $r
            }

            $recording.RecordingId | Should -Be 'test-123'
        }

        It 'has Id alias that returns RecordingId' {
            $recording = InModuleScope GoogleRecorderClient {
                $r = [Recording]::new()
                $r.RecordingId = 'alias-test'
                $r
            }

            $recording.Id | Should -Be 'alias-test'
        }

        It 'has Title property' {
            $recording = InModuleScope GoogleRecorderClient {
                $r = [Recording]::new()
                $r.Title = 'My Recording'
                $r
            }

            $recording.Title | Should -Be 'My Recording'
        }

        It 'has Created property (datetime)' {
            $recording = InModuleScope GoogleRecorderClient {
                $r = [Recording]::new()
                $r.Created = [datetime]'2025-01-15 10:30:00'
                $r
            }

            $recording.Created | Should -BeOfType [datetime]
        }

        It 'has Duration property' {
            $recording = InModuleScope GoogleRecorderClient {
                $r = [Recording]::new()
                $r.Duration = '16:18'
                $r
            }

            $recording.Duration | Should -Be '16:18'
        }

        It 'has Location property' {
            $recording = InModuleScope GoogleRecorderClient {
                $r = [Recording]::new()
                $r.Location = 'Spokane, WA'
                $r
            }

            $recording.Location | Should -Be 'Spokane, WA'
        }

        It 'has Latitude and Longitude properties' {
            $recording = InModuleScope GoogleRecorderClient {
                $r = [Recording]::new()
                $r.Latitude = 47.6
                $r.Longitude = -117.4
                $r
            }

            $recording.Latitude  | Should -Be 47.6
            $recording.Longitude | Should -Be -117.4
        }

        It 'has Speakers as string array, defaulting to empty' {
            $count = InModuleScope GoogleRecorderClient {
                $r = [Recording]::new()
                $r.Speakers.Count
            }

            $count | Should -Be 0
        }

        It 'Speakers can hold multiple values' {
            $recording = InModuleScope GoogleRecorderClient {
                $r = [Recording]::new()
                $r.Speakers = @('Alice', 'Bob')
                $r
            }

            $recording.Speakers | Should -HaveCount 2
            $recording.Speakers | Should -Contain 'Alice'
            $recording.Speakers | Should -Contain 'Bob'
        }

        It 'has Url property' {
            $recording = InModuleScope GoogleRecorderClient {
                $r = [Recording]::new()
                $r.Url = 'https://recorder.google.com/test-123'
                $r
            }

            $recording.Url | Should -Be 'https://recorder.google.com/test-123'
        }

        It 'has AudioDownloadUrl property (nullable)' {
            $recording = InModuleScope GoogleRecorderClient {
                $r = [Recording]::new()
                $r.AudioDownloadUrl = 'https://example.com/audio.m4a'
                $r
            }

            $recording.AudioDownloadUrl | Should -Be 'https://example.com/audio.m4a'
        }

        It 'AudioDownloadUrl defaults to null' {
            $recording = InModuleScope GoogleRecorderClient {
                [Recording]::new()
            }

            $recording.AudioDownloadUrl | Should -BeNullOrEmpty
        }
    }

    Context 'ToString' {
        It 'returns Title when converted to string' {
            $recording = InModuleScope GoogleRecorderClient {
                $r = [Recording]::new()
                $r.Title = 'Morning Standup'
                $r
            }

            $recording.ToString() | Should -Be 'Morning Standup'
        }
    }
}
