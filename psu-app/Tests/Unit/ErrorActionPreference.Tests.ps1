BeforeDiscovery {
    $psuAppRoot = Join-Path $PSScriptRoot '..' '..'
    $repoRoot = Resolve-Path (Join-Path $psuAppRoot '..')

    # Directories to scan for function files
    $searchPaths = @(
        (Join-Path $psuAppRoot 'Public')
        (Join-Path $psuAppRoot 'Private')
        (Join-Path $repoRoot 'Devolutions.CIEM.Admin' 'Public')
        (Join-Path $repoRoot 'Devolutions.CIEM.Admin' 'Private')
    )

    # Add all modules/**/Public and modules/**/Private directories.
    $modulesRoot = Join-Path $psuAppRoot 'modules'
    if (Test-Path $modulesRoot) {
        Get-ChildItem -Path $modulesRoot -Directory -Recurse |
            Where-Object {
                $_.Name -eq 'Public' -or $_.Name -eq 'Private'
            } |
            ForEach-Object { $searchPaths += $_.FullName }
    }

    # Exempt files
    $exemptFileNames = @(
        'RegisterCIEMArgumentCompleters.ps1'
    )

    # Collect all .ps1 files from the search paths
    $ps1Files = foreach ($dir in $searchPaths) {
        if (Test-Path $dir) {
            Get-ChildItem -Path $dir -Filter '*.ps1' -File
        }
    }

    $resolvedRoot = $repoRoot.Path

    function Get-FirstFunctionStatement {
        param(
            [Parameter(Mandatory)]
            [System.Management.Automation.Language.FunctionDefinitionAst]$Function
        )

        foreach ($blockName in 'BeginBlock', 'ProcessBlock', 'EndBlock') {
            $block = $Function.Body.$blockName
            if ($block -and $block.Statements.Count -gt 0) {
                return @($block.Statements)[0]
            }
        }

        $null
    }

    # Parse each file with the AST and find functions where the first executable
    # statement is not $ErrorActionPreference = 'Stop'.
    $violations = @(foreach ($file in $ps1Files) {
        # Skip exempt files
        if ($file.Name -in $exemptFileNames) { continue }

        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $file.FullName, [ref]$tokens, [ref]$errors
        )

        # Find all function definitions in the file
        $functions = $ast.FindAll(
            { param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] },
            $true
        )

        foreach ($func in $functions) {
            $firstStatement = Get-FirstFunctionStatement -Function $func

            $hasEapFirst = $firstStatement -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                $firstStatement.Left.ToString() -eq '$ErrorActionPreference' -and
                $firstStatement.Right.ToString() -eq "'Stop'"

            if (-not $hasEapFirst) {
                @{
                    FilePath     = $file.FullName -replace [regex]::Escape($resolvedRoot + [IO.Path]::DirectorySeparatorChar), ''
                    FunctionName = $func.Name
                    FirstStatement = if ($firstStatement) { $firstStatement.Extent.Text } else { '<none>' }
                }
            }
        }
    })

    # Store counts as discovery-time data for -ForEach on the Describe block
    $fileCount = ($ps1Files | Measure-Object).Count
    $violationCount = $violations.Count
}

Describe 'ErrorActionPreference Enforcement' {

    It "Scanned function files from Public/ and Private/ directories" {
        # Re-derive file count at runtime to validate discovery worked
        $psuAppRoot = Join-Path $PSScriptRoot '..' '..'
        $repoRoot = Resolve-Path (Join-Path $psuAppRoot '..')
        $searchPaths = @(
            (Join-Path $psuAppRoot 'Public')
            (Join-Path $psuAppRoot 'Private')
            (Join-Path $repoRoot 'Devolutions.CIEM.Admin' 'Public')
            (Join-Path $repoRoot 'Devolutions.CIEM.Admin' 'Private')
        )
        $modulesRoot = Join-Path $psuAppRoot 'modules'
        if (Test-Path $modulesRoot) {
            Get-ChildItem -Path $modulesRoot -Directory -Recurse |
                Where-Object {
                    $_.Name -eq 'Public' -or $_.Name -eq 'Private'
                } |
                ForEach-Object { $searchPaths += $_.FullName }
        }
        $count = 0
        foreach ($dir in $searchPaths) {
            if (Test-Path $dir) {
                $count += (Get-ChildItem -Path $dir -Filter '*.ps1' -File | Measure-Object).Count
            }
        }
        $count | Should -BeGreaterThan 0
    }

    Context 'Every function must set $ErrorActionPreference = ''Stop'' first' {

        It '<FunctionName> in <FilePath> should set $ErrorActionPreference first' -ForEach $violations {
            # Each violation generates a dedicated failing test with function name and file path.
            $false | Should -BeTrue -Because "function '$($_.FunctionName)' in '$($_.FilePath)' does not start with `$ErrorActionPreference = 'Stop'; first statement is '$($_.FirstStatement)'"
        }
    }
}
