function GetCIEMAttackPathRuleScopeHash {
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    $rows = @(Invoke-CIEMQuery -Query @"
SELECT
    id,
    name,
    severity,
    category,
    description,
    remediation,
    remediation_script_path,
    psu_script_name,
    steps_json
FROM attack_path_rules
WHERE disabled = 0
ORDER BY id
"@)

    $fingerprints = @(foreach ($row in $rows) {
        $payload = [ordered]@{
            id                      = [string]$row.id
            name                    = [string]$row.name
            severity                = [string]$row.severity
            category                = [string]$row.category
            description             = [string]$row.description
            remediation             = [string]$row.remediation
            remediation_script_path = [string]$row.remediation_script_path
            psu_script_name         = [string]$row.psu_script_name
            steps_json              = [string]$row.steps_json
        } | ConvertTo-Json -Depth 10 -Compress

        GetCIEMSHA256Hash -InputText $payload
    })

    GetCIEMSHA256Hash -InputText ($fingerprints -join "`n")
}
