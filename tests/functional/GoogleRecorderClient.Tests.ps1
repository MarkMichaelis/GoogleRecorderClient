BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
}

Describe 'Module structure' -Tag 'Functional' {
    It 'exports exactly 3 commands' {
        $commands = Get-Command -Module GoogleRecorderClient
        $commands.Count | Should -Be 3
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

    It 'does not export private functions' {
        $commands = Get-Command -Module GoogleRecorderClient
        $commands.Name | Should -Not -Contain 'Invoke-RecorderRpc'
        $commands.Name | Should -Not -Contain 'Get-SapisIdHash'
        $commands.Name | Should -Not -Contain 'Format-RawRecording'
        $commands.Name | Should -Not -Contain 'New-RecorderWebSession'
        $commands.Name | Should -Not -Contain 'ConvertFrom-ProtoTimestamp'
        $commands.Name | Should -Not -Contain 'Format-RecorderDuration'
        $commands.Name | Should -Not -Contain 'Get-UnixTimestamp'
    }
}

Describe 'Unauthenticated behavior' -Tag 'Functional' {
    BeforeAll {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
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

    AfterAll {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
        $cachePath = InModuleScope GoogleRecorderClient { Join-Path $script:ModuleRoot 'recorder-session.json' }
        if (Test-Path $cachePath) { Remove-Item $cachePath -Force -ErrorAction SilentlyContinue }
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
