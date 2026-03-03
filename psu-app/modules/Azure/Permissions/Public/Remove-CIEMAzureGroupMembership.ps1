function Remove-CIEMAzureGroupMembership {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')][string]$GroupId,
        [Parameter(Mandatory, ParameterSetName = 'ById')][string]$MemberId,
        [Parameter(Mandatory, ParameterSetName = 'ByGroupId')][string]$GroupIdFilter,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureGroupMembership[]]$InputObject
    )
    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) { if ($PSCmdlet.ShouldProcess("('$($item.GroupId)', '$($item.MemberId)')", 'Remove Azure group membership')) { Invoke-CIEMQuery -Query "DELETE FROM azure_group_memberships WHERE group_id = @group_id AND member_id = @member_id" -Parameters @{ group_id = $item.GroupId; member_id = $item.MemberId } -AsNonQuery | Out-Null } }
        } elseif ($PSCmdlet.ParameterSetName -eq 'ByGroupId') {
            if ($PSCmdlet.ShouldProcess("group '$GroupIdFilter'", 'Remove all Azure group memberships')) { Invoke-CIEMQuery -Query "DELETE FROM azure_group_memberships WHERE group_id = @group_id" -Parameters @{ group_id = $GroupIdFilter } -AsNonQuery | Out-Null }
        } else {
            if ($PSCmdlet.ShouldProcess("('$GroupId', '$MemberId')", 'Remove Azure group membership')) { Invoke-CIEMQuery -Query "DELETE FROM azure_group_memberships WHERE group_id = @group_id AND member_id = @member_id" -Parameters @{ group_id = $GroupId; member_id = $MemberId } -AsNonQuery | Out-Null }
        }
    }
}
