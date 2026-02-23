class CIEMProvider {
    [string]$Name                              # 'Azure', 'AWS', 'GCP', etc.
    [bool]$Enabled
    [bool]$IsDefault
    # Untyped to avoid PSU runspace class isolation issues.
    # Expected shape: { Provider, Enabled, Method, TenantId?, ClientId?, ManagedIdentityClientId? }
    [PSCustomObject]$Authentication
    [PSCustomObject]$Endpoints                  # Provider-specific API endpoints
    [string[]]$ResourceFilter                   # Subscription IDs / Account IDs

    CIEMProvider() {}

    CIEMProvider([string]$Name) {
        $this.Name = $Name
        $this.Enabled = $false
        $this.IsDefault = $false
        $this.Authentication = [CIEMAuthenticationContext]::new()
        $this.Endpoints = [PSCustomObject]@{}
        $this.ResourceFilter = @()
    }

    # Serialize for PSU cache (class instances -> PSCustomObjects)
    [PSCustomObject] ToPSCustomObject() {
        $authObj = [PSCustomObject]@{
            Provider = $this.Authentication.Provider
            Enabled  = $this.Authentication.Enabled
            Method   = $this.Authentication.Method
        }

        # Include subclass-specific properties
        foreach ($prop in $this.Authentication.PSObject.Properties) {
            if ($prop.Name -notin @('Provider', 'Enabled', 'Method')) {
                $authObj | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
            }
        }

        return [PSCustomObject]@{
            Name           = $this.Name
            Enabled        = $this.Enabled
            IsDefault      = $this.IsDefault
            Authentication = $authObj
            Endpoints      = $this.Endpoints
            ResourceFilter = $this.ResourceFilter
        }
    }
}
