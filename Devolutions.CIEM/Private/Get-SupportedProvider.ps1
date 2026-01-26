function Get-SupportedProvider {
    <#
    .SYNOPSIS
        Gets supported cloud providers from module configuration.

    .DESCRIPTION
        Reads the module configuration and returns a list of supported cloud providers
        (azure, aws, gcp) that have configuration entries defined.

    .OUTPUTS
        [string[]] Array of lowercase provider names.

    .EXAMPLE
        $providers = Get-SupportedProvider
        # Returns: @('azure')
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    $ErrorActionPreference = 'Stop'

    $knownProviders = @('azure', 'aws', 'gcp')
    $supported = [System.Collections.Generic.List[string]]::new()

    foreach ($key in ($script:Config | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)) {
        if ($knownProviders -contains $key.ToLower()) {
            $supported.Add($key.ToLower())
        }
    }

    if ($supported.Count -eq 0) {
        throw "No supported providers found in config.json. Expected top-level keys: azure, aws, or gcp"
    }

    [string[]]$supported.ToArray()
}
