BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
    . (Join-Path $PSScriptRoot '..' '..' 'helpers' 'TestData.ps1')
}

Describe 'Edit-GoogleRecordingAudio' {
    AfterEach {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
    }

    It 'throws when not connected' {
        Mock -ModuleName GoogleRecorderClient Assert-RecorderSession { throw 'Not connected' }

        {
            InModuleScope GoogleRecorderClient {
                Edit-GoogleRecordingAudio -RecordingId 'rec-1' -Crop -Start ([TimeSpan]::FromSeconds(1)) -End ([TimeSpan]::FromSeconds(2))
            }
        } | Should -Throw '*Not connected*'
    }

    It 'crops audio with start/end times and saves' {
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
            if ($Method -eq 'OpenSession') { return @('session-abc') }
            if ($Method -eq 'CropAudio') { return 'crop-result' }
            return $null
        }

        $result = InModuleScope GoogleRecorderClient {
            $localStart = New-TimeSpan -Minutes 1 -Seconds 2 -Milliseconds 250
            $localEnd   = New-TimeSpan -Minutes 2 -Seconds 5 -Milliseconds 125

            Edit-GoogleRecordingAudio -RecordingId 'rec-1' -Crop -Start $localStart -End $localEnd
        }

        $result | Should -Be 'crop-result'
        $script:Calls[1].Body | Should -Be '["session-abc",[[62,250000000],[125,125000000]]]'
        $script:Calls[2].Body | Should -Be '["session-abc",[[["Meeting"]],["rec-1"]]]'
        $script:Calls[3].Body | Should -Be '["session-abc"]'
    }

    It 'removes audio when -Remove is specified' {
        $session = New-FakeSession
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $session }

        Mock -ModuleName GoogleRecorderClient Assert-RecorderSession { }
        Mock -ModuleName GoogleRecorderClient Get-GoogleRecording {
            return [pscustomobject]@{ RecordingId = 'rec-9'; Title = 'Lecture' }
        }

        $script:Calls = @()
        Mock -ModuleName GoogleRecorderClient Invoke-EditingRpc {
            param($Method, $Body)
            $script:Calls += [pscustomobject]@{ Method = $Method; Body = $Body }
            if ($Method -eq 'OpenSession') { return @('session-rm') }
            if ($Method -eq 'RemoveAudio') { return 'remove-result' }
            return $null
        }

        $result = InModuleScope GoogleRecorderClient {
            Edit-GoogleRecordingAudio -RecordingId 'rec-9' -Remove -Start ([TimeSpan]::FromSeconds(10)) -End ([TimeSpan]::FromSeconds(20))
        }

        $result | Should -Be 'remove-result'
        ($script:Calls | Where-Object Method -eq 'RemoveAudio').Body |
            Should -Be '["session-rm",[[10,0],[20,0]]]'
    }

    It 'resolves title and applies to each recording' {
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
            Edit-GoogleRecordingAudio -Title 'Daily*' -Crop -Start ([TimeSpan]::FromSeconds(1)) -End ([TimeSpan]::FromSeconds(2))
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
            return [pscustomobject]@{ RecordingId = 'rec-1'; Title = 'Title' }
        }
        Mock -ModuleName GoogleRecorderClient Invoke-EditingRpc { throw 'Should not call' }

        InModuleScope GoogleRecorderClient {
            Edit-GoogleRecordingAudio -RecordingId 'rec-1' -Remove -Start ([TimeSpan]::FromSeconds(1)) -End ([TimeSpan]::FromSeconds(2)) -WhatIf
        }

        Should -Invoke -ModuleName GoogleRecorderClient Invoke-EditingRpc -Times 0
    }
}
