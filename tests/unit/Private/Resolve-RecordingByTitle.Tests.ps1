BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
    . (Join-Path $PSScriptRoot '..' '..' 'helpers' 'TestData.ps1')
}

Describe 'Resolve-RecordingByTitle' {
    BeforeEach {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }
    }

    AfterEach {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
    }

    It 'returns recordings matching an exact title' {
        InModuleScope GoogleRecorderClient {
            Mock Get-GoogleRecording {
                $rec = [Recording]::new()
                $rec.RecordingId = 'rec-1'
                $rec.Title = 'My Meeting'
                return @($rec)
            }
            $result = Resolve-RecordingByTitle -Title 'My Meeting'
            $result.Count | Should -Be 1
            $result[0].RecordingId | Should -Be 'rec-1'
        }
    }

    It 'supports wildcard matching with asterisk' {
        InModuleScope GoogleRecorderClient {
            Mock Get-GoogleRecording {
                $rec1 = [Recording]::new()
                $rec1.RecordingId = 'rec-1'
                $rec1.Title = 'Standup Monday'
                $rec2 = [Recording]::new()
                $rec2.RecordingId = 'rec-2'
                $rec2.Title = 'Standup Tuesday'
                $rec3 = [Recording]::new()
                $rec3.RecordingId = 'rec-3'
                $rec3.Title = 'Sprint Review'
                return @($rec1, $rec2, $rec3)
            }
            $result = Resolve-RecordingByTitle -Title 'Standup*'
            $result.Count | Should -Be 2
            $result[0].Title | Should -Be 'Standup Monday'
            $result[1].Title | Should -Be 'Standup Tuesday'
        }
    }

    It 'supports wildcard matching with question mark' {
        InModuleScope GoogleRecorderClient {
            Mock Get-GoogleRecording {
                $rec1 = [Recording]::new()
                $rec1.RecordingId = 'rec-1'
                $rec1.Title = 'Sprint 1 Review'
                $rec2 = [Recording]::new()
                $rec2.RecordingId = 'rec-2'
                $rec2.Title = 'Sprint 2 Review'
                $rec3 = [Recording]::new()
                $rec3.RecordingId = 'rec-3'
                $rec3.Title = 'Sprint 10 Review'
                return @($rec1, $rec2, $rec3)
            }
            $result = Resolve-RecordingByTitle -Title 'Sprint ? Review'
            $result.Count | Should -Be 2
        }
    }

    It 'throws when no recordings match the title pattern' {
        InModuleScope GoogleRecorderClient {
            Mock Get-GoogleRecording {
                $rec = [Recording]::new()
                $rec.RecordingId = 'rec-1'
                $rec.Title = 'Something Else'
                return @($rec)
            }
            { Resolve-RecordingByTitle -Title 'NonExistent*' } |
                Should -Throw '*No recording found*'
        }
    }

    It 'is case-insensitive' {
        InModuleScope GoogleRecorderClient {
            Mock Get-GoogleRecording {
                $rec = [Recording]::new()
                $rec.RecordingId = 'rec-1'
                $rec.Title = 'My Meeting'
                return @($rec)
            }
            $result = Resolve-RecordingByTitle -Title 'my meeting'
            $result.Count | Should -Be 1
        }
    }
}
