function Get-CIEMPSUJobOutput {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object]$Job,

        [Parameter()]
        [switch]$Integrated
    )

    $ErrorActionPreference = 'Stop'

    $getOutputParameters = @{
        Job      = $Job
        AsObject = $true
    }
    if ($Integrated) {
        $getOutputParameters.Integrated = $true
    }

    $ansiEscapePattern = "$([char]27)\[[0-?]*[ -/]*[@-~]"
    foreach ($entry in @(Get-PSUJobOutput @getOutputParameters)) {
        if ($null -eq $entry.Message) {
            throw 'Cannot read PSU job output because an output entry message is missing.'
        }

        [regex]::Replace([string]$entry.Message, $ansiEscapePattern, '')
    }
}
