#Requires -Version 7.4

$script:ModuleRoot = $PSScriptRoot

# Dot-source classes in explicit order (order matters for type dependencies)
$classLoadOrder = @('ResourceGraphClasses.ps1')
foreach ($className in $classLoadOrder) {
    . (Join-Path "$script:ModuleRoot/Classes" $className)
}

# Dot-source private functions
$privateFiles = Get-ChildItem -Path "$script:ModuleRoot/Private" -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue
foreach ($file in $privateFiles) {
    . $file.FullName
}

# Dot-source public functions and export them
$publicFiles = Get-ChildItem -Path "$script:ModuleRoot/Public" -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue
foreach ($file in $publicFiles) {
    . $file.FullName
}

$publicFunctions = $publicFiles | ForEach-Object { $_.BaseName }
if ($publicFunctions) {
    Export-ModuleMember -Function $publicFunctions
}
