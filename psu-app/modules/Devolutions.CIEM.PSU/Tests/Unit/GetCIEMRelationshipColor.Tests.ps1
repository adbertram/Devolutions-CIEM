BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
    New-CIEMDatabase -Path "$TestDrive/ciem.db"
    InModuleScope Devolutions.CIEM { $script:DatabasePath = "$TestDrive/ciem.db" }
}

Describe 'Get-CIEMRelationshipColor' {
    It 'Returns blue (#1976d2) for CONTAINS' {
        Get-CIEMRelationshipColor -Relationship 'CONTAINS' | Should -Be '#1976d2'
    }
    It 'Returns purple (#9c27b0) for member_of' {
        Get-CIEMRelationshipColor -Relationship 'member_of' | Should -Be '#9c27b0'
    }
    It 'Returns red (#f44336) for owner_of' {
        Get-CIEMRelationshipColor -Relationship 'owner_of' | Should -Be '#f44336'
    }
    It 'Returns orange (#ff9800) for has_role_member' {
        Get-CIEMRelationshipColor -Relationship 'has_role_member' | Should -Be '#ff9800'
    }
    It 'Returns green (#4caf50) for transitive_member_of' {
        Get-CIEMRelationshipColor -Relationship 'transitive_member_of' | Should -Be '#4caf50'
    }
    It 'Returns gray fallback (#607d8b) for unknown type' {
        Get-CIEMRelationshipColor -Relationship 'UNKNOWN' | Should -Be '#607d8b'
    }
}
