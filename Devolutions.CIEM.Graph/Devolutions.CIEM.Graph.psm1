#Requires -Version 7.4

Set-StrictMode -Version Latest

$script:ModuleRoot = $PSScriptRoot

# Class files MUST be loaded in dependency order (base classes before derived)
$classLoadOrder = @(
    'CIEMGraphNode.ps1'        # Base node + NodeType enum
    'CIEMIdentityNodes.ps1'    # EntraUser, EntraGroup, etc. (depends on CIEMGraphNode)
    'CIEMRBACNodes.ps1'        # AzureRoleAssignment, etc. (depends on CIEMGraphNode)
    'CIEMGraphEdge.ps1'        # Edge + Relationship enum
    'CIEMGraph.ps1'            # Container (depends on all above)
)

$classesPath = Join-Path -Path $PSScriptRoot -ChildPath 'Classes'
foreach ($className in $classLoadOrder) {
    $classFile = Join-Path -Path $classesPath -ChildPath $className
    if (Test-Path -Path $classFile) {
        try {
            Write-Verbose "Importing class: $className"
            . $classFile
        }
        catch {
            Write-Error "Failed to import class $className : $_"
            throw
        }
    }
}

# Get private and public function definition files
$privatePath = Join-Path -Path $PSScriptRoot -ChildPath 'Private'
$publicPath = Join-Path -Path $PSScriptRoot -ChildPath 'Public'

$Private = @()
$Public = @()

if (Test-Path -Path $privatePath) {
    $Private = @(Get-ChildItem -Path (Join-Path $privatePath '*.ps1') -ErrorAction Stop)
}

if (Test-Path -Path $publicPath) {
    $Public = @(Get-ChildItem -Path (Join-Path $publicPath '*.ps1') -ErrorAction Stop)
}

# Dot source the files (private first, then public)
foreach ($import in @($Private + $Public)) {
    try {
        Write-Verbose "Importing $($import.FullName)"
        . $import.FullName
    }
    catch {
        Write-Error "Failed to import function $($import.FullName): $_"
        throw
    }
}

# Export public functions
foreach ($file in $Public) {
    $content = Get-Content -Path $file.FullName -Raw
    $functionNames = [regex]::Matches($content, '(?m)^function\s+([A-Za-z0-9-]+)') | ForEach-Object { $_.Groups[1].Value }
    foreach ($funcName in $functionNames) {
        Export-ModuleMember -Function $funcName
    }
}
