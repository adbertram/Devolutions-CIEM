function Test-CodebuildProjectOlder90Days {
    <#
    .SYNOPSIS
        CodeBuild project has been invoked in the last 90 days

    .DESCRIPTION
        **AWS CodeBuild projects** are assessed for recent activity using the last build invocation timestamp. Projects not invoked within `90 days` or never built are treated as **inactive**.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType('CIEMScanResult[]')]
    param(
        [Parameter(Mandatory)]
        $Check
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: codebuild_project_older_90_days

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check codebuild_project_older_90_days for reference.', 'N/A', 'codebuild Resources')
}
