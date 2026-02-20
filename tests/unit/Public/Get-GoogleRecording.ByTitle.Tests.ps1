BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
    . (Join-Path $PSScriptRoot '..' '..' 'helpers' 'TestData.ps1')
}

Describe 'Get-GoogleRecording -Title (ByTitle parameter set)' {
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

    It 'has a ByTitle parameter set' {
        $cmd = Get-Command Get-GoogleRecording
        $cmd.ParameterSets.Name | Should -Contain 'ByTitle'
    }

    It 'Title parameter has Position 0' {
        $cmd = Get-Command Get-GoogleRecording
        $titleParam = $cmd.Parameters['Title']
        $titleParam | Should -Not -BeNullOrEmpty
        $byTitleAttr = $titleParam.Attributes | Where-Object {
            $_ -is [System.Management.Automation.ParameterAttribute] -and
            $_.ParameterSetName -eq 'ByTitle'
        }
        $byTitleAttr.Position | Should -Be 0
    }

    It 'Title parameter has Name alias' {
        $cmd = Get-Command Get-GoogleRecording
        $titleParam = $cmd.Parameters['Title']
        $titleParam.Aliases | Should -Contain 'Name'
    }

    It 'accepts a positional title argument' {
        InModuleScope GoogleRecorderClient {
            Mock Resolve-RecordingByTitle {
                $rec = [Recording]::new()
                $rec.RecordingId = 'rec-1'
                $rec.Title = 'My Meeting'
                return @($rec)
            }
        }
        $result = Get-GoogleRecording 'My Meeting'
        $result.Title | Should -Be 'My Meeting'
    }

    It 'accepts -Name alias for Title' {
        InModuleScope GoogleRecorderClient {
            Mock Resolve-RecordingByTitle {
                $rec = [Recording]::new()
                $rec.RecordingId = 'rec-1'
                $rec.Title = 'My Meeting'
                return @($rec)
            }
        }
        $result = Get-GoogleRecording -Name 'My Meeting'
        $result.Title | Should -Be 'My Meeting'
    }

    It 'returns multiple matches for wildcard title' {
        InModuleScope GoogleRecorderClient {
            Mock Resolve-RecordingByTitle {
                $rec1 = [Recording]::new()
                $rec1.RecordingId = 'rec-1'
                $rec1.Title = 'Standup Monday'
                $rec2 = [Recording]::new()
                $rec2.RecordingId = 'rec-2'
                $rec2.Title = 'Standup Tuesday'
                return @($rec1, $rec2)
            }
        }
        $result = @(Get-GoogleRecording -Title 'Standup*')
        $result.Count | Should -Be 2
    }
}
