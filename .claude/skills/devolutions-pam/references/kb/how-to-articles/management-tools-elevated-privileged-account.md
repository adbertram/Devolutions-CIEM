# Elevate management tools elevated with a privileged account

**Source URL:** https://docs.devolutions.net/pam/kb/how-to-articles/management-tools-elevated-privileged-account/

---

Discover how to manage tools with elevated privileges using the PowerShell Remote session type in Remote Desktop Manager. It establishes a connection to a remote host through ps-sessions with different credentials.
Prerequisite
WinRM HTTPS listener
is properly configured on the target workstation.
A
valid SSL certificate
is used with an appropriate thumbprint.
Configuring a
PowerShell terminal (Remote) entry
Open
Remote Desktop Manager.
Click on
New entry
and search for
PowerShell terminal (Remote)
.
Select
PowerShell terminal (Remote)
as the session type.
Enter the name, the host and the credentials.
You can configure multiple hosts and select the destination at the startup of the session.
The elevated credentials could be a custom one from AD, a privileged access management account, or any other credentials entry from Remote Desktop Manager.
To elevate permissions, the session must be configured to
run as an administrator
.
Navigate to the
Run as
tab.
Enable the setting
Run as administrator
. Note that port 5986 - HTTPS (WinRM) is used when running the PowerShell entry as an administrator.
Run as tab - Enable the setting Run as administrator
Click
Add
to save the PowerShell entry.
Execute the PowerShell entry.
To confirm that the session is running under a privileged account, use the following PowerShell commands:
Check the current user
whoami
Verify elevated permissions
$currentPrincipal
=
New-Object
Security.Principal.WindowsPrincipal([
Security.Principal.WindowsIdentity
]::GetCurrent())
$currentPrincipal
.IsInRole([
Security.Principal.WindowsBuiltInRole
]::Administrator)
Share your feedback

---

*Downloaded on: 2026-02-18 13:10:45*