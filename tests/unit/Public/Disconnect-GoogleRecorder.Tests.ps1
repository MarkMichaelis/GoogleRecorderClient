BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop

    # Preserve real credential cache so tests don't destroy it
    $script:CachePath  = InModuleScope GoogleRecorderClient { Join-Path $script:ModuleRoot 'recorder-session.json' }
    $script:BackupPath = "$($script:CachePath).bak"
    if (Test-Path $script:CachePath) {
        Copy-Item $script:CachePath $script:BackupPath -Force
    }
}

AfterAll {
    # Restore the real credential cache
    if (Test-Path $script:BackupPath) {
        Copy-Item $script:BackupPath $script:CachePath -Force
        Remove-Item $script:BackupPath -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Disconnect-GoogleRecorder' {
    BeforeEach {
        InModuleScope GoogleRecorderClient {
            $script:RecorderSession = @{
                CookieHeader = 'SID=abc'
                ApiKey       = 'key'
                Email        = 'x@y.com'
                BaseUrl      = 'https://example.com'
            }
        }
    }

    It 'clears the in-memory session' {
        Disconnect-GoogleRecorder

        $session = InModuleScope GoogleRecorderClient { $script:RecorderSession }
        $session | Should -BeNullOrEmpty
    }

    It 'removes cache file when -RemoveCache is specified' {
        $cachePath = InModuleScope GoogleRecorderClient { Join-Path $script:ModuleRoot 'recorder-session.json' }
        # Create a temp cache file
        '{}' | Set-Content -Path $cachePath -Force

        Disconnect-GoogleRecorder -RemoveCache

        Test-Path $cachePath | Should -BeFalse
    }

    It 'does not throw when cache file does not exist' {
        { Disconnect-GoogleRecorder -RemoveCache } | Should -Not -Throw
    }
}
