BeforeDiscovery {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..')
    $publicRoots = @(
        (Join-Path $repoRoot 'psu-app' 'Public')
        (Join-Path $repoRoot 'Devolutions.CIEM.Admin' 'Public')
    )

    $modulesRoot = Join-Path $repoRoot 'psu-app' 'modules'
    if (Test-Path $modulesRoot) {
        $publicRoots += @(Get-ChildItem -Path $modulesRoot -Directory -Recurse |
            Where-Object { $_.Name -eq 'Public' } |
            Select-Object -ExpandProperty FullName)
    }

    $publicFiles = @($publicRoots | Where-Object { Test-Path $_ } | ForEach-Object {
        Get-ChildItem -Path $_ -Filter '*.ps1' -File
    })

    $violations = foreach ($file in $publicFiles) {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $file.FullName, [ref]$tokens, [ref]$errors
        )

        $functions = $ast.FindAll(
            { param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] },
            $true
        )

        foreach ($function in $functions) {
            foreach ($attribute in @($function.Body.ParamBlock.Attributes)) {
                if ($attribute.TypeName.FullName -eq 'OutputType' -and $attribute.Extent.Text -match '\[CIEM') {
                    @{
                        FilePath = $file.FullName -replace [regex]::Escape($repoRoot.Path + [IO.Path]::DirectorySeparatorChar), ''
                        FunctionName = $function.Name
                        Source = $attribute.Extent.Text
                    }
                }
            }

            foreach ($parameter in @($function.Body.ParamBlock.Parameters)) {
                if ($parameter.Extent.Text -match '\[CIEM') {
                    @{
                        FilePath = $file.FullName -replace [regex]::Escape($repoRoot.Path + [IO.Path]::DirectorySeparatorChar), ''
                        FunctionName = $function.Name
                        Source = $parameter.Extent.Text
                    }
                }
            }
        }
    }
    $scanSummary = @(@{ FileCount = $publicFiles.Count })
}

Describe 'Public API class type isolation' {
    It 'Scans public module functions' -ForEach $scanSummary {
        $FileCount | Should -BeGreaterThan 0
    }

    It '<FunctionName> in <FilePath> does not expose CIEM class types' -ForEach $violations {
        $false | Should -BeTrue -Because "public function '$($_.FunctionName)' in '$($_.FilePath)' exposes module class type in '$($_.Source)'"
    }
}
