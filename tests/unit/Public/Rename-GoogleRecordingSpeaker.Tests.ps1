BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
    . (Join-Path $PSScriptRoot '..' '..' 'helpers' 'TestData.ps1')
}

Describe 'Rename-GoogleRecordingSpeaker' {
    AfterEach {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
    }

    It 'throws when not connected' {
        Mock -ModuleName GoogleRecorderClient Assert-RecorderSession { throw 'Not connected' }

        {
            InModuleScope GoogleRecorderClient {
                Rename-GoogleRecordingSpeaker -RecordingId 'rec-1' -SpeakerId 1 -NewName 'Alex'
            }
        } | Should -Throw '*Not connected*'
    }

    It 'opens a session, renames the speaker, saves audio, and returns speakers' {
        $session = New-FakeSession
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $session }

        Mock -ModuleName GoogleRecorderClient Assert-RecorderSession { }
        Mock -ModuleName GoogleRecorderClient Get-GoogleRecording {
            return [pscustomobject]@{ RecordingId = 'rec-1'; Title = 'Meeting Title' }
        }

        $script:Calls = @()
        Mock -ModuleName GoogleRecorderClient Invoke-EditingRpc {
            param($Method, $Body)
            $script:Calls += [pscustomobject]@{ Method = $Method; Body = $Body }
            switch ($Method) {
                'OpenSession'   { return @('session-abc') }
                'RenameSpeaker' { return @('speaker-list') }
                default         { return $null }
            }
        }

        $result = InModuleScope GoogleRecorderClient {
            Rename-GoogleRecordingSpeaker -RecordingId 'rec-1' -SpeakerId 2 -NewName 'Alex'
        }

        $result | Should -Be 'speaker-list'
        $script:Calls | Should -HaveCount 4
        $script:Calls[0].Method | Should -Be 'OpenSession'
        $script:Calls[0].Body   | Should -Be '["rec-1"]'
        $script:Calls[1].Method | Should -Be 'RenameSpeaker'
        $script:Calls[1].Body   | Should -Be '["session-abc",[[[2],"Alex"]]]'
        $script:Calls[2].Method | Should -Be 'SaveAudio'
        $script:Calls[2].Body   | Should -Be '["session-abc",[[["Meeting Title"]],["rec-1"]]]'
        $script:Calls[3].Method | Should -Be 'CloseSession'
        $script:Calls[3].Body   | Should -Be '["session-abc"]'
    }

    It 'resolves recordings by title and processes each result' {
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
        $sessionQueue = [System.Collections.Generic.Queue[string]]::new()
        $sessionQueue.Enqueue('session-one')
        $sessionQueue.Enqueue('session-two')

        Mock -ModuleName GoogleRecorderClient Invoke-EditingRpc {
            param($Method, $Body)
            $script:Calls += [pscustomobject]@{ Method = $Method; Body = $Body }

            if ($Method -eq 'OpenSession') {
                return @($sessionQueue.Dequeue())
            }

            return $null
        }

        InModuleScope GoogleRecorderClient {
            Rename-GoogleRecordingSpeaker -Title 'Standup*' -SpeakerId 1 -NewName 'Alex'
        }

        $script:Calls | Should -HaveCount 8
        ($script:Calls | Where-Object Method -eq 'SaveAudio').Body |
            Should -Contain '["session-one",[[["One"]],["rec-1"]]]'
        ($script:Calls | Where-Object Method -eq 'SaveAudio').Body |
            Should -Contain '["session-two",[[["Two"]],["rec-2"]]]'
    }

    It 'supports -WhatIf and skips RPC calls' {
        $session = New-FakeSession
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $session }

        Mock -ModuleName GoogleRecorderClient Assert-RecorderSession { }
        Mock -ModuleName GoogleRecorderClient Invoke-EditingRpc { throw 'Should not be called' }

        Mock -ModuleName GoogleRecorderClient Get-GoogleRecording {
            return [pscustomobject]@{ RecordingId = 'rec-1'; Title = 'Title' }
        }

        InModuleScope GoogleRecorderClient {
            Rename-GoogleRecordingSpeaker -RecordingId 'rec-1' -SpeakerId 1 -NewName 'Alex' -WhatIf
        }

        Should -Invoke -ModuleName GoogleRecorderClient Invoke-EditingRpc -Times 0
    }
}
