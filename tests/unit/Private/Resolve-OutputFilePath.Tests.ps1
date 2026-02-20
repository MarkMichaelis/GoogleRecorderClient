BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'GoogleRecorderClient' 'GoogleRecorderClient.psd1'
    Import-Module (Resolve-Path $modulePath) -Force -ErrorAction Stop
}

Describe 'Resolve-OutputFilePath' {
    It 'appends BaseName and Extension when OutputPath is a directory' {
        $result = InModuleScope GoogleRecorderClient {
            param($dir)
            Resolve-OutputFilePath -OutputPath $dir -BaseName 'rec-123' -Extension '.m4a'
        } -ArgumentList $TestDrive

        $expected = Join-Path $TestDrive 'rec-123.m4a'
        $result | Should -Be $expected
    }

    It 'returns the file path as-is when OutputPath is a file path' {
        $expected = Join-Path $TestDrive 'output.m4a'

        $result = InModuleScope GoogleRecorderClient {
            param($path)
            Resolve-OutputFilePath -OutputPath $path -BaseName 'rec-123' -Extension '.m4a'
        } -ArgumentList $expected

        $result | Should -Be $expected
    }

    It 'throws when the parent directory does not exist' {
        $badPath = Join-Path $TestDrive 'nonexistent' 'file.m4a'

        {
            InModuleScope GoogleRecorderClient {
                param($path)
                Resolve-OutputFilePath -OutputPath $path -BaseName 'rec-123' -Extension '.m4a'
            } -ArgumentList $badPath
        } | Should -Throw '*Directory not found*'
    }

    It 'throws when file exists and -Force is not set' {
        $existingFile = Join-Path $TestDrive 'exists.m4a'
        Set-Content -Path $existingFile -Value 'data'

        {
            InModuleScope GoogleRecorderClient {
                param($path)
                Resolve-OutputFilePath -OutputPath $path -BaseName 'rec-123' -Extension '.m4a'
            } -ArgumentList $existingFile
        } | Should -Throw '*File already exists*'
    }

    It 'returns path when file exists and -Force is set' {
        $existingFile = Join-Path $TestDrive 'force.m4a'
        Set-Content -Path $existingFile -Value 'data'

        $result = InModuleScope GoogleRecorderClient {
            param($path)
            Resolve-OutputFilePath -OutputPath $path -BaseName 'rec-123' -Extension '.m4a' -Force
        } -ArgumentList $existingFile

        $result | Should -Be $existingFile
    }

    It 'auto-generates filename in directory even with extension in BaseName' {
        $result = InModuleScope GoogleRecorderClient {
            param($dir)
            Resolve-OutputFilePath -OutputPath $dir -BaseName 'my-recording' -Extension '.txt'
        } -ArgumentList $TestDrive

        $expected = Join-Path $TestDrive 'my-recording.txt'
        $result | Should -Be $expected
    }
}
