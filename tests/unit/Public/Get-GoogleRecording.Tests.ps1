BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
    . (Join-Path $PSScriptRoot '..' '..' 'helpers' 'TestData.ps1')
}

Describe 'Get-GoogleRecording' {
    AfterEach {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
    }

    It 'throws when not connected' {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }

        { Get-GoogleRecording } | Should -Throw '*Not connected*'
    }

    It 'calls Invoke-RecorderRpc with GetRecordingList method' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'
                ApiKey       = 'k'
                Email        = 'x'
                BaseUrl      = 'https://example.com'
            }
        }

        # Mock the RPC call inside the module to return a fake response
        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            $fakeRaw = [object[]]::new(25)
            $fakeRaw[0]  = 'uuid'
            $fakeRaw[1]  = 'Test Title'
            $fakeRaw[2]  = @('1771181693', 0)
            $fakeRaw[3]  = @('60', 0)
            $fakeRaw[4]  = 0
            $fakeRaw[5]  = 0
            $fakeRaw[6]  = 'Test Location'
            $fakeRaw[13] = 'rec-id-1'
            return ,@(@(,$fakeRaw), 0)
        }

        $result = Get-GoogleRecording -First 1

        Should -InvokeVerifiable
        $result.Title | Should -Be 'Test Title'
        $result.RecordingId | Should -Be 'rec-id-1'
    }

    It 'respects -First parameter' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'
                ApiKey       = 'k'
                Email        = 'x'
                BaseUrl      = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            $recordings = @()
            for ($i = 1; $i -le 5; $i++) {
                $r = [object[]]::new(25)
                $r[0]  = "uuid-$i"
                $r[1]  = "Recording $i"
                $r[2]  = @('1771181693', 0)
                $r[3]  = @('60', 0)
                $r[4]  = 0
                $r[5]  = 0
                $r[6]  = 'Loc'
                $r[13] = "rec-$i"
                $recordings += ,$r
            }
            return ,@($recordings, 0)
        }

        $result = @(Get-GoogleRecording -First 2)

        $result.Count | Should -Be 2
    }
}
