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

    It 'does not download when -WhatIf is specified' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SID=abc; SAPISID=mno/pqr'
                ApiKey       = 'k'
                Email        = 'x'
                BaseUrl      = 'https://pixelrecorder-pa.clients6.google.com'
            }
        }

        Mock -ModuleName GoogleRecorderClient Invoke-WebRequest { }

        $testFile = Join-Path $TestDrive 'whatif.m4a'
        Save-GoogleRecordingAudio -RecordingId 'test-id' -OutputPath $testFile -WhatIf

        Should -Invoke -ModuleName GoogleRecorderClient Invoke-WebRequest -Times 0
    }

    It 'throws when file exists and -Force is not set' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SID=abc; SAPISID=mno/pqr'
                ApiKey       = 'k'
                Email        = 'x'
                BaseUrl      = 'https://pixelrecorder-pa.clients6.google.com'
            }
        }

        $existingFile = Join-Path $TestDrive 'existing.m4a'
        Set-Content -Path $existingFile -Value 'data'

        { Save-GoogleRecordingAudio -RecordingId 'test-id' -OutputPath $existingFile } |
            Should -Throw '*File already exists*'
    }

    It 'overwrites when file exists and -Force is set' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SID=abc; SAPISID=mno/pqr'
                ApiKey       = 'k'
                Email        = 'x'
                BaseUrl      = 'https://pixelrecorder-pa.clients6.google.com'
            }
        }

        $existingFile = Join-Path $TestDrive 'force.m4a'
        Set-Content -Path $existingFile -Value 'old data'

        Mock -ModuleName GoogleRecorderClient Invoke-WebRequest { }

        Save-GoogleRecordingAudio -RecordingId 'test-id' -OutputPath $existingFile -Force

        Should -Invoke -ModuleName GoogleRecorderClient Invoke-WebRequest -Times 1
    }

    It 'throws when parent directory does not exist' {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SID=abc; SAPISID=mno/pqr'
                ApiKey       = 'k'
                Email        = 'x'
                BaseUrl      = 'https://pixelrecorder-pa.clients6.google.com'
            }
        }

        $badPath = Join-Path $TestDrive 'nonexistent' 'output.m4a'

        { Save-GoogleRecordingAudio -RecordingId 'test-id' -OutputPath $badPath } |
            Should -Throw '*Directory not found*'
    }
}
