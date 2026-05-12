BeforeAll {
    $script:StartDiscoverySource = Get-Content (Join-Path $PSScriptRoot '..' '..' '..' 'Azure' 'Discovery' 'Public' 'Start-CIEMAzureDiscovery.ps1') -Raw
}

Describe 'Azure discovery notification wiring' {
    It 'calls Send-CIEMNotification after exposure changes are compared' {
        $script:StartDiscoverySource | Should -Match 'Compare-CIEMExposureSnapshot[\s\S]+Send-CIEMNotification'
    }

    It 'passes scheduled discovery context into the notification invocation source' {
        $script:StartDiscoverySource | Should -Match 'InvocationSource\s+\$notificationInvocationSource'
    }
}
