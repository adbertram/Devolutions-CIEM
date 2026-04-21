<#
.SYNOPSIS
Remediates the attack path finding "{{PATTERN_NAME}}".

.DESCRIPTION
This generated remediation script targets the specific attack path chain below:
{{PATH_CHAIN}}

It removes Azure RBAC role assignments that grant privileged subscription access
to the virtual machine managed identity in this path. The commands are generated
from the role assignment edges in the finding and execute with the Azure REST API under
the selected CIEM authentication profile context. Review the managed identity and
role scope before running the script, then rerun Azure discovery to confirm the
attack path is gone.
#>

{{ROLE_ASSIGNMENT_DELETE_COMMANDS}}
