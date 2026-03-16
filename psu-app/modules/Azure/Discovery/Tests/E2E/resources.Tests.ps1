BeforeAll {
    $projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' '..')
    Import-Module (Join-Path $projectRoot 'Devolutions.CIEM.Admin' 'Devolutions.CIEM.Admin.psd1') -Force

    # Helper: run a command on PSU, wrap output in JSON, and parse the result.
    function script:Run-OnPSU {
        param(
            [Parameter(Mandatory)][string]$Command,
            [int]$TimeoutSeconds = 60
        )

        $wrappedCommand = @"
`$ErrorActionPreference = 'Continue'
`$__result = & { $Command }
if (`$null -ne `$__result) { `$__result | ConvertTo-Json -Depth 5 -Compress } else { '___NULL___' }
"@
        $allOutput = @(Invoke-TestCommand -ScriptBlock ([scriptblock]::Create($wrappedCommand)) -TimeoutSeconds $TimeoutSeconds)
        $jobResult = $allOutput | Where-Object { $_.PSObject.Properties.Name -contains 'JobId' } | Select-Object -Last 1

        if (-not $jobResult) { throw "PSU command returned no job result." }
        if ($jobResult.Status -eq 'Failed') {
            $errMsgs = @($jobResult.Output) | Where-Object { $_.type -eq 4 } | ForEach-Object { $_.message }
            throw "PSU command failed: $($errMsgs -join '; ')"
        }
        if ($jobResult.Status -notin @('Completed', 'Warning')) {
            throw "PSU job $($jobResult.JobId) did not complete. Status: $($jobResult.Status)"
        }

        $pipelineItems = @($jobResult.PipelineOutput)
        if ($pipelineItems.Count -eq 0) { return $null }

        $lastItem = $pipelineItems[-1]
        $jsonDataStr = $lastItem.jsonData
        if (-not $jsonDataStr) { return $null }

        $jsonEntries = $jsonDataStr | ConvertFrom-Json
        $rawValue = ($jsonEntries | Select-Object -Last 1).value

        if ($rawValue -eq '___NULL___') { return $null }

        try { $rawValue | ConvertFrom-Json }
        catch { $rawValue }
    }

    Connect-PSU -Local | Out-Null

    # Verify PSU is reachable and discovery data exists
    $script:dataCounts = Run-OnPSU @'
        [PSCustomObject]@{
            Arm   = @(Get-CIEMAzureArmResource).Count
            Entra = @(Get-CIEMAzureEntraResource).Count
            Rels  = @(Get-CIEMAzureResourceRelationship).Count
            Types = @(Get-CIEMAzureResourceType).Count
        }
'@

    if ($script:dataCounts.Arm -eq 0 -and $script:dataCounts.Entra -eq 0) {
        throw "No discovery data in database. Run the discovery E2E test first to populate data."
    }
}

Describe 'Resource Query Commands E2E' {

    Context 'Get-CIEMAzureArmResource' {
        BeforeAll {
            # Grab a known ARM resource to use as filter values
            $script:armSample = Run-OnPSU '@(Get-CIEMAzureArmResource) | Where-Object { $_.Id -and $_.Type -and $_.Name } | Select-Object -First 1 Id, Type, Name, SubscriptionId, ResourceGroup, Location, CollectedAt'
            $script:armTotal = $script:dataCounts.Arm
        }

        It 'Returns all ARM resources when called with no parameters' {
            $script:armTotal | Should -BeGreaterThan 0
        }

        It 'Filters by -Id and returns exactly one result' {
            $id = $script:armSample.Id
            $result = Run-OnPSU "@(Get-CIEMAzureArmResource -Id '$id') | Select-Object Id, Type, Name"
            @($result).Count | Should -Be 1
            $result.Id | Should -Be $id
        }

        It 'Filters by -Type and returns a subset' {
            $type = $script:armSample.Type
            $result = Run-OnPSU @"
                `$items = @(Get-CIEMAzureArmResource -Type '$type')
                [PSCustomObject]@{ Count = `$items.Count; AllMatch = (`$items | Where-Object { `$_.Type -ne '$type' }).Count -eq 0 }
"@
            $result.Count | Should -BeGreaterThan 0
            $result.AllMatch | Should -BeTrue
        }

        It 'Filters by -Name and returns matching results' {
            $name = $script:armSample.Name
            $result = Run-OnPSU "@(Get-CIEMAzureArmResource -Name '$name') | Select-Object Id, Name"
            @($result).Count | Should -BeGreaterThan 0
            (@($result) | Select-Object -First 1).Name | Should -Be $name
        }

        It 'Returns nothing for non-existent Id' {
            $result = Run-OnPSU '@(Get-CIEMAzureArmResource -Id "nonexistent-id-99999")'
            $result | Should -BeNullOrEmpty
        }

        It 'Returns objects with all expected properties' {
            $script:armSample.Id | Should -Not -BeNullOrEmpty
            $script:armSample.Type | Should -Not -BeNullOrEmpty
            $script:armSample.Name | Should -Not -BeNullOrEmpty
            $script:armSample.CollectedAt | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Get-CIEMAzureEntraResource' {
        BeforeAll {
            $script:entraSample = Run-OnPSU '@(Get-CIEMAzureEntraResource) | Where-Object { $_.Id -and $_.Type } | Select-Object -First 1 Id, Type, DisplayName, ParentId, CollectedAt'
            $script:entraTotal = $script:dataCounts.Entra
        }

        It 'Returns all Entra resources when called with no parameters' {
            $script:entraTotal | Should -BeGreaterThan 0
        }

        It 'Filters by -Id and returns exactly one result' {
            $id = $script:entraSample.Id
            $result = Run-OnPSU "@(Get-CIEMAzureEntraResource -Id '$id') | Select-Object Id, Type"
            @($result).Count | Should -Be 1
            $result.Id | Should -Be $id
        }

        It 'Filters by -Type and returns only that type' {
            $type = $script:entraSample.Type
            $result = Run-OnPSU @"
                `$items = @(Get-CIEMAzureEntraResource -Type '$type')
                [PSCustomObject]@{ Count = `$items.Count; AllMatch = (`$items | Where-Object { `$_.Type -ne '$type' }).Count -eq 0 }
"@
            $result.Count | Should -BeGreaterThan 0
            $result.AllMatch | Should -BeTrue
        }

        It 'Returns users when filtered by -Type user' {
            $result = Run-OnPSU '@(Get-CIEMAzureEntraResource -Type "user") | Select-Object -First 1 Id, Type'
            $result | Should -Not -BeNullOrEmpty
            $result.Type | Should -Be 'user'
        }

        It 'Returns nothing for non-existent Id' {
            $result = Run-OnPSU '@(Get-CIEMAzureEntraResource -Id "nonexistent-id-99999")'
            $result | Should -BeNullOrEmpty
        }

        It 'Returns objects with all expected properties' {
            $script:entraSample.Id | Should -Not -BeNullOrEmpty
            $script:entraSample.Type | Should -Not -BeNullOrEmpty
            $script:entraSample.CollectedAt | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Get-CIEMAzureResourceRelationship' {
        BeforeAll {
            $script:relSample = Run-OnPSU '@(Get-CIEMAzureResourceRelationship) | Select-Object -First 1 Id, SourceId, SourceType, TargetId, TargetType, Relationship, CollectedAt'
            $script:relTotal = $script:dataCounts.Rels
        }

        It 'Returns all relationships when called with no parameters' {
            $script:relTotal | Should -BeGreaterThan 0
        }

        It 'Filters by -Id and returns exactly one result' {
            $id = $script:relSample.Id
            $result = Run-OnPSU "@(Get-CIEMAzureResourceRelationship -Id $id) | Select-Object Id, SourceId"
            @($result).Count | Should -Be 1
            $result.Id | Should -Be $id
        }

        It 'Filters by -Relationship and returns only that type' {
            $rel = $script:relSample.Relationship
            $result = Run-OnPSU @"
                `$items = @(Get-CIEMAzureResourceRelationship -Relationship '$rel')
                [PSCustomObject]@{ Count = `$items.Count; AllMatch = (`$items | Where-Object { `$_.Relationship -ne '$rel' }).Count -eq 0 }
"@
            $result.Count | Should -BeGreaterThan 0
            $result.AllMatch | Should -BeTrue
        }

        It 'Filters by -SourceId and returns matching results' {
            $sourceId = $script:relSample.SourceId
            $result = Run-OnPSU @"
                `$items = @(Get-CIEMAzureResourceRelationship -SourceId '$sourceId')
                [PSCustomObject]@{ Count = `$items.Count; AllMatch = (`$items | Where-Object { `$_.SourceId -ne '$sourceId' }).Count -eq 0 }
"@
            $result.Count | Should -BeGreaterThan 0
            $result.AllMatch | Should -BeTrue
        }

        It 'Filters by -TargetId and returns matching results' {
            $targetId = $script:relSample.TargetId
            $result = Run-OnPSU @"
                `$items = @(Get-CIEMAzureResourceRelationship -TargetId '$targetId')
                [PSCustomObject]@{ Count = `$items.Count; AllMatch = (`$items | Where-Object { `$_.TargetId -ne '$targetId' }).Count -eq 0 }
"@
            $result.Count | Should -BeGreaterThan 0
            $result.AllMatch | Should -BeTrue
        }

        It 'Returns nothing for non-existent SourceId' {
            $result = Run-OnPSU '@(Get-CIEMAzureResourceRelationship -SourceId "nonexistent-id-99999")'
            $result | Should -BeNullOrEmpty
        }

        It 'Returns objects with all expected properties' {
            $script:relSample.Id | Should -BeGreaterThan 0
            $script:relSample.SourceId | Should -Not -BeNullOrEmpty
            $script:relSample.SourceType | Should -Not -BeNullOrEmpty
            $script:relSample.TargetId | Should -Not -BeNullOrEmpty
            $script:relSample.TargetType | Should -Not -BeNullOrEmpty
            $script:relSample.Relationship | Should -Not -BeNullOrEmpty
            $script:relSample.CollectedAt | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Get-CIEMAzureResourceType' {
        BeforeAll {
            $script:typeSample = Run-OnPSU '@(Get-CIEMAzureResourceType) | Select-Object -First 1 Type, ApiSource, GraphTable, ResourceCount, DiscoveredAt'
            $script:typeTotal = $script:dataCounts.Types
        }

        It 'Returns all resource types when called with no parameters' {
            $script:typeTotal | Should -BeGreaterThan 0
        }

        It 'Filters by -Type and returns exactly one result' {
            $type = $script:typeSample.Type
            $result = Run-OnPSU "@(Get-CIEMAzureResourceType -Type '$type') | Select-Object Type, ApiSource"
            @($result).Count | Should -Be 1
            $result.Type | Should -Be $type
        }

        It 'Filters by -ApiSource and returns only that source' {
            $apiSource = $script:typeSample.ApiSource
            $result = Run-OnPSU @"
                `$items = @(Get-CIEMAzureResourceType -ApiSource '$apiSource')
                [PSCustomObject]@{ Count = `$items.Count; AllMatch = (`$items | Where-Object { `$_.ApiSource -ne '$apiSource' }).Count -eq 0 }
"@
            $result.Count | Should -BeGreaterThan 0
            $result.AllMatch | Should -BeTrue
        }

        It 'Returns nothing for non-existent Type' {
            $result = Run-OnPSU '@(Get-CIEMAzureResourceType -Type "nonexistent.type/nothing")'
            $result | Should -BeNullOrEmpty
        }

        It 'Returns objects with expected properties' {
            $script:typeSample.Type | Should -Not -BeNullOrEmpty
            $script:typeSample.ApiSource | Should -Not -BeNullOrEmpty
            $script:typeSample.ResourceCount | Should -BeGreaterThan 0
            $script:typeSample.DiscoveredAt | Should -Not -BeNullOrEmpty
        }
    }
}
