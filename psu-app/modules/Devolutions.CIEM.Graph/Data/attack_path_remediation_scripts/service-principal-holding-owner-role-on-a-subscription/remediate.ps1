# Attack path: {{PATTERN_NAME}}
# Finding: {{PATH_CHAIN}}
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

az account show --only-show-errors | Out-Null

{{ROLE_ASSIGNMENT_DELETE_COMMANDS}}

Write-Host 'Remediation commands completed. Rerun Azure discovery in CIEM.'
