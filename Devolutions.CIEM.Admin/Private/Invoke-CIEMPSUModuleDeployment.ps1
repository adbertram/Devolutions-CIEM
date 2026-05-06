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

    $validationResult = Test-CIEMPSUDeployment -Environment $Environment -EnvFilePath $EnvFilePath -TimeoutSeconds $TimeoutSeconds

    [pscustomobject]@{
        Environment      = $Environment
        ModulePath       = $ModulePath
        BumpVersion      = $BumpVersion
        PublishResult    = $PublishResult
        ValidationResult = $validationResult
        Status           = 'Deployed'
    }
}
