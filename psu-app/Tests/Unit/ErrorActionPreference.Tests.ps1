BeforeDiscovery {
    $psuAppRoot = Join-Path $PSScriptRoot '..' '..'
    $repoRoot = Resolve-Path (Join-Path $psuAppRoot '..')

    # Exempt files
    $exemptFileNames = @(
        'RegisterCIEMArgumentCompleters.ps1'
    )

    $resolvedRoot = $repoRoot.Path

    $trackedPowerShellFiles = & git -C $resolvedRoot ls-files '*.ps1' '*.psm1'
    $ps1Files = foreach ($relativePath in $trackedPowerShellFiles) {
        if ($relativePath -match '\.Tests\.ps1$') { continue }
        if ($relativePath -match '(^|/)Classes/') { continue }
        Get-Item (Join-Path $resolvedRoot $relativePath)
    }

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
    $scanSummary = @(@{ FileCount = $fileCount })
}

Describe 'ErrorActionPreference Enforcement' {

    It "Scanned tracked PowerShell source files" -ForEach $scanSummary {
        $FileCount | Should -BeGreaterThan 0
    }

    Context 'Every function must set $ErrorActionPreference = ''Stop'' first' {

        It '<FunctionName> in <FilePath> should set $ErrorActionPreference first' -ForEach $violations {
            # Each violation generates a dedicated failing test with function name and file path.
            $false | Should -BeTrue -Because "function '$($_.FunctionName)' in '$($_.FilePath)' does not start with `$ErrorActionPreference = 'Stop'; first statement is '$($_.FirstStatement)'"
        }
    }
}
