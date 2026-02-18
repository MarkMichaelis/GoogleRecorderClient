BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
}

Describe 'Save-GoogleRecordingAudio' {
    AfterEach {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
    }

    It 'throws when not connected' {
        InModuleScope GoogleRecorderClient { $script:RecorderSession = $null }
        Mock -ModuleName GoogleRecorderClient Test-Path { $false }

        { Save-GoogleRecordingAudio -RecordingId 'some-id' -OutputPath 'test.m4a' } | Should -Throw '*Not connected*'
    }

    It 'calls the audio download URL with correct headers' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SID=abc; SAPISID=mno/pqr'
                ApiKey       = 'k'
                Email        = 'x'
                BaseUrl      = 'https://pixelrecorder-pa.clients6.google.com'
            }
        }

        $testFile = Join-Path $TestDrive 'test.m4a'

        Mock -ModuleName GoogleRecorderClient Invoke-WebRequest {
            # Simulate writing a file
            [byte[]]$fakeAudio = @(0xFF, 0xD8, 0xFF, 0xE0)
            Set-Content -Path $testFile -Value $fakeAudio -AsByteStream
        }

        Save-GoogleRecordingAudio -RecordingId 'test-id' -OutputPath $testFile

        Should -Invoke -ModuleName GoogleRecorderClient Invoke-WebRequest -Times 1
    }

    It 'auto-generates filename when only directory is specified' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SID=abc; SAPISID=mno/pqr'
                ApiKey       = 'k'
                Email        = 'x'
                BaseUrl      = 'https://pixelrecorder-pa.clients6.google.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-WebRequest { }

        # When OutputPath is a directory, expect auto-generated filename
        Save-GoogleRecordingAudio -RecordingId 'test-id' -OutputPath $TestDrive

        Should -Invoke -ModuleName GoogleRecorderClient Invoke-WebRequest -Times 1
    }

    It 'accepts RecordingId from pipeline by property name' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SID=abc; SAPISID=mno/pqr'
                ApiKey       = 'k'
                Email        = 'x'
                BaseUrl      = 'https://pixelrecorder-pa.clients6.google.com'
            }
        }

        $testFile = Join-Path $TestDrive 'piped.m4a'

        Mock -ModuleName GoogleRecorderClient Invoke-WebRequest { }

        $input = [PSCustomObject]@{ RecordingId = 'pipe-id' }
        $input | Save-GoogleRecordingAudio -OutputPath $testFile

        Should -Invoke -ModuleName GoogleRecorderClient Invoke-WebRequest -Times 1
    }
}
