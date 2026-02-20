BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
    . (Join-Path $PSScriptRoot '..' '..' 'helpers' 'TestData.ps1')
}

Describe 'Split-GoogleRecordingTranscript' {
    AfterEach {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
    }

    It 'throws when not connected' {
        Mock -ModuleName GoogleRecorderClient Assert-RecorderSession { throw 'Not connected' }

        {
            InModuleScope GoogleRecorderClient {
                Split-GoogleRecordingTranscript -RecordingId 'rec-1' -Position @(1,2)
            }
        } | Should -Throw '*Not connected*'
    }

    It 'opens session, splits transcript, saves audio, and closes session' {
        $session = New-FakeSession
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $session }

        Mock -ModuleName GoogleRecorderClient Assert-RecorderSession { }
        Mock -ModuleName GoogleRecorderClient Get-GoogleRecording {
            return [pscustomobject]@{ RecordingId = 'rec-1'; Title = 'Meeting' }
        }

        $script:Calls = @()
        Mock -ModuleName GoogleRecorderClient Invoke-EditingRpc {
            param($Method, $Body)
            $script:Calls += [pscustomobject]@{ Method = $Method; Body = $Body }

            switch ($Method) {
                'OpenSession'         { return @('session-abc') }
                'SplitTranscription'  { return 'split-result' }
                default               { return $null }
            }
        }

        $result = InModuleScope GoogleRecorderClient {
            Split-GoogleRecordingTranscript -RecordingId 'rec-1' -Position @(3,4)
        }

        $result | Should -Be 'split-result'
        $script:Calls[0].Body | Should -Be '["rec-1"]'
        $script:Calls[1].Body | Should -Be '["session-abc",[3,4]]'
        $script:Calls[2].Body | Should -Be '["session-abc",[[["Meeting"]],["rec-1"]]]'
        $script:Calls[3].Body | Should -Be '["session-abc"]'
    }

    It 'resolves by title and processes all matches' {
        $session = New-FakeSession
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $session }

        Mock -ModuleName GoogleRecorderClient Assert-RecorderSession { }
        Mock -ModuleName GoogleRecorderClient Resolve-RecordingByTitle {
            return @(
                [pscustomobject]@{ RecordingId = 'rec-1'; Title = 'One' },
                [pscustomobject]@{ RecordingId = 'rec-2'; Title = 'Two' }
            )
        }
        Mock -ModuleName GoogleRecorderClient Get-GoogleRecording {
            param($RecordingId)
            switch ($RecordingId) {
                'rec-1' { return [pscustomobject]@{ RecordingId = 'rec-1'; Title = 'One' } }
                'rec-2' { return [pscustomobject]@{ RecordingId = 'rec-2'; Title = 'Two' } }
            }
        }

        $script:Calls = @()
        $sessionQueue = [System.Collections.Generic.Queue[string]]::new()
        $sessionQueue.Enqueue('s-one')
        $sessionQueue.Enqueue('s-two')

        Mock -ModuleName GoogleRecorderClient Invoke-EditingRpc {
            param($Method, $Body)
            $script:Calls += [pscustomobject]@{ Method = $Method; Body = $Body }
            if ($Method -eq 'OpenSession') { return @($sessionQueue.Dequeue()) }
            return $null
        }

        InModuleScope GoogleRecorderClient {
            Split-GoogleRecordingTranscript -Title 'Daily*' -Position 9
        }

        ($script:Calls | Where-Object Method -eq 'SaveAudio').Body |
            Should -Contain '["s-one",[[["One"]],["rec-1"]]]'
        ($script:Calls | Where-Object Method -eq 'SaveAudio').Body |
            Should -Contain '["s-two",[[["Two"]],["rec-2"]]]'
    }

    It 'supports -WhatIf and skips RPC calls' {
        $session = New-FakeSession
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $session }

        Mock -ModuleName GoogleRecorderClient Assert-RecorderSession { }
        Mock -ModuleName GoogleRecorderClient Get-GoogleRecording {
            return [pscustomobject]@{ RecordingId = 'rec-1'; Title = 'Meeting' }
        }
        Mock -ModuleName GoogleRecorderClient Invoke-EditingRpc { throw 'Should not call' }

        InModuleScope GoogleRecorderClient {
            Split-GoogleRecordingTranscript -RecordingId 'rec-1' -Position 1 -WhatIf
        }

        Should -Invoke -ModuleName GoogleRecorderClient Invoke-EditingRpc -Times 0
    }
}
