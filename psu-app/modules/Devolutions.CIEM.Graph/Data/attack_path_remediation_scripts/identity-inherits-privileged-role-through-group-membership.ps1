<#
.SYNOPSIS
Remediates the attack path finding "{{PATTERN_NAME}}".

.DESCRIPTION
This generated remediation script targets the specific attack path chain below:
{{PATH_CHAIN}}

It removes the identity from the Entra group that grants the privileged role in
this attack path. The commands are generated from the group membership edges in
the finding and execute with the Azure REST API under the selected CIEM authentication profile
context. Review the identity, group, and inherited role before running
the script, then rerun Azure discovery to confirm the attack path is gone.
#>

{{GROUP_MEMBER_REMOVE_COMMANDS}}
