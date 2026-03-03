function Save-CIEMAzureGroupMembership {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Upsert operation')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$GroupId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$MemberId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$MemberType,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureGroupMembership[]]$InputObject
    )
    process {
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            if ($item) { $p = @{ group_id=$item.GroupId; member_id=$item.MemberId; member_type=$item.MemberType } }
            else { $p = @{ group_id=$GroupId; member_id=$MemberId; member_type=$MemberType } }
            Invoke-CIEMQuery -Query "INSERT OR REPLACE INTO azure_group_memberships (group_id, member_id, member_type) VALUES (@group_id, @member_id, @member_type)" -Parameters $p -AsNonQuery | Out-Null
        }
    }
}
