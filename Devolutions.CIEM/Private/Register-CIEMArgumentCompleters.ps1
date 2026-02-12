function Register-CIEMArgumentCompleters {
    <#
    .SYNOPSIS
        Registers dynamic tab-completion for provider-related parameters.

    .DESCRIPTION
        Adds argument completers for -Provider and -Name parameters across
        CIEM functions. Provider names are resolved dynamically from the
        CIEM:Providers cache at tab-completion time.
    #>
    [CmdletBinding()]
    param()

    # Completer scriptblock that returns provider names
    $providerCompleter = {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

        try {
            $providers = @(Get-CIEMProvider)
        }
        catch {
            $providers = @(
                [PSCustomObject]@{ Name = 'Azure' }
                [PSCustomObject]@{ Name = 'AWS' }
            )
        }

        $providers | Where-Object { $_.Name -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new(
                $_.Name,
                $_.Name,
                'ParameterValue',
                $_.Name
            )
        }
    }

    # Register for -Provider parameter on relevant functions
    $providerParamFunctions = @(
        'Compare-ProwlerCheck'
        'Connect-CIEM'
        'Invoke-CIEMScan'
        'Get-CIEMCheck'
        'Get-CIEMCheckService'
        'Test-CIEMAuthenticationContext'
        'Get-CIEMAuthenticationContext'
        'Save-CIEMAuthenticationContext'
    )

    foreach ($funcName in $providerParamFunctions) {
        Register-ArgumentCompleter -CommandName $funcName -ParameterName 'Provider' -ScriptBlock $providerCompleter
    }

    # Register for -Name parameter on provider CRUD functions
    $nameParamFunctions = @(
        'Get-CIEMProvider'
        'Update-CIEMProvider'
        'Remove-CIEMProvider'
    )

    foreach ($funcName in $nameParamFunctions) {
        Register-ArgumentCompleter -CommandName $funcName -ParameterName 'Name' -ScriptBlock $providerCompleter
    }
}
