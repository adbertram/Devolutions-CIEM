# Attack path: {{PATTERN_NAME}}
# Finding: {{PATH_CHAIN}}
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

az account show --only-show-errors | Out-Null

{{GROUP_MEMBER_REMOVE_COMMANDS}}

Write-Host 'Remediation commands completed. Rerun Azure discovery in CIEM.'
