BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
}

Describe 'Invoke-EditingSessionAction' {
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

    It 'runs OpenSession, action, SaveAudio, CloseSession in order' {
        InModuleScope GoogleRecorderClient {
            $script:EditingCallLog = @()
            Mock Invoke-EditingRpc {
                param($Method, $Body)
                $script:EditingCallLog += @{ Method = $Method; Body = $Body }
                switch ($Method) {
                    'OpenSession'  { return ,@('session-123') }
                    'TestAction'   { return ,@('action-result') }
                    'SaveAudio'    { return ,@('new-share-id') }
                    'CloseSession' { return $null }
                }
            }
            Mock Get-GoogleRecording {
                [PSCustomObject]@{ RecordingId = 'rec-1'; Title = 'My Rec' }
            }

            $result = Invoke-EditingSessionAction -RecordingId 'rec-1' -Action {
                param($SessionId)
                Invoke-EditingRpc -Method 'TestAction' -Body "[`"$SessionId`"]"
            }

            $script:EditingCallLog.Count | Should -Be 4
            $script:EditingCallLog[0].Method | Should -Be 'OpenSession'
            $script:EditingCallLog[0].Body | Should -Be '["rec-1"]'
            $script:EditingCallLog[2].Method | Should -Be 'SaveAudio'
            $script:EditingCallLog[2].Body | Should -Be '["session-123",[[["My Rec"]],["rec-1"]]]'
            $script:EditingCallLog[3].Method | Should -Be 'CloseSession'
            $script:EditingCallLog[3].Body | Should -Be '["session-123"]'
        }
    }

    It 'returns the result of the action scriptblock' {
        InModuleScope GoogleRecorderClient {
            Mock Invoke-EditingRpc {
                param($Method)
                switch ($Method) {
                    'OpenSession'  { return ,@('session-123') }
                    'SaveAudio'    { return ,@('new-share-id') }
                    'CloseSession' { return $null }
                }
            }
            Mock Get-GoogleRecording {
                [PSCustomObject]@{ RecordingId = 'rec-1'; Title = 'My Rec' }
            }

            $result = Invoke-EditingSessionAction -RecordingId 'rec-1' -Action {
                param($SessionId)
                return 'my-result'
            }

            $result | Should -Be 'my-result'
        }
    }

    It 'calls CloseSession even when action throws' {
        InModuleScope GoogleRecorderClient {
            $script:CloseSessionCalled = $false
            Mock Invoke-EditingRpc {
                param($Method)
                switch ($Method) {
                    'OpenSession'  { return ,@('session-123') }
                    'CloseSession' { $script:CloseSessionCalled = $true; return $null }
                }
            }
            Mock Get-GoogleRecording {
                [PSCustomObject]@{ RecordingId = 'rec-1'; Title = 'My Rec' }
            }

            { Invoke-EditingSessionAction -RecordingId 'rec-1' -Action {
                throw 'action failed'
            } } | Should -Throw '*action failed*'

            $script:CloseSessionCalled | Should -BeTrue
        }
    }
}
