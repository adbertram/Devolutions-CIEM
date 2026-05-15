function Deploy-PSUModule {
    <#
    .SYNOPSIS
        Deploys a published Devolutions.CIEM PowerShell Gallery version into a PSU instance.

    .DESCRIPTION
        Connects to the target PSU instance (local adam-server or Azure), installs the
        Devolutions.CIEM module from PowerShell Gallery, restarts the CIEM app, and
        optionally validates the resulting deployment state.

        This cmdlet assumes the version is already published to PSGallery. Use
        Publish-PSUModule first if it is not.

    .PARAMETER Environment
        Target PSU environment: 'local' (adam-server) or 'azure' (production).

    .PARAMETER ModulePath
        Path to the local module source directory. Used to derive the CIEM app
        name for restart and validation. Defaults to ./psu-app relative to the
        current location.

    .PARAMETER Version
        Specific Gallery version to install. If not specified, the version is
        read from the module manifest at ModulePath.

    .PARAMETER EnvFilePath
        Path to .env file for PSU connection credentials.

    .PARAMETER SkipAppRestart
        Skip the CIEM app restart and health check after install.

    .PARAMETER ValidateDeployment
        Run CIEM deployment validation after install. Validation owns its own
        restart/health flow, so Restart-CIEMPSUApp is skipped when this is set.

    .PARAMETER TimeoutSeconds
        Timeout for CIEM deployment validation when ValidateDeployment is specified.

    .EXAMPLE
        Deploy-PSUModule -Environment local

    .EXAMPLE
        Deploy-PSUModule -Environment azure -Version 5.1.6

    .EXAMPLE
        Deploy-PSUModule -Environment local -ValidateDeployment
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'CLI tooling requires colored user feedback for step progress and status messages')]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('local', 'azure')]
        [string]$Environment,

        [Parameter()]
        [string]$ModulePath = './psu-app',

        [Parameter()]
        [string]$Version,

        [Parameter()]
        [string]$EnvFilePath,

        [Parameter()]
        [switch]$SkipAppRestart,

        [Parameter()]
        [switch]$ValidateDeployment,

        [Parameter()]
        [int]$TimeoutSeconds = 300
    )

    $ErrorActionPreference = 'Stop'

    $moduleName = 'Devolutions.CIEM'
    $galleryUrl = "https://www.powershellgallery.com/packages/$moduleName"
    $versionToInstall = $Version
    if (-not $versionToInstall) {
        $resolvedModulePath = Resolve-Path -Path $ModulePath -ErrorAction Stop | Select-Object -ExpandProperty Path
        $manifestFile = Get-ChildItem -Path $resolvedModulePath -Filter "$moduleName.psd1" -File | Select-Object -First 1
        if (-not $manifestFile) {
            throw "No $moduleName.psd1 manifest found in: $resolvedModulePath"
        }

        $manifest = Import-PowerShellDataFile -Path $manifestFile.FullName
        $versionToInstall = [string]$manifest.ModuleVersion
    }

    $shouldProcessTarget = "$moduleName v$versionToInstall"
    $shouldProcessAction = "Install into $Environment PSU"

    if (-not $PSCmdlet.ShouldProcess($shouldProcessTarget, $shouldProcessAction)) {
        Write-Host ''
        Write-Host '[DRY RUN] Would deploy:' -ForegroundColor Yellow
        Write-Host "  Module:      $moduleName"
        Write-Host "  Version:     $versionToInstall"
        Write-Host "  Environment: $Environment"

        return [PSCustomObject]@{
            ModuleName  = $moduleName
            Version     = $versionToInstall
            Environment = $Environment
            GalleryUrl  = $galleryUrl
            UpdatedPSU  = $false
            Status      = 'DryRun'
        }
    }

    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host "Deploying $moduleName to $Environment PSU" -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ''

    Write-Host 'Step 1: Connecting to PSU...' -ForegroundColor Yellow
    $connectParams = @{ ErrorAction = 'Stop' }
    if ($EnvFilePath) { $connectParams.EnvFilePath = $EnvFilePath }
    if ($Environment -eq 'local') {
        $connectParams.Local = $true
    }
    else {
        $connectParams.Azure = $true
    }
    $null = Connect-PSU @connectParams
    Write-Host "  [OK] Connected to $Environment PSU" -ForegroundColor Green

    Write-Host ''
    Write-Host "Step 2: Removing existing $moduleName module versions..." -ForegroundColor Yellow
    $removeParams = @{
        Name        = $moduleName
        Environment = $Environment
        Force       = $true
        ErrorAction = 'Stop'
    }
    if ($EnvFilePath) { $removeParams.EnvFilePath = $EnvFilePath }
    Remove-PSUModule @removeParams | Out-Null
    Write-Host "  [OK] Removed existing $moduleName module versions" -ForegroundColor Green

    Write-Host ''
    Write-Host "Step 3: Installing $moduleName from PowerShell Gallery..." -ForegroundColor Yellow
    $installParams = @{
        Name    = $moduleName
        Version = $versionToInstall
    }
    $installResult = Install-PSUModule @installParams
    $resolvedVersion = $installResult.Version
    Write-Host "  [OK] Installed $moduleName $resolvedVersion" -ForegroundColor Green

    $deployResult = [PSCustomObject]@{
        ModuleName  = $moduleName
        Version     = $resolvedVersion
        Environment = $Environment
        GalleryUrl  = $galleryUrl
        UpdatedPSU  = $true
        Status      = 'Deployed'
    }

    if ($ValidateDeployment) {
        Write-Host ''
        Write-Host 'Step 4: Validating deployment...' -ForegroundColor Yellow
        return Invoke-CIEMPSUModuleDeployment `
            -Environment $Environment `
            -ModulePath $ModulePath `
            -BumpVersion 'Patch' `
            -PublishResult $deployResult `
            -EnvFilePath $EnvFilePath `
            -TimeoutSeconds $TimeoutSeconds
    }

    if (-not $SkipAppRestart) {
        Restart-CIEMPSUApp -ModulePath $ModulePath -StepNumber 4
    }
    else {
        Write-Host ''
        Write-Host 'Step 4: Skipping app restart (-SkipAppRestart).' -ForegroundColor Yellow
    }

    Write-Host ''
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host "Deploy Successful! ($moduleName $resolvedVersion -> $Environment PSU)" -ForegroundColor Green
    Write-Host '========================================' -ForegroundColor Cyan

    $deployResult
}
