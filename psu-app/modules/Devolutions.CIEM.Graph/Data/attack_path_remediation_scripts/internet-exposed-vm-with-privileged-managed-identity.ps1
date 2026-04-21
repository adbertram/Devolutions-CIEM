<#
.SYNOPSIS
Remediates the attack path finding "{{PATTERN_NAME}}".

.DESCRIPTION
This generated remediation script targets the specific attack path chain below:
{{PATH_CHAIN}}

It removes the network exposure and privileged subscription access links that make
the virtual machine managed identity reachable and high impact. The NSG commands
remove inbound management exposure, and the role assignment commands remove Azure
RBAC permissions found on the path. These commands execute with the Azure REST API
under the selected CIEM authentication profile context. Review the NSG rules and
role assignments before running the script, then rerun Azure discovery to confirm
the attack path is gone.
#>

{{NSG_RULE_DELETE_COMMANDS}}

{{ROLE_ASSIGNMENT_DELETE_COMMANDS}}
