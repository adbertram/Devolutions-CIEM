<#
.SYNOPSIS
Remediates the attack path finding "{{PATTERN_NAME}}".

.DESCRIPTION
This generated remediation script targets the specific attack path chain below:
{{PATH_CHAIN}}

It deletes the Azure Network Security Group rules that expose management ports to
the internet. The commands are generated from the inbound NSG rule edges in the
finding and execute with the Azure REST API under the selected CIEM authentication profile
context. Review the rule names and resource scopes before running the
script, then rerun Azure discovery to confirm the attack path is gone.
#>

{{NSG_RULE_DELETE_COMMANDS}}
