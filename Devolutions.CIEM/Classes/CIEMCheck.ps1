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
    [string[]]$Graph              # Azure: Microsoft Graph API
    [string[]]$ARM                # Azure: Azure Resource Manager
    [string[]]$KeyVaultDataPlane  # Azure: Key Vault data plane
    [string[]]$IAM                # AWS: IAM actions

    CIEMCheckPermissions() {
        $this.Graph = @()
        $this.ARM = @()
        $this.KeyVaultDataPlane = @()
        $this.IAM = @()
    }

    [hashtable] ToHashtable() {
        $ht = @{}
        if ($this.Graph.Count -gt 0) { $ht.Graph = $this.Graph }
        if ($this.ARM.Count -gt 0) { $ht.ARM = $this.ARM }
        if ($this.KeyVaultDataPlane.Count -gt 0) { $ht.KeyVaultDataPlane = $this.KeyVaultDataPlane }
        if ($this.IAM.Count -gt 0) { $ht.IAM = $this.IAM }
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
