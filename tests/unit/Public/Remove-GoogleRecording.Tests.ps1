BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
    . (Join-Path $PSScriptRoot '..' '..' 'helpers' 'TestData.ps1')
}

Describe 'Remove-GoogleRecording' {
    AfterEach {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
    }

    It 'throws when not connected' {
        Mock -ModuleName GoogleRecorderClient Assert-RecorderSession { throw 'Not connected' }

        {
            InModuleScope GoogleRecorderClient {
                Remove-GoogleRecording -RecordingId 'rec-1'
            }
        } | Should -Throw '*Not connected*'
    }

    It 'deletes specified recording ids via DeleteRecordingList' {
        $session = New-FakeSession
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $session }

        Mock -ModuleName GoogleRecorderClient Assert-RecorderSession { }

        $script:Calls = @()
        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            param($Method, $Body)
            $script:Calls += [pscustomobject]@{ Method = $Method; Body = $Body }
            'deleted'
        }

        $result = InModuleScope GoogleRecorderClient {
            Remove-GoogleRecording -RecordingId @('rec-1','rec-2') -Confirm:$false
        }

        $result | Should -Be 'deleted'
        $script:Calls | Should -HaveCount 1
        $script:Calls[0].Method | Should -Be 'DeleteRecordingList'
        $script:Calls[0].Body   | Should -Be '[["rec-1","rec-2"]]'
    }

    It 'resolves by title and deletes all matches' {
        $session = New-FakeSession
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $session }

        Mock -ModuleName GoogleRecorderClient Assert-RecorderSession { }
        Mock -ModuleName GoogleRecorderClient Resolve-RecordingByTitle {
            return @(
                [pscustomobject]@{ RecordingId = 'rec-1'; Title = 'One' },
                [pscustomobject]@{ RecordingId = 'rec-2'; Title = 'Two' }
            )
        }

        $script:Calls = @()
        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            param($Method, $Body)
            $script:Calls += [pscustomobject]@{ Method = $Method; Body = $Body }
            'ok'
        }

        InModuleScope GoogleRecorderClient {
            Remove-GoogleRecording -Title 'Daily*' -Confirm:$false
        }

        $script:Calls | Should -HaveCount 1
        $script:Calls[0].Method | Should -Be 'DeleteRecordingList'
        $script:Calls[0].Body   | Should -Be '[["rec-1","rec-2"]]'
    }

    It 'honors -WhatIf and skips RPC calls' {
        $session = New-FakeSession
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $session }

        Mock -ModuleName GoogleRecorderClient Assert-RecorderSession { }
        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc { throw 'Should not call' }

        InModuleScope GoogleRecorderClient {
            Remove-GoogleRecording -RecordingId 'rec-1' -WhatIf
        }

        Should -Invoke -ModuleName GoogleRecorderClient Invoke-RecorderRpc -Times 0
    }
}