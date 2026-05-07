function InvokeCIEMParallelForEach {
    <#
    .SYNOPSIS
        Private helper that runs a scriptblock against a set of work items in parallel
        runspaces while preserving Devolutions.CIEM module state.

    .DESCRIPTION
        Wraps ForEach-Object -Parallel. Each runspace hydrates the Devolutions.CIEM
        module exactly once (guarded by Get-Module + a $script:CIEMRunspaceInitialized
        flag) and copies the caller's auth context into script scope before invoking
        the user-supplied scriptblock.

        Returns one record per input item with Success/Result/Error fields so the
        caller can project failures without cross-runspace exception flow.

        NOTE: Import-Module is called WITHOUT -Force. Using -Force would rebind any
        module-defined classes (e.g., [CIEMAzureAuthContext]) and break ::new() calls
        inside the runspace, and would also re-import on every item instead of once
        per runspace.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param(
        [Parameter(ValueFromPipeline)]
        [object[]]$InputObject,

        [Parameter()]
        [int]$ThrottleLimit = $script:CIEMParallelThrottleLimitDiscovery,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    begin {
        $ErrorActionPreference = 'Stop'
        $items = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($item in $InputObject) {
            $items.Add($item)
        }
    }

    end {
        if ($items.Count -eq 0) {
            return @()
        }

        $module = Get-Module Devolutions.CIEM
        if (-not $module) {
            throw 'InvokeCIEMParallelForEach requires the Devolutions.CIEM module to be loaded.'
        }

        $modulePath = $module.Path
        $authSnapshot = $script:AuthContext
        $azureAuthSnapshot = $script:AzureAuthContext
        $scriptBlockText = $ScriptBlock.ToString()

        $items | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
            $ErrorActionPreference = 'Stop'

            # Init-once-per-runspace: runspaces are reused across items assigned to the
            # same throttle slot. Only import/hydrate on first use in this runspace.
            if (-not $script:CIEMRunspaceInitialized) {
                if (-not (Get-Module Devolutions.CIEM)) {
                    Import-Module $using:modulePath
                }

                $moduleInstance = Get-Module Devolutions.CIEM
                & $moduleInstance {
                    param($authSnapshot, $azureAuthSnapshot)

                    $script:AuthContext = @{}
                    if ($authSnapshot) {
                        foreach ($key in $authSnapshot.Keys) {
                            $script:AuthContext[$key] = $authSnapshot[$key]
                        }
                    }

                    if ($azureAuthSnapshot) {
                        $ctx = [CIEMAzureAuthContext]::new()
                        foreach ($property in 'ProfileId', 'ProfileName', 'ProviderId', 'Method', 'TenantId', 'ClientId', 'ManagedIdentityClientId', 'AccountId', 'AccountType', 'ARMToken', 'GraphToken', 'KeyVaultToken', 'LastError') {
                            if ($azureAuthSnapshot.PSObject.Properties.Name -contains $property) {
                                $ctx.$property = $azureAuthSnapshot.$property
                            }
                        }
                        if ($azureAuthSnapshot.PSObject.Properties.Name -contains 'SubscriptionIds') {
                            $ctx.SubscriptionIds = @($azureAuthSnapshot.SubscriptionIds)
                        }
                        if ($azureAuthSnapshot.PSObject.Properties.Name -contains 'TokenExpiresAt' -and $azureAuthSnapshot.TokenExpiresAt) {
                            $ctx.TokenExpiresAt = $azureAuthSnapshot.TokenExpiresAt
                        }
                        if ($azureAuthSnapshot.PSObject.Properties.Name -contains 'ConnectedAt' -and $azureAuthSnapshot.ConnectedAt) {
                            $ctx.ConnectedAt = $azureAuthSnapshot.ConnectedAt
                        }
                        $ctx.IsConnected = $true
                        $script:AzureAuthContext = $ctx
                        $script:AuthContext['Azure'] = $ctx
                    }
                    else {
                        $script:AzureAuthContext = $null
                    }
                } $using:authSnapshot $using:azureAuthSnapshot

                $script:CIEMRunspaceInitialized = $true
            }

            # Create scriptblock inside the module scope so module-defined classes
            # ([CIEMCheck], [CIEMServiceCache], etc.) are visible at parse time.
            $moduleInstance = Get-Module Devolutions.CIEM
            $childBlock = & $moduleInstance { [scriptblock]::Create($args[0]) } $using:scriptBlockText
            # Capture the pipeline item before try/catch — inside catch, $_ is the ErrorRecord.
            $currentItem = $_
            try {
                $result = @(& $moduleInstance $childBlock $currentItem)
                [pscustomobject]@{
                    Input   = $currentItem
                    Success = $true
                    Result  = $result
                    Error   = $null
                }
            }
            catch {
                [pscustomobject]@{
                    Input   = $currentItem
                    Success = $false
                    Result  = @()
                    Error   = $_.Exception.Message
                }
            }
        }
    }
}
