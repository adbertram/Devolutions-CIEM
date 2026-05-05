function Invoke-CIEMAzCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$ArgumentList
    )

    $ErrorActionPreference = 'Stop'

    $output = az @ArgumentList 2>&1
    $exitCode = $global:LASTEXITCODE
    if ($exitCode -ne 0) {
        $commandNameLength = if ($ArgumentList.Count -ge 3 -and $ArgumentList[0] -eq 'deployment' -and $ArgumentList[1] -eq 'group') {
            3
        }
        else {
            [Math]::Min(2, $ArgumentList.Count)
        }
        $commandName = "az $(@($ArgumentList | Select-Object -First $commandNameLength) -join ' ')"
        $sanitizedArguments = @($ArgumentList | ForEach-Object {
                if ($_ -match '^(jwtSigningKey|password|secret|token)=') {
                    "$($matches[1])=***"
                }
                else {
                    $_
                }
            })
        throw "$commandName failed with exit code $exitCode. Arguments: az $($sanitizedArguments -join ' '). Output: $(@($output) -join "`n")"
    }

    $output
}
