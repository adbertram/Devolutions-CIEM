function Update-CIEMAzureGroupMembership {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType([CIEMAzureGroupMembership])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$GroupId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$MemberId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$MemberType,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureGroupMembership[]]$InputObject,
        [switch]$PassThru
    )
    process {
        $ErrorActionPreference = 'Stop'
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            if ($item) {
                $cGid = $item.GroupId; $cMid = $item.MemberId
                $setClauses = @(); $params = @{ group_id = $cGid; member_id = $cMid }
                $params.member_type = $item.MemberType; $setClauses += "member_type = @member_type"
            } else {
                $cGid = $GroupId; $cMid = $MemberId
                $existing = Invoke-CIEMQuery -Query "SELECT group_id FROM azure_group_memberships WHERE group_id = @group_id AND member_id = @member_id" -Parameters @{ group_id = $cGid; member_id = $cMid }
                if (-not $existing) { throw "Azure group membership ('$cGid', '$cMid') not found." }
                $setClauses = @(); $params = @{ group_id = $cGid; member_id = $cMid }
                if ($PSBoundParameters.ContainsKey('MemberType')) { $setClauses += "member_type = @member_type"; $params.member_type = $MemberType }
            }
            if ($setClauses.Count -eq 0) { if ($PassThru) { Get-CIEMAzureGroupMembership -GroupId $cGid -MemberId $cMid }; continue }
            Invoke-CIEMQuery -Query "UPDATE azure_group_memberships SET $($setClauses -join ', ') WHERE group_id = @group_id AND member_id = @member_id" -Parameters $params -AsNonQuery | Out-Null
            if ($PassThru) { Get-CIEMAzureGroupMembership -GroupId $cGid -MemberId $cMid }
        }
    }
}
