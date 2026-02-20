BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
}

Describe 'Module structure' -Tag 'Functional' {
    It 'exports exactly 11 commands' {
        $commands = Get-Command -Module GoogleRecorderClient
        $commands.Count | Should -Be 11
    }

    It 'exports Connect-GoogleRecorder' {
        Get-Command -Module GoogleRecorderClient -Name Connect-GoogleRecorder |
            Should -Not -BeNullOrEmpty
    }

    It 'exports Disconnect-GoogleRecorder' {
        Get-Command -Module GoogleRecorderClient -Name Disconnect-GoogleRecorder |
            Should -Not -BeNullOrEmpty
    }

    It 'exports Get-GoogleRecording' {
        Get-Command -Module GoogleRecorderClient -Name Get-GoogleRecording |
            Should -Not -BeNullOrEmpty
    }

    It 'exports Get-GoogleRecorderLabel' {
        Get-Command -Module GoogleRecorderClient -Name Get-GoogleRecorderLabel |
            Should -Not -BeNullOrEmpty
    }

    It 'exports Get-GoogleRecordingAudioTag' {
        Get-Command -Module GoogleRecorderClient -Name Get-GoogleRecordingAudioTag |
            Should -Not -BeNullOrEmpty
    }

    It 'exports Get-GoogleRecordingShare' {
        Get-Command -Module GoogleRecorderClient -Name Get-GoogleRecordingShare |
            Should -Not -BeNullOrEmpty
    }

    It 'exports Get-GoogleRecordingTranscript' {
        Get-Command -Module GoogleRecorderClient -Name Get-GoogleRecordingTranscript |
            Should -Not -BeNullOrEmpty
    }

    It 'exports Get-GoogleRecordingWaveform' {
        Get-Command -Module GoogleRecorderClient -Name Get-GoogleRecordingWaveform |
            Should -Not -BeNullOrEmpty
    }

    It 'exports Rename-GoogleRecording' {
        Get-Command -Module GoogleRecorderClient -Name Rename-GoogleRecording |
            Should -Not -BeNullOrEmpty
    }

    It 'exports Save-GoogleRecordingAudio' {
        Get-Command -Module GoogleRecorderClient -Name Save-GoogleRecordingAudio |
            Should -Not -BeNullOrEmpty
    }

    It 'exports Test-GoogleRecorderSearch' {
        Get-Command -Module GoogleRecorderClient -Name Test-GoogleRecorderSearch |
            Should -Not -BeNullOrEmpty
    }

    It 'does not export private functions' {
        $commands = Get-Command -Module GoogleRecorderClient
        $commands.Name | Should -Not -Contain 'Invoke-RecorderRpc'
        $commands.Name | Should -Not -Contain 'Get-SapisIdHash'
        $commands.Name | Should -Not -Contain 'Format-RawRecording'
        $commands.Name | Should -Not -Contain 'New-RecorderWebSession'
        $commands.Name | Should -Not -Contain 'ConvertFrom-ProtoTimestamp'
        $commands.Name | Should -Not -Contain 'Format-RecorderDuration'
        $commands.Name | Should -Not -Contain 'Get-UnixTimestamp'
        $commands.Name | Should -Not -Contain 'Get-SingleRecording'
        $commands.Name | Should -Not -Contain 'Get-RecordingList'
        $commands.Name | Should -Not -Contain 'Resolve-OutputFilePath'
        $commands.Name | Should -Not -Contain 'Build-AudioDownloadHeaders'
    }
}

Describe 'Unauthenticated behavior' -Tag 'Functional' {
    BeforeAll {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
        Mock -ModuleName GoogleRecorderClient Test-Path { $false }
    }

    It 'Get-GoogleRecording throws a helpful message when not connected' {
        { Get-GoogleRecording } | Should -Throw '*Not connected*Connect-GoogleRecorder*'
    }
}

