BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
    . (Join-Path $PSScriptRoot '..' '..' 'helpers' 'TestData.ps1')
}

Describe 'Set-GoogleRecordingSpeaker' {
    AfterEach {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
    }

    It 'throws when not connected' {
        Mock -ModuleName GoogleRecorderClient Assert-RecorderSession { throw 'Not connected' }

        {
            InModuleScope GoogleRecorderClient {
                Set-GoogleRecordingSpeaker -RecordingId 'rec-1' -SegmentIndex 1 -TargetSpeakerId 2
            }
        } | Should -Throw '*Not connected*'
    }

    It 'switches segments to an existing speaker and saves audio' {
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
                'OpenSession'    { return @('session-one') }
                'SwitchSpeaker'  { return 'switch-result' }
                default          { return $null }
            }
        }

        $result = InModuleScope GoogleRecorderClient {
            Set-GoogleRecordingSpeaker -RecordingId 'rec-1' -SegmentIndex @(5,6) -TargetSpeakerId 3
        }

        $result | Should -Be 'switch-result'
        $script:Calls | Should -HaveCount 4
        $script:Calls[0].Method | Should -Be 'OpenSession'
        $script:Calls[0].Body   | Should -Be '["rec-1"]'
        $script:Calls[1].Method | Should -Be 'SwitchSpeaker'
        $script:Calls[1].Body   | Should -Be '["session-one",[5,6],[[3]]]'
        $script:Calls[2].Method | Should -Be 'SaveAudio'
        $script:Calls[2].Body   | Should -Be '["session-one",[[["Meeting Title"]],["rec-1"]]]'
        $script:Calls[3].Method | Should -Be 'CloseSession'
        $script:Calls[3].Body   | Should -Be '["session-one"]'
    }

    It 'creates a new speaker by name when TargetSpeakerName is provided' {
        $session = New-FakeSession
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $session }

        Mock -ModuleName GoogleRecorderClient Assert-RecorderSession { }
        Mock -ModuleName GoogleRecorderClient Get-GoogleRecording {
            return [pscustomobject]@{ RecordingId = 'rec-9'; Title = 'One-Off' }
        }

        $script:Calls = @()
        Mock -ModuleName GoogleRecorderClient Invoke-EditingRpc {
            param($Method, $Body)
            $script:Calls += [pscustomobject]@{ Method = $Method; Body = $Body }

            if ($Method -eq 'OpenSession') { return @('session-new') }
            return $null
        }

        InModuleScope GoogleRecorderClient {
            Set-GoogleRecordingSpeaker -RecordingId 'rec-9' -SegmentIndex 4 -TargetSpeakerName 'Alex'
        }

        ($script:Calls | Where-Object Method -eq 'SwitchSpeaker').Body |
            Should -Be '["session-new",[4],["Alex"]]'
    }

    It 'resolves by title and processes each recording' {
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
            Set-GoogleRecordingSpeaker -Title 'Standup*' -SegmentIndex 1 -TargetSpeakerId 2
        }

        ($script:Calls | Where-Object Method -eq 'SaveAudio').Body |
            Should -Contain '["session-one",[[["One"]],["rec-1"]]]'
        ($script:Calls | Where-Object Method -eq 'SaveAudio').Body |
            Should -Contain '["session-two",[[["Two"]],["rec-2"]]]'
    }

    It 'supports -WhatIf and skips RPC calls' {
        $session = New-FakeSession
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $session }

        Mock -ModuleName GoogleRecorderClient Assert-RecorderSession { }
        Mock -ModuleName GoogleRecorderClient Get-GoogleRecording {
            return [pscustomobject]@{ RecordingId = 'rec-1'; Title = 'Title' }
        }
        Mock -ModuleName GoogleRecorderClient Invoke-EditingRpc { throw 'Should not call' }

        InModuleScope GoogleRecorderClient {
            Set-GoogleRecordingSpeaker -RecordingId 'rec-1' -SegmentIndex 3 -TargetSpeakerId 1 -WhatIf
        }

        Should -Invoke -ModuleName GoogleRecorderClient Invoke-EditingRpc -Times 0
    }
}
