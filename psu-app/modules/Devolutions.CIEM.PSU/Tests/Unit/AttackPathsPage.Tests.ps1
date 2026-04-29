BeforeAll {
    $script:PageContent = Get-Content (Join-Path $PSScriptRoot '..' '..' 'Pages' 'New-CIEMAttackPathsPage.ps1') -Raw
    $script:ScriptManifestContent = Get-Content (Join-Path $PSScriptRoot '..' '..' '..' '..' 'data' 'psu-scripts.json') -Raw
}

Describe 'Attack Paths page refresh action' {
    It 'Displays a refresh button on the Attack Paths page' {
        $script:PageContent | Should -Match "New-UDButton[\s\S]*-Id\s+'refreshAttackPathsBtn'"
        $script:PageContent | Should -Match "-Text\s+'Refresh Attack Paths'"
    }

    It 'Materializes attack paths and reloads the Attack Paths panel after refresh' {
        $script:PageContent | Should -Match 'Devolutions\.CIEM\\Update-CIEMAttackPath\s+-PassThru'
        $script:PageContent | Should -Match "Sync-UDElement\s+-Id\s+'attackPathsPanel'"
        $script:PageContent | Should -Match 'Show-UDToast[\s\S]*Attack paths refreshed'
    }
}

Describe 'Attack Paths page remediation execution action' {
    It 'Displays an execute button alongside the remediation script copy button' {
        $script:PageContent | Should -Match "'data-ciem-attack-path-remediation-script-copy'\s*=\s*'true'"
        $script:PageContent | Should -Match "'data-ciem-attack-path-remediation-script-execute'\s*=\s*'true'"
        $script:PageContent | Should -Match "New-UDButton[\s\S]*-Text\s+'Execute'"
    }

    It 'Renders copy and execute controls in a shared horizontal action group' {
        $script:PageContent | Should -Match "'data-ciem-attack-path-remediation-script-actions'\s*=\s*'true'"
        $script:PageContent | Should -Match "width\s*=\s*'112px'"
        $script:PageContent | Should -Match "minWidth\s*=\s*'112px'"
        $script:PageContent | Should -Match "display\s*=\s*'flex'"
        $script:PageContent | Should -Match "alignItems\s*=\s*'center'"
        $script:PageContent | Should -Match "gap\s*=\s*'8px'"
    }

    It 'Starts the remediation as a PSU job and streams job stream output into the execution modal' {
        $script:PageContent | Should -Match "Invoke-PSUScript[\s\S]*-Name\s+'Checks/Invoke-CIEMAttackPathRemediation'"
        $script:PageContent | Should -Match "Devolutions\.CIEM\\Get-CIEMPSUJobOutput[\s\S]*-Integrated"
        $script:PageContent | Should -Match "New-UDDynamic[\s\S]*-AutoRefresh[\s\S]*-AutoRefreshInterval\s+1"
        $script:PageContent | Should -Match "'data-ciem-attack-path-execution-dialog'\s*=\s*'true'"
        $script:PageContent | Should -Match "'data-ciem-attack-path-execution-script'\s*=\s*'true'"
        $script:PageContent | Should -Match "'data-ciem-attack-path-execution-streams'\s*=\s*'true'"
    }

    It 'Does not mix pipeline output into the Streams textbox' {
        $script:PageContent | Should -Not -Match 'Get-PSUJobPipelineOutput'
    }

    It 'Delegates job output cleanup to the PSU job output helper' {
        $script:PageContent | Should -Match 'Devolutions\.CIEM\\Get-CIEMPSUJobOutput[\s\S]*-Job\s+\$job[\s\S]*-Integrated'
        $script:PageContent | Should -Not -Match 'Get-PSUJobOutput[\s\S]*-AsObject'
        $script:PageContent | Should -Not -Match '\[regex\]::Replace\(\$message, \$ansiEscapePattern, ''''\)'
        $script:PageContent | Should -Not -Match '\$streamLines\.Add\("\[stream\] \$entry"\)'
    }

    It 'Registers the PSU script used by the execution button' {
        $script:ScriptManifestContent | Should -Match '"name"\s*:\s*"Checks/Invoke-CIEMAttackPathRemediation"'
        $script:ScriptManifestContent | Should -Match '"path"\s*:\s*"Checks/Invoke-CIEMAttackPathRemediation.ps1"'
    }

    It 'Keeps the page-invoked remediation PSU script manually invokable' {
        $manifest = $script:ScriptManifestContent | ConvertFrom-Json -Depth 10
        $scripts = @($manifest.scripts | Where-Object { $_.name -eq 'Checks/Invoke-CIEMAttackPathRemediation' })
        $scripts | Should -HaveCount 1
        [bool]$scripts[0].disableManualInvocation | Should -BeFalse
    }

    It 'Warns before closing a running remediation and can terminate the PSU job' {
        $script:PageContent | Should -Match "Stop-PSUJob[\s\S]*-Integrated"
        $script:PageContent | Should -Match "'data-ciem-attack-path-execution-close-warning'\s*=\s*'true'"
        $script:PageContent | Should -Match "'data-ciem-attack-path-execution-terminate'\s*=\s*'true'"
        $script:PageContent | Should -Match "'data-ciem-attack-path-execution-leave-running'\s*=\s*'true'"
    }
}
