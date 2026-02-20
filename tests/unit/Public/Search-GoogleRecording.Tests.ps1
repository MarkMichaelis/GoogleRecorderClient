BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
}

Describe 'Search-GoogleRecording' {
    AfterEach {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
    }

    It 'throws when not connected' {
        Mock -ModuleName GoogleRecorderClient Assert-RecorderSession { throw 'Not connected' }

        { InModuleScope GoogleRecorderClient { Search-GoogleRecording -Query 'notes' } } |
            Should -Throw '*Not connected*'
    }

    It 'performs global search via Search RPC with page size' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Assert-RecorderSession { }

        $script:Calls = @()
        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            param($Method, $Body)
            $script:Calls += [pscustomobject]@{ Method = $Method; Body = $Body }
            return ,@('hit-1')
        }

        $result = InModuleScope GoogleRecorderClient {
            Search-GoogleRecording -Query 'hello world' -MaxResults 5
        }

        $result | Should -Be @('hit-1')
        $script:Calls | Should -HaveCount 1
        $script:Calls[0].Method | Should -Be 'Search'
        $script:Calls[0].Body   | Should -Be '["hello world",null,null,null,5]'
    }

    It 'searches within a single recording by ID' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Assert-RecorderSession { }

        $script:Calls = @()
        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            param($Method, $Body)
            $script:Calls += [pscustomobject]@{ Method = $Method; Body = $Body }
            return ,@('r1')
        }

        $result = InModuleScope GoogleRecorderClient {
            Search-GoogleRecording -RecordingId 'rec-1' -Query 'hello'
        }

        $result | Should -Be @('r1')
        $script:Calls | Should -HaveCount 1
        $script:Calls[0].Method | Should -Be 'SingleRecordingSearch'
        $script:Calls[0].Body   | Should -Be '["rec-1","hello"]'
    }

    It 'resolves titles and aggregates results from each recording' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'; ApiKey = 'k'; Email = 'x'; BaseUrl = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Assert-RecorderSession { }
        Mock -ModuleName GoogleRecorderClient Resolve-RecordingByTitle {
            return @(
                [pscustomobject]@{ RecordingId = 'rec-1'; Title = 'First' },
                [pscustomobject]@{ RecordingId = 'rec-2'; Title = 'Second' }
            )
        }

        $script:Calls = @()
        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            param($Method, $Body)
            $script:Calls += [pscustomobject]@{ Method = $Method; Body = $Body }
            if ($Body -like '*rec-1*') { return ,@('hit-1') }
            if ($Body -like '*rec-2*') { return ,@('hit-2') }
        }

        $result = InModuleScope GoogleRecorderClient {
            Search-GoogleRecording -Title 'Daily*' -Query 'agenda'
        }

        $result | Should -Be @('hit-1','hit-2')
        $script:Calls | Should -HaveCount 2
        $script:Calls[0].Method | Should -Be 'SingleRecordingSearch'
        $script:Calls[1].Method | Should -Be 'SingleRecordingSearch'
        $script:Calls[0].Body   | Should -Be '["rec-1","agenda"]'
        $script:Calls[1].Body   | Should -Be '["rec-2","agenda"]'
    }
}