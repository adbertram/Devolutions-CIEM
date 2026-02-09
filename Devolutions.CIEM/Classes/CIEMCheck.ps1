enum CIEMCloudProvider {
    Azure
    AWS
}

enum CIEMCheckSeverity {
    low
    medium
    high
    critical
}

enum CIEMCheckCategory {
    encryption
    identity
    network
    logging
    compliance
}

class CIEMCheckRemediation {
    [string]$Text
    [string]$Url

    CIEMCheckRemediation() {}

    CIEMCheckRemediation([string]$Text, [string]$Url) {
        $this.Text = $Text
        $this.Url = $Url
    }

    [hashtable] ToHashtable() {
        return @{
            Text = $this.Text
            Url  = $this.Url
        }
    }
}

class CIEMCheckPermissions {
    [string[]]$Graph
    [string[]]$ARM
    [string[]]$KeyVaultDataPlane

    CIEMCheckPermissions() {
        $this.Graph = @()
        $this.ARM = @()
        $this.KeyVaultDataPlane = @()
    }

    [hashtable] ToHashtable() {
        $ht = @{}
        if ($this.Graph.Count -gt 0) { $ht.Graph = $this.Graph }
        if ($this.ARM.Count -gt 0) { $ht.ARM = $this.ARM }
        if ($this.KeyVaultDataPlane.Count -gt 0) { $ht.KeyVaultDataPlane = $this.KeyVaultDataPlane }
        return $ht
    }
}

class CIEMCheck {
    [string]$Id
    [CIEMCloudProvider]$CloudProvider
    [string]$Service
    [string]$Title
    [string]$Description
    [string]$Risk
    [CIEMCheckSeverity]$Severity
    [CIEMCheckCategory[]]$Categories
    [CIEMCheckRemediation]$Remediation
    [string]$RelatedUrl
    [string]$CheckScript
    [string[]]$DependsOn
    [CIEMCheckPermissions]$Permissions

    CIEMCheck() {}
}
