function Test-VmEnsureUsingManagedDisks {
    <#
    .SYNOPSIS
        Ensure Virtual Machines are utilizing Managed Disks

    .DESCRIPTION
        Migrate blob-based VHDs to Managed Disks on Virtual Machines to exploit the default features of this configuration. The features include: 1. Default Disk Encryption 2. Resilience, as Microsoft will managed the disk storage and move around if underlying hardware goes faulty 3. Reduction of costs over storage accounts

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        $Check
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: vm_ensure_using_managed_disks

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check vm_ensure_using_managed_disks for reference.', 'N/A', 'vm Resources')
}
