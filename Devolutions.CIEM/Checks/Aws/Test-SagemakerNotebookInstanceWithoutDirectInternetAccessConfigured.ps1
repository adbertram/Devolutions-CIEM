function Test-SagemakerNotebookInstanceWithoutDirectInternetAccessConfigured {
    <#
    .SYNOPSIS
        Amazon SageMaker notebook instance has direct internet access disabled

    .DESCRIPTION
        Amazon SageMaker notebook instances are evaluated for the `DirectInternetAccess` setting.
        
        Instances with it disabled use only VPC connectivity; instances with it enabled permit direct outbound internet access.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [CIEMCheck]$Check
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: sagemaker_notebook_instance_without_direct_internet_access_configured

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check sagemaker_notebook_instance_without_direct_internet_access_configured for reference.', 'N/A', 'sagemaker Resources')
}
