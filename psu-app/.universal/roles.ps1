New-PSURole -Name "Administrator" -Policy {
    param($User)

    $User.Identity.Name -ieq "admin"
}