Describe 'Session lifecycle' -Tag 'Functional' {
    BeforeAll {
        # Mock external calls to avoid real HTTP traffic
        Mock -ModuleName GoogleRecorderClient Invoke-ClientConfigRequest {
            return @{
                apiKey           = 'func-test-key'
                email            = 'functional@test.com'
                firstPartyApiUrl = 'https://pixelrecorder-pa.clients6.google.com'
            }
        }
    }

    BeforeEach {
        # Backup real cache before each test that creates cache files
        $script:CachePath  = InModuleScope GoogleRecorderClient { Join-Path $script:ModuleRoot 'recorder-session.json' }
        $script:BackupPath = "$($script:CachePath).bak"
        if (Test-Path $script:CachePath) {
            Copy-Item $script:CachePath $script:BackupPath -Force
        }
    }

    AfterEach {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
        # Restore real cache after each test
        if (Test-Path $script:BackupPath) {
            Copy-Item $script:BackupPath $script:CachePath -Force
            Remove-Item $script:BackupPath -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Connect then Disconnect clears the session' {
        Connect-GoogleRecorder -CookieHeader 'SID=abc; SAPISID=xyz' -ApiKey 'k'

        $connected = InModuleScope GoogleRecorderClient { $null -ne $script:RecorderSession }
        $connected | Should -BeTrue

        Disconnect-GoogleRecorder

        $session = InModuleScope GoogleRecorderClient { $script:RecorderSession }
        $session | Should -BeNullOrEmpty
    }

    It 'Connect with -CookieHeader/-ApiKey sets email from clientconfig' {
        Connect-GoogleRecorder -CookieHeader 'SID=abc' -ApiKey 'k'

        $session = InModuleScope GoogleRecorderClient { $script:RecorderSession }
        $session.Email | Should -Be 'functional@test.com'
    }
}

Describe 'Recording retrieval with mock API' -Tag 'Functional' {
    BeforeAll {
        # Set session directly
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SID=abc; SAPISID=test/value'
                ApiKey       = 'test-key'
                Email        = 'func@test.com'
                BaseUrl      = 'https://pixelrecorder-pa.clients6.google.com'
            }
        }

        # Mock the RPC to return realistic data
        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            $rec1 = [object[]]::new(25)
            $rec1[0]  = 'uuid-1'
            $rec1[1]  = 'Morning Standup'
            $rec1[2]  = @('1771181693', 323000000)
            $rec1[3]  = @('978', 200000000)
            $rec1[4]  = 47.629
            $rec1[5]  = -117.216
            $rec1[6]  = 'Spokane Valley, Washington'
            $rec1[13] = 'rec-001'
            $rec1[20] = @(,@('1 Alice', '2 Bob'))

            $rec2 = [object[]]::new(25)
            $rec2[0]  = 'uuid-2'
            $rec2[1]  = 'Afternoon Notes'
            $rec2[2]  = @('1771100000', 0)
            $rec2[3]  = @('300', 0)
            $rec2[4]  = 47.6
            $rec2[5]  = -117.4
            $rec2[6]  = 'Spokane, WA'
            $rec2[13] = 'rec-002'

            return ,@(@($rec1, $rec2), 0)
        }
    }

    AfterAll {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
    }

    It 'returns recording objects with required properties' {
        $recordings = @(Get-GoogleRecording -First 2)

        $recordings.Count | Should -Be 2
        $recordings[0].Title       | Should -Be 'Morning Standup'
        $recordings[0].RecordingId | Should -Be 'rec-001'
        $recordings[0].Location    | Should -Be 'Spokane Valley, Washington'
        $recordings[0].Duration    | Should -Be '16:18'
        $recordings[0].Created     | Should -BeOfType [datetime]
        $recordings[0].Speakers    | Should -Contain 'Alice'
        $recordings[0].Speakers    | Should -Contain 'Bob'
        $recordings[0].Url         | Should -Be 'https://recorder.google.com/rec-001'
    }

    It 'objects have GoogleRecorder.Recording type' {
        $recordings = @(Get-GoogleRecording -First 1)

        $recordings[0].PSTypeNames | Should -Contain 'GoogleRecorder.Recording'
    }

    It 'supports pipeline filtering' {
        $spokane = Get-GoogleRecording | Where-Object Location -like '*Spokane Valley*'

        @($spokane).Count | Should -Be 1
        $spokane.Title | Should -Be 'Morning Standup'
    }
}

