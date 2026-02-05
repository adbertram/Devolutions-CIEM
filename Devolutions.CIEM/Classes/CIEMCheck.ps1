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

enum CIEMCheckService {
    Entra
    IAM
    KeyVault
    Storage
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
    [CIEMCheckService]$Service
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

    static [CIEMCheck] FromJsonObject([PSCustomObject]$JsonObj, [CIEMCloudProvider]$Provider) {
        $check = [CIEMCheck]::new()
        $check.Id = $JsonObj.id
        $check.CloudProvider = $Provider
        $check.Service = [CIEMCheckService]$JsonObj.service
        $check.Title = $JsonObj.title
        $check.Description = $JsonObj.description
        $check.Risk = $JsonObj.risk
        $check.Severity = [CIEMCheckSeverity]$JsonObj.severity
        $check.RelatedUrl = $JsonObj.relatedUrl
        $check.CheckScript = $JsonObj.checkScript
        $check.DependsOn = @($JsonObj.dependsOn | Where-Object { $_ })

        # Parse categories
        $check.Categories = @($JsonObj.categories | Where-Object { $_ } | ForEach-Object {
            [CIEMCheckCategory]$_
        })

        # Parse remediation
        $rem = [CIEMCheckRemediation]::new()
        if ($JsonObj.remediation) {
            $rem.Text = $JsonObj.remediation.text
            $rem.Url = $JsonObj.remediation.url
        }
        $check.Remediation = $rem

        # Parse permissions
        $perms = [CIEMCheckPermissions]::new()
        if ($JsonObj.permissions) {
            if ($JsonObj.permissions.PSObject.Properties['graph'] -and $JsonObj.permissions.graph) {
                $perms.Graph = @($JsonObj.permissions.graph)
            }
            if ($JsonObj.permissions.PSObject.Properties['arm'] -and $JsonObj.permissions.arm) {
                $perms.ARM = @($JsonObj.permissions.arm)
            }
            if ($JsonObj.permissions.PSObject.Properties['keyvaultDataPlane'] -and $JsonObj.permissions.keyvaultDataPlane) {
                $perms.KeyVaultDataPlane = @($JsonObj.permissions.keyvaultDataPlane)
            }
        }
        $check.Permissions = $perms

        return $check
    }
}
