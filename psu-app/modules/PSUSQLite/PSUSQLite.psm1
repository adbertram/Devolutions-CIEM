# Load private functions
foreach ($file in (Get-ChildItem "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue)) {
    . $file.FullName
}

# Load Microsoft.Data.Sqlite assembly BEFORE loading public functions (they reference the types)
ResolvePSUSQLiteAssembly

# Load public functions
foreach ($file in (Get-ChildItem "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue)) {
    . $file.FullName
}
