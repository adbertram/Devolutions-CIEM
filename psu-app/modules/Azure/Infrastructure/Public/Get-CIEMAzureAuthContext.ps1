function Get-CIEMAzureAuthContext {
    <#
    .SYNOPSIS
        Returns the current Azure authentication context.

    .DESCRIPTION
        Public accessor for the module-scoped AzureAuthContext set by Connect-CIEMAzure.
        Returns the rich CIEMAzureAuthContext object with profile info, tokens,
        subscription IDs, and connection state.

    .OUTPUTS
        CIEMAzureAuthContext

    .EXAMPLE
        $ctx = Get-CIEMAzureAuthContext
        $ctx.IsConnected
        $ctx.SubscriptionIds
    #>
    [CmdletBinding()]
    [OutputType('CIEMAzureAuthContext')]
    param()

    $script:AzureAuthContext
}
