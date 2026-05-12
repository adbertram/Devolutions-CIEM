BeforeAll {
    $script:PagesRoot = Join-Path $PSScriptRoot '..' '..' 'Pages'
    $script:PageFiles = Get-ChildItem -Path $script:PagesRoot -Filter '*.ps1' | Sort-Object Name
    $script:ModuleCommandPattern = '^(Write-CIEMLog|Get-SeverityColor|Get-StatusColor|Get-PSUInstalledEnvironment|Invoke-CIEMJobWithProgress|New-CIEM(?:ErrorContent|InfoContent|SuccessContent)|Connect-CIEM|Send-CIEMNotification|Set-CIEMSecret|Save-CIEMAzureAuthenticationProfile|Set-CIEMAzureAuthenticationProfileActive|Set-CIEMAzureDiscoverySchedule|Set-CIEMAWSAuthenticationProfile|Set-CIEMNotification(?:AuthenticationProfile|Channel)?|Update-CIEMProvider|Invoke-CIEMQuery|Get-CIEM(?:AzureArmHierarchy|AzureAuthenticationProfile|AzureDiscoveryRun|AzureDiscoverySchedule|AzureIdentityHierarchy|AttackPath|AttackPathRemediationScript|Check|Config|ConnectorPayloadPreview|ExposureChange|IdentityRiskSignals|IdentityRiskSummary|Notification|NotificationAuthenticationProfile|NotificationChannel|NotificationHistory|PAMProgressSummary|PSUJobOutput|Provider|ProviderAuthMethod|ScanEfficiencySummary|ScanRun|Secret))$'
    $script:UnqualifiedCommands = foreach ($pageFile in $script:PageFiles) {
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($pageFile.FullName, [ref]$tokens, [ref]$parseErrors)

        if ($parseErrors.Count -gt 0) {
            throw "Failed to parse $($pageFile.Name): $($parseErrors[0].Message)"
        }

        foreach ($commandAst in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)) {
            $commandName = $commandAst.GetCommandName()
            if (-not $commandName) { continue }
            if ($commandName -notmatch $script:ModuleCommandPattern) { continue }

            [PSCustomObject]@{
                File    = $pageFile.Name
                Command = $commandName
            }
        }
    }
}

Describe 'PSU page command qualification' {
    It 'Qualifies Devolutions.CIEM commands used by PSU page endpoints' {
        $script:UnqualifiedCommands | Should -BeNullOrEmpty
    }
}
