function Invoke-CIEMIdentityScan {
    <#
    .SYNOPSIS
        Collects and persists identity data for the specified providers (internal).

    .DESCRIPTION
        Connects to each provider, calls the per-service collector functions
        (Get-CIEMAzureEntraData, Get-CIEMAzureIAMData), and persists the data
        to SQLite via the per-service save functions.

        This is an internal function called by New-CIEMIdentityScanRun. It does not
        manage the ScanRun lifecycle — the caller is responsible for that.

    .PARAMETER Provider
        One or more cloud providers to collect identity data for. Required.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Provider
    )

    $ErrorActionPreference = 'Stop'

    $progressActivity = "Identity Data Collection ($($Provider -join ', '))"

    Write-CIEMLog -Message "Invoke-CIEMIdentityScan called: Provider=[$($Provider -join ',')]" -Severity INFO -Component 'IdentityScan'

    $providerCount = $Provider.Count
    $providerIdx = 0

    foreach ($providerName in $Provider) {
        $providerIdx++
        Write-CIEMLog -Message "Collecting identity data for $providerName" -Severity INFO -Component 'IdentityScan'

        Write-Progress -Activity $progressActivity -Status "Connecting to $providerName..." -PercentComplete ([math]::Floor(($providerIdx - 1) / $providerCount * 80))
        Connect-CIEM -Provider $providerName -Force

        switch ($providerName) {
            'Azure' {
                # Step 1: Collect Entra data (~40% of provider work)
                Write-Progress -Activity $progressActivity -Status "Collecting Entra ID data from $providerName..." -CurrentOperation 'Users, Groups, Service Principals, Directory Roles' -PercentComplete ([math]::Floor(($providerIdx - 1) / $providerCount * 80 + 5))
                $sw = [Diagnostics.Stopwatch]::StartNew()
                $entraData = Get-CIEMAzureEntraData
                Write-CIEMLog -Message "[$providerName] Entra data collected in $([math]::Round($sw.Elapsed.TotalSeconds, 2))s" -Severity INFO -Component 'IdentityScan'

                # Step 2: Collect IAM data (~40% of provider work)
                Write-Progress -Activity $progressActivity -Status "Collecting IAM data from $providerName..." -CurrentOperation 'Role Definitions, Role Assignments' -PercentComplete ([math]::Floor(($providerIdx - 1) / $providerCount * 80 + 35))
                $sw.Restart()
                $iamData = Get-CIEMAzureIAMData
                Write-CIEMLog -Message "[$providerName] IAM data collected in $([math]::Round($sw.Elapsed.TotalSeconds, 2))s" -Severity INFO -Component 'IdentityScan'

                # Step 3: Persist data (~20% of provider work)
                Write-Progress -Activity $progressActivity -Status "Saving identity data for $providerName..." -CurrentOperation 'Writing to database' -PercentComplete ([math]::Floor(($providerIdx - 1) / $providerCount * 80 + 65))
                $providerId = $providerName.ToLower()
                Save-CIEMAzureEntraData -ProviderId $providerId -Data $entraData
                Save-CIEMAzureIAMData -ProviderId $providerId -Data $iamData
                Write-CIEMLog -Message "[$providerName] Identity data persisted to SQLite" -Severity INFO -Component 'IdentityScan'
            }
            # Future: 'AWS' { ... }
            default {
                Write-Warning "Invoke-CIEMIdentityScan: No identity collection implemented for provider '$providerName'"
            }
        }
    }

    Write-Progress -Activity $progressActivity -Completed
}
