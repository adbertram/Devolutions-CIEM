function GetCIEMExposureChangeMigrationTitle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Change
    )

    $ErrorActionPreference = 'Stop'

    switch ([string]$Change.exposure_type) {
        'IdentityRisk' {
            if ([string]::IsNullOrWhiteSpace([string]$Change.impacted_identity_name)) {
                throw "Cannot backfill exposure-change title for '$($Change.id)' because impacted_identity_name is empty."
            }

            return [string]$Change.impacted_identity_name
        }
        'AttackPath' {
            $stateJson = if ([string]$Change.change_type -eq 'RemovedRisk') {
                [string]$Change.previous_state_json
            }
            else {
                [string]$Change.current_state_json
            }

            if ([string]::IsNullOrWhiteSpace($stateJson)) {
                throw "Cannot backfill attack-path exposure-change title for '$($Change.id)' because state JSON is empty."
            }

            $state = $stateJson | ConvertFrom-Json
            if ($null -eq $state.PSObject.Properties['PatternName'] -or [string]::IsNullOrWhiteSpace([string]$state.PatternName)) {
                throw "Cannot backfill attack-path exposure-change title for '$($Change.id)' because state JSON has no PatternName."
            }

            return [string]$state.PatternName
        }
        default {
            throw "Cannot backfill exposure-change title for '$($Change.id)' with unsupported exposure type '$($Change.exposure_type)'."
        }
    }
}

function UpdateCIEMExposureChangeStorageSchema {
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    $columns = @{}
    foreach ($column in @(Invoke-CIEMQuery -Query "PRAGMA table_info('ciem_exposure_changes')")) {
        $columns[[string]$column.name] = [string]$column.type
    }
    if ($columns.Count -eq 0) {
        throw "Cannot migrate exposure-change storage because table 'ciem_exposure_changes' does not exist."
    }

    if (-not $columns.ContainsKey('title')) {
        Invoke-CIEMQuery -Query "ALTER TABLE ciem_exposure_changes ADD COLUMN title TEXT NOT NULL DEFAULT ''" -AsNonQuery | Out-Null
    }

    $rowsNeedingTitle = @(Invoke-CIEMQuery -Query @"
SELECT id, change_type, exposure_type, impacted_identity_name, previous_state_json, current_state_json
FROM ciem_exposure_changes
WHERE title IS NULL OR TRIM(title) = ''
"@)

    foreach ($row in $rowsNeedingTitle) {
        $title = GetCIEMExposureChangeMigrationTitle -Change $row
        Invoke-CIEMQuery -Query 'UPDATE ciem_exposure_changes SET title = @title WHERE id = @id' -Parameters @{
            id    = [string]$row.id
            title = $title
        } -AsNonQuery | Out-Null
    }
}
