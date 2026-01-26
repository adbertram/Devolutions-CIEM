#Requires -Version 5

Set-StrictMode -Version Latest

# Module root path for use by all functions
$script:ModuleRoot = $PSScriptRoot

# Load configuration into script-scoped variable
$script:configFilePath = Join-Path -Path $PSScriptRoot -ChildPath 'config.json'
if (Test-Path $script:configFilePath) {
    try {
        $script:Config = Get-Content $script:configFilePath -Raw | ConvertFrom-Json
    } catch {
        Write-Warning "Failed to load config.json: $_"
        $script:Config = $null
    }
}

# Apply default configuration if not loaded
if (-not $script:Config) {
    $script:Config = [PSCustomObject]@{
        azure = [PSCustomObject]@{
            authentication = [PSCustomObject]@{
                method = 'CurrentContext'
            }
            subscriptionFilter = @()
            endpoints = [PSCustomObject]@{
                graphApi = 'https://graph.microsoft.com/v1.0'
                armApi   = 'https://management.azure.com'
            }
        }
        scan = [PSCustomObject]@{
            throttleLimit    = 10
            timeoutSeconds   = 300
            continueOnError  = $true
        }
        pam = [PSCustomObject]@{
            remediationUrl = 'https://devolutions.net/pam'
        }
    }
}

# Initialize script-scoped service variables (populated during scan)
$script:EntraService = @{}
$script:IAMService = @{}
$script:KeyVaultService = @{}
$script:StorageService = @{}

# Get public and private function definition files
$Public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -Recurse -ErrorAction SilentlyContinue)

# Dot source the files
foreach ($import in @($Private + $Public)) {
    try {
        Write-Verbose "Importing $($import.FullName)"
        . $import.FullName
    } catch {
        Write-Error "Failed to import function $($import.FullName): $_"
    }
}

# Export public functions
foreach ($file in $Public) {
    Export-ModuleMember -Function $file.BaseName
}
