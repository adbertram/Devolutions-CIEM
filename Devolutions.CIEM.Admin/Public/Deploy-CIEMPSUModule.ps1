function Deploy-CIEMPSUModule {
    <#
    .SYNOPSIS
        Publishes, installs, bootstraps, and validates the CIEM PSU module.

    .DESCRIPTION
        Uses Publish-PSUModule for the selected target, registers CIEM PSU
        automation scripts, initializes the CIEM database, restarts the CIEM app,
        and runs the consolidated deployment validation.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [ValidateSet('local', 'azure')]
        [string]$Environment = 'local',

        [Parameter()]
        [string]$ModulePath = $script:PsuAppRoot,

        [Parameter(Mandatory)]
        [ValidateSet('Patch', 'Minor', 'Major')]
        [string]$BumpVersion,

        [Parameter()]
        [string]$NuGetApiKey,

        [Parameter()]
        [string]$EnvFilePath,

        [Parameter()]
        [int]$TimeoutSeconds = 300
    )

    $ErrorActionPreference = 'Stop'

    $publishParams = @{
        ModulePath      = $ModulePath
        BumpVersion     = $BumpVersion
        SkipAppRestart  = $true
        ErrorAction     = 'Stop'
    }
    if ($PSBoundParameters.ContainsKey('NuGetApiKey')) {
        $publishParams.NuGetApiKey = $NuGetApiKey
    }
    if ($PSBoundParameters.ContainsKey('EnvFilePath')) {
        $publishParams.EnvFilePath = $EnvFilePath
    }
    if ($Environment -eq 'local') {
        $publishParams.LocalOnly = $true
    }

    $publishResult = Publish-PSUModule @publishParams

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

    Stop-PSUApp -Name 'Devolutions CIEM'
    Start-PSUApp -Name 'Devolutions CIEM'

    $validationResult = Test-CIEMPSUDeployment -Environment $Environment -EnvFilePath $EnvFilePath -TimeoutSeconds $TimeoutSeconds

    [pscustomobject]@{
        Environment      = $Environment
        ModulePath       = $ModulePath
        BumpVersion      = $BumpVersion
        PublishResult    = $publishResult
        BootstrapResult  = $safeBootstrapResult
        ValidationResult = $validationResult
        Status           = 'Deployed'
    }
}