Describe 'Unauthenticated behavior for new functions' -Tag 'Functional' {
    BeforeAll {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
        Mock -ModuleName GoogleRecorderClient Test-Path { $false }
    }

    It 'Get-GoogleRecorderLabel throws when not connected' {
        { Get-GoogleRecorderLabel } | Should -Throw '*Not connected*'
    }

    It 'Get-GoogleRecordingTranscript throws when not connected' {
        { Get-GoogleRecordingTranscript -RecordingId 'x' } | Should -Throw '*Not connected*'
    }

    It 'Get-GoogleRecordingShare throws when not connected' {
        { Get-GoogleRecordingShare -RecordingId 'x' } | Should -Throw '*Not connected*'
    }

    It 'Get-GoogleRecordingAudioTag throws when not connected' {
        { Get-GoogleRecordingAudioTag -RecordingId 'x' } | Should -Throw '*Not connected*'
    }

    It 'Get-GoogleRecordingWaveform throws when not connected' {
        { Get-GoogleRecordingWaveform -RecordingId 'x' } | Should -Throw '*Not connected*'
    }

    It 'Rename-GoogleRecording throws when not connected' {
        { Rename-GoogleRecording -RecordingId 'x' -NewTitle 'y' } | Should -Throw '*Not connected*'
    }

    It 'Save-GoogleRecordingAudio throws when not connected' {
        { Save-GoogleRecordingAudio -RecordingId 'x' -OutputPath 'c:\temp' } | Should -Throw '*Not connected*'
    }

    It 'Test-GoogleRecorderSearch throws when not connected' {
        { Test-GoogleRecorderSearch } | Should -Throw '*Not connected*'
    }
}

Describe 'Rename-GoogleRecording with mock API' -Tag 'Functional' {
    BeforeAll {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SID=abc; SAPISID=test/value'
                ApiKey       = 'test-key'
                Email        = 'func@test.com'
                BaseUrl      = 'https://pixelrecorder-pa.clients6.google.com'
            }
        }
    }

    AfterAll {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
    }

    It 'calls UpdateRecordingTitle and does not throw' {
        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc { return $null }

        { Rename-GoogleRecording -RecordingId 'test-rec' -NewTitle 'Test Test Test' } |
            Should -Not -Throw

        Should -Invoke -ModuleName GoogleRecorderClient Invoke-RecorderRpc -Times 1 -Exactly
    }

    It 'supports -WhatIf to preview without calling API' {
        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc { return $null }

        Rename-GoogleRecording -RecordingId 'test-rec' -NewTitle 'Test Test Test' -WhatIf

        Should -Invoke -ModuleName GoogleRecorderClient Invoke-RecorderRpc -Times 0 -Exactly
    }
}

Describe 'Pipeline integration across functions' -Tag 'Functional' {
    BeforeAll {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SID=abc; SAPISID=test/value'
                ApiKey       = 'test-key'
                Email        = 'func@test.com'
                BaseUrl      = 'https://pixelrecorder-pa.clients6.google.com'
            }
        }
    }

    AfterAll {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
    }

    It 'Get-GoogleRecording pipes into Get-GoogleRecordingTranscript' {
        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            param($Method)
            if ($Method -eq 'GetRecordingList') {
                $rec = [object[]]::new(25)
                $rec[0] = 'uuid-1'; $rec[1] = 'Test'; $rec[13] = 'rec-pipe'
                $rec[2] = @('1771181693', 0); $rec[3] = @('60', 0)
                return ,@(,@($rec), 0)
            }
            if ($Method -eq 'GetTranscription') {
                return ,@(,@(,@(,@(
                    @('hi','Hi.','0','500',$null,$null,@(1,1)),
                    @('there','there.','500','1000',$null,$null,@(1,1))
                ))))
            }
        }

        $result = Get-GoogleRecording -First 1 | Get-GoogleRecordingTranscript -AsText

        $result | Should -BeLike '*Hi.*'
    }
}
