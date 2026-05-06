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

    $bootstrapScript = {
        Import-Module Devolutions.CIEM -ErrorAction Stop
        Initialize-CIEMPSUInstance -Integrated | Out-Null
    }

    $bootstrapResult = Invoke-TestCommand -Environment $Environment -EnvFilePath $EnvFilePath -TimeoutSeconds $TimeoutSeconds -ScriptBlock $bootstrapScript
    if (-not $bootstrapResult.PSObject.Properties['Status']) {
        throw 'CIEM PSU bootstrap returned no Status.'
    }
    $bootstrapOutput = ConvertTo-CIEMPSUCommandOutputText -Output $bootstrapResult.Output
    if ($bootstrapResult.Status -ne 'Completed') {
        throw "CIEM PSU bootstrap failed with status $($bootstrapResult.Status). Output: $($bootstrapOutput -join "`n")"
    }
    $safeBootstrapResult = [pscustomobject]@{
        JobId     = $bootstrapResult.JobId
        ScriptId  = $bootstrapResult.ScriptId
        Status    = $bootstrapResult.Status
        Output    = $bootstrapOutput
        StartTime = $bootstrapResult.StartTime
        EndTime   = $bootstrapResult.EndTime
    }

    Restart-CIEMPSUApp -ModulePath $ModulePath -StepNumber 8

    $validationResult = Test-CIEMPSUDeployment -Environment $Environment -EnvFilePath $EnvFilePath -TimeoutSeconds $TimeoutSeconds

    [pscustomobject]@{
        Environment      = $Environment
        ModulePath       = $ModulePath
        BumpVersion      = $BumpVersion
        PublishResult    = $PublishResult
        BootstrapResult  = $safeBootstrapResult
        ValidationResult = $validationResult
        Status           = 'Deployed'
    }
}
