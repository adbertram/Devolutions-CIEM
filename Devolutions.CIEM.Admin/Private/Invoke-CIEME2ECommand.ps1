function Invoke-CIEME2ECommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('local', 'azure')]
        [string]$Environment,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [Parameter()]
        [int]$TimeoutSeconds = 120
    )

    $ErrorActionPreference = 'Stop'

    $result = Invoke-TestCommand -ScriptBlock $ScriptBlock -Environment $Environment -TimeoutSeconds $TimeoutSeconds
    if ($result.Status -notin @('Completed', 'Warning', 'WarningOutput')) {
        throw "E2E command failed in '$Environment'. PSU job $($result.JobId) returned status $($result.Status)."
    }

    [PSCustomObject]@{
        Suite          = 'E2E'
        Environment    = $Environment
        Framework      = 'PSU'
        JobId          = $result.JobId
        Status         = $result.Status
        Output         = $result.Output
        PipelineOutput = $result.PipelineOutput
        Result         = $result
    }
}
