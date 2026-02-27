function Register-CIEMArgumentCompleters {
    <#
    .SYNOPSIS
        Registers dynamic tab-completion for provider-related parameters.

    .DESCRIPTION
        Adds argument completers for -Provider and -Name parameters across
        CIEM functions. Provider names are resolved dynamically from the
        CIEM SQLite database at tab-completion time, with a fallback to
        registered provider type names.
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
            # Fallback to registered provider type names
            $providers = @($script:ProviderTypes.Keys | ForEach-Object {
                [PSCustomObject]@{ Name = $_ }
            })
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
        'Connect-CIEM'
        'Invoke-CIEMScan'
        'Get-CIEMCheck'
        'Get-CIEMProviderService'
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
