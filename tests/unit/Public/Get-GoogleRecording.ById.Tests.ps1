BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
    . (Join-Path $PSScriptRoot '..' '..' 'helpers' 'TestData.ps1')
}

Describe 'Get-GoogleRecording -RecordingId' {
    AfterEach {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
    }

    It 'throws when not connected' {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
        Mock -ModuleName GoogleRecorderClient Test-Path { $false }

        { Get-GoogleRecording -RecordingId 'some-id' } | Should -Throw '*Not connected*'
    }

    It 'calls GetRecordingInfo RPC with the recording ID' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'
                ApiKey       = 'k'
                Email        = 'x'
                BaseUrl      = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            param($Method, $Body)
            $Method | Should -Be 'GetRecordingInfo'
            $Body | Should -Be '["test-rec-id"]'

            $fakeRaw = [object[]]::new(25)
            $fakeRaw[0]  = 'uuid'
            $fakeRaw[1]  = 'Single Recording'
            $fakeRaw[2]  = @('1771181693', 0)
            $fakeRaw[3]  = @('120', 0)
            $fakeRaw[4]  = 47.6
            $fakeRaw[5]  = -117.2
            $fakeRaw[6]  = 'Spokane'
            $fakeRaw[13] = 'test-rec-id'
            return ,@(
                $fakeRaw,
                1,
                $null,
                'https://usercontent.recorder.google.com/download/playback/test-rec-id',
                1
            )
        }

        $result = Get-GoogleRecording -RecordingId 'test-rec-id'

        $result.Title       | Should -Be 'Single Recording'
        $result.RecordingId | Should -Be 'test-rec-id'
    }

    It 'includes AudioDownloadUrl from GetRecordingInfo response' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'
                ApiKey       = 'k'
                Email        = 'x'
                BaseUrl      = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            $fakeRaw = [object[]]::new(25)
            $fakeRaw[0]  = 'uuid'
            $fakeRaw[1]  = 'Test'
            $fakeRaw[2]  = @('1771181693', 0)
            $fakeRaw[3]  = @('60', 0)
            $fakeRaw[13] = 'rec-123'
            return ,@(
                $fakeRaw,
                1,
                $null,
                'https://usercontent.recorder.google.com/download/playback/rec-123',
                1
            )
        }

        $result = Get-GoogleRecording -RecordingId 'rec-123'

        $result.AudioDownloadUrl | Should -Be 'https://usercontent.recorder.google.com/download/playback/rec-123'
    }

    It 'throws when recording is not found' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'
                ApiKey       = 'k'
                Email        = 'x'
                BaseUrl      = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc { return ,@() }

        { Get-GoogleRecording -RecordingId 'nonexistent' } | Should -Throw '*not found*'
    }

    It 'accepts RecordingId from pipeline by property name' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SAPISID=val'
                ApiKey       = 'k'
                Email        = 'x'
                BaseUrl      = 'https://example.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-RecorderRpc {
            $fakeRaw = [object[]]::new(25)
            $fakeRaw[0]  = 'uuid'
            $fakeRaw[1]  = 'Piped'
            $fakeRaw[2]  = @('1771181693', 0)
            $fakeRaw[3]  = @('60', 0)
            $fakeRaw[13] = 'pipe-id'
            return ,@($fakeRaw, 1, $null, 'https://example.com/dl', 1)
        }

        $input = [PSCustomObject]@{ RecordingId = 'pipe-id' }
        $result = $input | Get-GoogleRecording

        $result.RecordingId | Should -Be 'pipe-id'
    }
}
