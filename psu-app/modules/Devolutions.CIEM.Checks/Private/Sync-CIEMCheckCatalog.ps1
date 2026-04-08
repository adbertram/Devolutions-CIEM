function Sync-CIEMCheckCatalog {
    <#
    .SYNOPSIS
        Upserts provider check metadata from the checked-in catalog.

    .DESCRIPTION
        Validates the checked-in catalog for the requested provider, ensures every
        local check script is represented, and upserts catalog metadata into the
        SQLite checks table. Existing user enable/disable state is preserved.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Azure', 'AWS')]
        [string]$Provider
    )

    $checksRoot = switch ($Provider) {
        'Azure' { Join-Path $script:ModuleRoot 'modules/Azure/Checks' }
        'AWS' { Join-Path $script:ModuleRoot 'modules/AWS/Checks' }
        default { throw "Unsupported provider '$Provider'." }
    }

    $catalogPath = Join-Path $checksRoot 'check_catalog.json'
    if (-not (Test-Path $catalogPath)) {
        Write-Verbose "No check catalog found for provider '$Provider' at '$catalogPath'."
        return
    }

    $catalog = @(
        Get-Content -Path $catalogPath -Raw |
            ConvertFrom-Json -AsHashtable -ErrorAction Stop
    )
    if ($catalog.Count -eq 0) {
        throw "Check catalog '$catalogPath' is empty."
    }

    $catalogById = @{}
    $catalogByScript = @{}
    foreach ($entry in $catalog) {
        if ($entry.Provider -ne $Provider) {
            throw "Catalog entry '$($entry.Id)' declares provider '$($entry.Provider)' but is stored under '$Provider'."
        }

        if (-not $entry.Id) {
            throw "Catalog entry in '$catalogPath' is missing Id."
        }
        if (-not $entry.CheckScript) {
            throw "Catalog entry '$($entry.Id)' is missing CheckScript."
        }
        if ($catalogById.ContainsKey($entry.Id)) {
            throw "Duplicate check id '$($entry.Id)' in '$catalogPath'."
        }
        if ($catalogByScript.ContainsKey($entry.CheckScript)) {
            throw "Duplicate check script '$($entry.CheckScript)' in '$catalogPath'."
        }

        $catalogById[$entry.Id] = $entry
        $catalogByScript[$entry.CheckScript] = $entry
    }

    $scriptFiles = @(Get-ChildItem -Path $checksRoot -Filter '*.ps1' | Select-Object -ExpandProperty Name)
    $missingCatalogScripts = @($scriptFiles | Where-Object { -not $catalogByScript.ContainsKey($_) })
    if ($missingCatalogScripts.Count -gt 0) {
        throw "Check catalog '$catalogPath' is missing script entries: $($missingCatalogScripts -join ', ')"
    }

    $missingLocalScripts = @($catalogByScript.Keys | Where-Object { -not ($scriptFiles -contains $_) })
    if ($missingLocalScripts.Count -gt 0) {
        throw "Check catalog '$catalogPath' references missing scripts: $($missingLocalScripts -join ', ')"
    }

    $existingRows = @(Get-CIEMCheckMetadata -Provider $Provider)
    $existingById = @{}
    $existingByScript = @{}
    foreach ($row in $existingRows) {
        if ($existingById.ContainsKey($row.id)) {
            throw "Existing metadata contains duplicate id '$($row.id)'."
        }
        if ($existingByScript.ContainsKey($row.check_script)) {
            throw "Existing metadata contains duplicate script '$($row.check_script)'."
        }

        $existingById[$row.id] = $row
        $existingByScript[$row.check_script] = $row
    }

    foreach ($entry in $catalog) {
        $dataNeeds = if ($entry.ContainsKey('DataNeeds') -and $null -ne $entry.DataNeeds) {
            @($entry.DataNeeds)
        }
        else {
            $null
        }

        $catalogDisabled = [System.Convert]::ToBoolean($entry.Disabled)

        if (-not $catalogDisabled) {
            if ($null -eq $dataNeeds -or $dataNeeds.Count -eq 0) {
                throw "Enabled catalog entry '$($entry.Id)' must declare at least one data need."
            }

            foreach ($needKey in $dataNeeds) {
                if ($needKey -cne $needKey.ToLowerInvariant()) {
                    throw "Catalog entry '$($entry.Id)' declares non-canonical data need '$needKey'."
                }
            }
        }

        if ($existingById.ContainsKey($entry.Id)) {
            $existing = $existingById[$entry.Id]
            if ($existing.check_script -ne $entry.CheckScript) {
                throw "Existing metadata id '$($entry.Id)' points to '$($existing.check_script)', but catalog expects '$($entry.CheckScript)'."
            }
        }

        if ($existingByScript.ContainsKey($entry.CheckScript)) {
            $existing = $existingByScript[$entry.CheckScript]
            if ($existing.id -ne $entry.Id) {
                throw "Existing metadata script '$($entry.CheckScript)' uses id '$($existing.id)', but catalog expects '$($entry.Id)'."
            }
        }

        $disabled = if ($existingById.ContainsKey($entry.Id)) {
            [bool]$existingById[$entry.Id].disabled
        }
        else {
            $catalogDisabled
        }

        $dependsOn = if ($entry.ContainsKey('DependsOn') -and $null -ne $entry.DependsOn -and @($entry.DependsOn).Count -gt 0) {
            @($entry.DependsOn)
        }
        else {
            $null
        }

        $permissions = if ($entry.ContainsKey('Permissions') -and $null -ne $entry.Permissions) {
            $entry.Permissions | ConvertTo-Json -Compress -Depth 10
        }
        else {
            $null
        }

        Save-CIEMCheck -Id $entry.Id `
            -Provider $entry.Provider `
            -Service $entry.Service `
            -Title $entry.Title `
            -Description $entry.Description `
            -Risk $entry.Risk `
            -Severity $entry.Severity `
            -RemediationText $entry.Remediation.Text `
            -RemediationUrl $entry.Remediation.Url `
            -RelatedUrl $entry.RelatedUrl `
            -CheckScript $entry.CheckScript `
            -Disabled:$disabled `
            -Permissions $permissions `
            -DependsOn $dependsOn `
            -DataNeeds $dataNeeds
    }
}
