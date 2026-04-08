# Regression test for the "Cannot find an overload for Add and the argument count: 1"
# error reproduced via PSU's Invoke-PSUScript path. Root cause: $selectedChecks was
# typed as [List[CIEMCheck]] in Invoke-CIEMScan. PowerShell module classes get a fresh
# dynamic assembly per Import-Module, so when PSU has accumulated multiple class
# assemblies (5 in the user's session), the [List[CIEMCheck v_X]] and [CIEMCheck v_Y]
# resolved at runtime can be different versions, causing List<T>.Add(item) to fail
# the overload resolution.
#
# Pester runs with a single module load so the bug doesn't trigger directly here. The
# defensive structural test below ensures Invoke-CIEMScan does not reintroduce the
# strongly-typed list.

BeforeAll {
    $script:InvokeCIEMScanPath = Join-Path $PSScriptRoot '..' '..' 'Private' 'Invoke-CIEMScan.ps1'
}

Describe 'Invoke-CIEMScan does not use module-class-typed collections' {
    It 'has Invoke-CIEMScan.ps1 on disk' {
        $script:InvokeCIEMScanPath | Should -Exist
    }

    It 'does not declare any [List[CIEMCheck]] or [List[CIEMCheckSeverity]] etc. — module class types in generic collections trigger assembly-version mismatches in PSU' {
        $source = Get-Content -Path $script:InvokeCIEMScanPath -Raw
        # Check for actual variable assignments, not comments explaining why they're bad
        $source | Should -Not -Match '\$\w+\s*=\s*\[(System\.Collections\.Generic\.)?List\[CIEM[A-Za-z]+\]\]'
    }

    It 'does not declare any [Dictionary[string,CIEMCheck]] etc. — same root cause' {
        $source = Get-Content -Path $script:InvokeCIEMScanPath -Raw
        $source | Should -Not -Match '\[(System\.Collections\.Generic\.)?Dictionary\[[^\]]*,\s*CIEM[A-Za-z]+\]\]'
    }
}
