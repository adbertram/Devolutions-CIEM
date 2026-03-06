class CIEMProvider {
    [string]$Name                              # 'Azure', 'AWS', 'GCP', etc.
    [bool]$Enabled
    [bool]$IsDefault
    [PSCustomObject]$Endpoints                  # Provider-specific API endpoints
    [string[]]$ResourceFilter                   # Subscription IDs / Account IDs

    CIEMProvider() {}

    CIEMProvider([string]$Name) {
        $this.Name = $Name
        $this.Enabled = $false
        $this.IsDefault = $false
        $this.Endpoints = [PSCustomObject]@{}
        $this.ResourceFilter = @()
    }
}
