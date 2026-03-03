function New-CIEMAzureGroupMembership {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates data record')]
    [OutputType('CIEMAzureGroupMembership[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$GroupId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$MemberId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$MemberType,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureGroupMembership[]]$InputObject
    )
    process {
        $ErrorActionPreference = 'Stop'
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            if ($item) { $p = @{ group_id=$item.GroupId; member_id=$item.MemberId; member_type=$item.MemberType }; $cGid=$item.GroupId; $cMid=$item.MemberId }
            else { $p = @{ group_id=$GroupId; member_id=$MemberId; member_type=$MemberType }; $cGid=$GroupId; $cMid=$MemberId }
            $existing = Invoke-CIEMQuery -Query "SELECT group_id FROM azure_group_memberships WHERE group_id = @group_id AND member_id = @member_id" -Parameters @{ group_id = $cGid; member_id = $cMid }
            if ($existing) { throw "Azure group membership ('$cGid', '$cMid') already exists." }
            Invoke-CIEMQuery -Query "INSERT INTO azure_group_memberships (group_id, member_id, member_type) VALUES (@group_id, @member_id, @member_type)" -Parameters $p -AsNonQuery | Out-Null
            Get-CIEMAzureGroupMembership -GroupId $cGid -MemberId $cMid
        }
    }
}
