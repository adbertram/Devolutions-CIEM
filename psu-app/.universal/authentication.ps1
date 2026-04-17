Set-PSUAuthenticationMethod -Type "Form" -ScriptBlock {
    param(
        [PSCredential]$Credential
    )

    if ($Credential.UserName -ieq "admin" -and $Credential.GetNetworkCredential().Password -eq "admin") {
        New-PSUAuthenticationResult -Success -UserName "admin"
        return
    }

    New-PSUAuthenticationResult -ErrorMessage "Bad username or password"
}
