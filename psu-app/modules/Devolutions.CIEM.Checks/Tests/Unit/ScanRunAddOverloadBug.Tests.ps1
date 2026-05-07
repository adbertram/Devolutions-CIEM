# Regression test for the "Cannot find an overload for Add and the argument count: 1"
# error that occurs when PSU's long-lived runspace accumulates multiple versions of
# a module class's dynamic assembly. Root cause: [List[CIEMType]] and
# [Dictionary[K, CIEMType]] use module-class types as generic parameters. When PSU
# reloads the module 5+ times, the [List[CIEMCheck v_X]] created in one load receives
# items from [CIEMCheck v_Y] (different assembly), causing List<T>.Add() overload
# resolution to fail with "Cannot find an overload for Add and the argument count: 1".
#
# Solution: Never use module-class types as generic type parameters. Use
# [List[object]] or plain PowerShell arrays instead. This defensive test scans the
# entire psu-app/modules directory to enforce this pattern repo-wide.

BeforeAll {
    $script:ModulesRoot = Join-Path $PSScriptRoot '..' '..' '..' '..' 'modules'
}

Describe 'No module-class-typed generic collections in psu-app/modules' {
    It 'modules directory exists' {
        $script:ModulesRoot | Should -Exist
    }

    It 'no [List[CIEM*]] or [List[object[CIEM*]]] variable assignments in any .ps1' {
        $psFiles = @(Get-ChildItem -Path $script:ModulesRoot -Include '*.ps1' -Recurse -ErrorAction Stop)
        $violatingFiles = @()

        foreach ($file in $psFiles) {
            $source = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
            if ($source -match '\$\w+\s*=\s*\[(System\.Collections\.Generic\.)?List\[CIEM[A-Za-z]+\]\]') {
                $violatingFiles += $file.FullName
            }
        }

        $violatingFiles | Should -HaveCount 0 -Because "module-class-typed lists cause PSU assembly mismatch failures; use [List[object]] or plain arrays instead"
    }

    It 'no [Dictionary[*,CIEM*]] variable assignments in any .ps1' {
        $psFiles = @(Get-ChildItem -Path $script:ModulesRoot -Include '*.ps1' -Recurse -ErrorAction Stop)
        $violatingFiles = @()

        foreach ($file in $psFiles) {
            $source = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
            if ($source -match '\$\w+\s*=\s*\[(System\.Collections\.Generic\.)?Dictionary\[[^\]]*,\s*CIEM[A-Za-z]+\]\]') {
                $violatingFiles += $file.FullName
            }
        }

        $violatingFiles | Should -HaveCount 0 -Because "same root cause as List; use [Dictionary[string,object]] instead"
    }

    It 'no parameter typed [CIEMCheck] or [CIEMServiceCache[]] in any check, helper, or scan file' {
        # Same root cause as the generic-collection bug: module-class types as parameter
        # type constraints fail across PSU's accumulated module assemblies, producing
        # "Cannot convert the 'CIEMCheck' value of type 'CIEMCheck' to type 'CIEMCheck'"
        # at parameter binding time. Use [object] / [object[]] for parameters that travel
        # across runspaces or repeated Import-Module calls.
        $psFiles = @(Get-ChildItem -Path $script:ModulesRoot -Include '*.ps1' -Recurse -ErrorAction Stop) |
            Where-Object { $_.FullName -notmatch '[\\/]Tests[\\/]' }
        $violatingFiles = @()

        foreach ($file in $psFiles) {
            $source = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
            if ($source -match '\[CIEMCheck\]\$\w+' -or $source -match '\[CIEMServiceCache\[\]\]\$\w+') {
                $violatingFiles += $file.FullName
            }
        }

        $violatingFiles | Should -HaveCount 0 -Because "module-class-typed parameters cause PSU cross-import binding failures; use [object] / [object[]] and rely on duck typing for property access"
    }
}
