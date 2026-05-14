function Remove-CIEMAuthenticationProfile {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Delete operation')]
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )

    $ErrorActionPreference = 'Stop'

    $profile = @(Get-CIEMAuthenticationProfile -Id $Id)
    if ($profile.Count -ne 1) {
        throw "Authentication profile '$Id' was not found."
    }

    $assignments = @(Get-CIEMAuthenticationProfileAssignment -AuthenticationProfileId $Id)
    if ($assignments.Count -gt 0) {
        $assignment = $assignments[0]
        throw "Authentication profile '$Id' is assigned to $($assignment.UsageType) '$($assignment.UsageId)'. Assign another profile before removing it."
    }

    foreach ($secretName in @(GetCIEMAuthenticationProfileOwnedSecretName -ProfileId $Id -SecretRefs $profile[0].SecretRefs)) {
        Remove-CIEMSecret -Name $secretName
    }

    Invoke-CIEMQuery -Query 'DELETE FROM authentication_profiles WHERE id = @id' -Parameters @{ id = $Id } -AsNonQuery | Out-Null
}
