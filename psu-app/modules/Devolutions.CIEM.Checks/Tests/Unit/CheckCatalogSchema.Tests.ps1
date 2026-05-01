BeforeAll {
    $script:ModuleRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' '..')
    $script:ProviderNames = @('Azure', 'AWS')
    $script:AllowedExecutionModes = @('script', 'rule', 'manual', 'notImplemented')
    $script:AllowedSeverities = @('critical', 'high', 'medium', 'low')

    $script:CatalogPaths = foreach ($providerName in $script:ProviderNames) {
        Join-Path $script:ModuleRoot 'modules' $providerName 'Checks' 'check_catalog.json'
    }

    $script:CatalogRows = @(
        foreach ($providerName in $script:ProviderNames) {
            $catalogPath = Join-Path $script:ModuleRoot 'modules' $providerName 'Checks' 'check_catalog.json'
            $index = 0
            foreach ($row in @(Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json)) {
                @{
                    Provider = $providerName
                    Id = [string]$row.Id
                    Service = [string]$row.Service
                    Severity = [string]$row.Severity
                    ExecutionMode = [string]$row.ExecutionMode
                    ManualReason = [string]$row.ManualReason
                    CheckScript = [string]$row.CheckScript
                    HasManualReasonProperty = ($row.PSObject.Properties.Name -contains 'ManualReason')
                    CatalogPath = $catalogPath
                    RowNumber = $index
                }
                $index++
            }
        }
    )

    $script:ScriptRows = @($script:CatalogRows | Where-Object { $_.ExecutionMode -eq 'script' })
    $script:NonScriptRows = @($script:CatalogRows | Where-Object { $_.ExecutionMode -in @('manual', 'notImplemented') })

    $script:ScriptFiles = @(
        foreach ($providerName in $script:ProviderNames) {
            $checksRoot = Join-Path $script:ModuleRoot 'modules' $providerName 'Checks'
            Get-ChildItem -LiteralPath $checksRoot -Filter '*.ps1' -File |
                ForEach-Object {
                    @{
                        Provider = $providerName
                        Name = $_.Name
                        Key = "$providerName/$($_.Name)"
                        FullName = $_.FullName
                    }
                }
        }
    )
}

Describe 'Provider check catalog schema' {
    It 'Every supported provider has a check catalog' {
        $script:CatalogPaths | Should -Exist
    }

    It 'Catalog row ids are unique across providers' {
        $duplicates = @(
            $script:CatalogRows |
                Group-Object Id |
                Where-Object Count -gt 1
        )

        $duplicates | Should -BeNullOrEmpty
    }

    It 'Every catalog row declares required metadata' {
        $invalidRows = @(
            $script:CatalogRows | Where-Object {
                [string]::IsNullOrWhiteSpace($_.Id) -or
                [string]::IsNullOrWhiteSpace($_.Service) -or
                $_.Severity -notin $script:AllowedSeverities
            } | ForEach-Object {
                "$($_.Provider)/$($_.Id)"
            }
        )

        $invalidRows | Should -BeNullOrEmpty
    }

    It 'Every catalog row declares a valid execution mode' {
        $invalidRows = @(
            $script:CatalogRows | Where-Object {
                $_.ExecutionMode -notin $script:AllowedExecutionModes
            } | ForEach-Object {
                "$($_.Provider)/$($_.Id)"
            }
        )

        $invalidRows | Should -BeNullOrEmpty
    }

    It 'Every catalog row declares the ManualReason property' {
        $invalidRows = @(
            $script:CatalogRows | Where-Object {
                -not $_.HasManualReasonProperty
            } | ForEach-Object {
                "$($_.Provider)/$($_.Id)"
            }
        )

        $invalidRows | Should -BeNullOrEmpty
    }

    It 'Every script catalog row points to an existing script' {
        $invalidRows = @(
            $script:ScriptRows | Where-Object {
                -not (Test-Path -LiteralPath (Join-Path $script:ModuleRoot 'modules' $_.Provider 'Checks' $_.CheckScript) -PathType Leaf)
            } | ForEach-Object {
                "$($_.Provider)/$($_.Id)"
            }
        )

        $invalidRows | Should -BeNullOrEmpty
    }

    It 'Every non-script catalog row omits a script' {
        $invalidRows = @(
            $script:NonScriptRows | Where-Object {
                -not [string]::IsNullOrWhiteSpace($_.CheckScript)
            } | ForEach-Object {
                "$($_.Provider)/$($_.Id)"
            }
        )

        $invalidRows | Should -BeNullOrEmpty
    }

    It 'Manual and notImplemented rows declare a reason' {
        $invalidRows = @(
            $script:NonScriptRows | Where-Object {
                [string]::IsNullOrWhiteSpace($_.ManualReason)
            } | ForEach-Object {
                "$($_.Provider)/$($_.Id)"
            }
        )

        $invalidRows | Should -BeNullOrEmpty
    }

    It 'Every remaining script has exactly one script catalog row' {
        $scriptKeys = @($script:ScriptFiles | ForEach-Object Key | Sort-Object)
        $catalogScriptKeys = @(
            $script:ScriptRows |
                ForEach-Object { "$($_.Provider)/$($_.CheckScript)" } |
                Sort-Object
        )

        Compare-Object -ReferenceObject $scriptKeys -DifferenceObject $catalogScriptKeys | Should -BeNullOrEmpty
    }

    It 'Provider check folders do not keep generated manual placeholder scripts' {
        $placeholderScripts = @(
            foreach ($scriptFile in $script:ScriptFiles) {
                if ((Get-Content -LiteralPath $scriptFile.FullName -Raw) -match 'This check requires manual implementation|TODO: Implement check logic from generated source') {
                    $scriptFile.FullName
                }
            }
        )

        $placeholderScripts | Should -BeNullOrEmpty
    }
}

Describe 'Provider check catalog execution modes' {
    BeforeAll {
        Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
        Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
    }

    BeforeEach {
        $script:TestDatabasePath = Join-Path $TestDrive ("ciem-" + [guid]::NewGuid().ToString('N') + '.db')
        $env:CIEM_TEST_DB_PATH = $script:TestDatabasePath
        New-CIEMDatabase -Path $script:TestDatabasePath

        InModuleScope Devolutions.CIEM {
            $script:DatabasePath = $env:CIEM_TEST_DB_PATH
        }
    }

    It 'Returns a deterministic skipped result for enabled notImplemented checks' {
        Enable-CIEMCheck -CheckId 'aks_cluster_rbac_enabled'

        $result = @(
            InModuleScope Devolutions.CIEM {
                InvokeCIEMScan -Provider Azure -CheckId 'aks_cluster_rbac_enabled'
            }
        )

        $result | Should -HaveCount 1
        [string]$result[0].Status | Should -Be 'SKIPPED'
        $result[0].StatusExtended | Should -Be 'Automated execution has not been implemented for this catalog check.'
        $result[0].ResourceId | Should -Be 'N/A'
        $result[0].ResourceName | Should -Be 'AKS cluster has RBAC enabled'
    }
}
