function Invoke-TestCommand {
    <#
    .SYNOPSIS
        Runs a PowerShell command on a PSU instance.

    .DESCRIPTION
        Unified test harness for running commands against the Devolutions CIEM module
        in two PSU contexts:

        - local:  Run on the local PSU instance via Invoke-CIEMCommand
        - azure:  Run on the Azure PSU instance via Invoke-CIEMCommand

        Handles Connect-PSU and formats the output.

    .PARAMETER ScriptBlock
        The PowerShell code to execute.

    .PARAMETER Environment
        Which PSU instance to run against: local or azure. Defaults to local.

    .PARAMETER TimeoutSeconds
        Maximum wait time for PSU commands. Defaults to 120.

    .EXAMPLE
        Invoke-TestCommand -ScriptBlock { Get-Module Devolutions.CIEM | Select-Object Version }

    .EXAMPLE
        Invoke-TestCommand -ScriptBlock { Invoke-CIEMScan -Service Entra -Verbose } -Environment azure
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [Parameter()]
        [ValidateSet('local', 'azure')]
        [string]$Environment = 'local',

        [Parameter()]
        [int]$TimeoutSeconds = 30
    )

    $ErrorActionPreference = 'Stop'

    $connectCommands = @{
        local = { Connect-PSU -Local }
        azure = { Connect-PSU }
    }

    Write-Verbose "[$Environment] Connecting to PSU..."
    & $connectCommands[$Environment] | Out-Null

    Write-Verbose "[$Environment] Executing on PSU..."
    Invoke-CIEMCommand -ScriptBlock $ScriptBlock -TimeoutSeconds $TimeoutSeconds
}
