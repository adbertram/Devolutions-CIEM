function Get-CIEMAzureGroupMembership {
    [CmdletBinding()]
    [OutputType('CIEMAzureGroupMembership[]')]
    param(
        [Parameter()][string]$GroupId,
        [Parameter()][string]$MemberId,
        [Parameter()][string]$MemberType
    )
    $ErrorActionPreference = 'Stop'
    $conditions = @(); $params = @{}
    if ($PSBoundParameters.ContainsKey('GroupId')) { $conditions += "group_id = @group_id"; $params.group_id = $GroupId }
    if ($PSBoundParameters.ContainsKey('MemberId')) { $conditions += "member_id = @member_id"; $params.member_id = $MemberId }
    if ($PSBoundParameters.ContainsKey('MemberType')) { $conditions += "member_type = @member_type"; $params.member_type = $MemberType }
    $query = "SELECT * FROM azure_group_memberships"
    if ($conditions.Count -gt 0) { $query += " WHERE " + ($conditions -join ' AND ') }
    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $params)
    @(foreach ($row in $rows) {
        $obj = [CIEMAzureGroupMembership]::new()
        $obj.GroupId = $row.group_id; $obj.MemberId = $row.member_id; $obj.MemberType = $row.member_type
        $obj
    })
}
