function Invoke-CIEMPSUModuleDeployment {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('local', 'azure')]
        [string]$Environment,

        [Parameter(Mandatory)]
        [string]$ModulePath,

        [Parameter(Mandatory)]
        [ValidateSet('Patch', 'Minor', 'Major')]
        [string]$BumpVersion,

        [Parameter(Mandatory)]
        [pscustomobject]$PublishResult,

        [Parameter()]
        [string]$EnvFilePath,

        [Parameter()]
        [int]$TimeoutSeconds = 300
    )

    $ErrorActionPreference = 'Stop'

    Restart-CIEMPSUApp -ModulePath $ModulePath -StepNumber 8

    $scriptRegistration = Invoke-TestCommand -Environment $Environment -EnvFilePath $EnvFilePath -TimeoutSeconds $TimeoutSeconds -ScriptBlock {
        Import-CIEMScript -Integrated | ConvertTo-Json -Depth 5 -Compress
    }
    if ($scriptRegistration.PSObject.Properties['Status'] -and $scriptRegistration.Status -notin @('Completed', 'Warning', 'WarningOutput')) {
        throw "CIEM PSU script registration failed with status $($scriptRegistration.Status)."
    }

    $validationResult = Test-CIEMPSUDeployment -Environment $Environment -EnvFilePath $EnvFilePath -TimeoutSeconds $TimeoutSeconds

    [pscustomobject]@{
        Environment      = $Environment
        ModulePath       = $ModulePath
        BumpVersion      = $BumpVersion
        PublishResult    = $PublishResult
        ScriptRegistration = $scriptRegistration
        ValidationResult = $validationResult
        Status           = 'Deployed'
    }
}
