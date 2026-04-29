enum CIEMCheckSeverity {
    low
    medium
    high
    critical
}

class CIEMCheckRemediation {
    [string]$Text
    [string]$Url

    CIEMCheckRemediation() {}

    CIEMCheckRemediation([string]$Text, [string]$Url) {
        $this.Text = $Text
        $this.Url = $Url
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
}

class CIEMCheck {
    [string]$Id
    [string]$Provider
    [string]$Service
    [string]$Title
    [string]$Description
    [string]$Risk
    [CIEMCheckSeverity]$Severity
    [CIEMCheckRemediation]$Remediation
    [string]$RelatedUrl
    [string]$CheckScript
    [string]$ExecutionMode
    [string]$ManualReason
    [string]$Evaluator
    [string]$EvaluatorConfig
    [string[]]$DependsOn
    [string[]]$DataNeeds
    [CIEMCheckPermissions]$Permissions
    [bool]$Disabled

    CIEMCheck() {}
}
