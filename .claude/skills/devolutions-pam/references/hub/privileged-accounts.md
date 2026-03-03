# Privileged accounts

**Source URL:** https://docs.devolutions.net/pam/hub/privileged-accounts/

---

Devolutions Hub's privileged access management module allows privileged account passwords to be automatically reset once access has expired. You can also manually trigger the password reset via the menu.
Privileged accounts are added and managed in the PAM vault. The accounts can be organized within folders or directly saved in the root.
You can use the
Check-out
feature to request temporary access to a privileged account entry in a PAM vault. The approver must then approve or deny the request. To learn more about this process, see
Request access to a privileged account
or
Approve access to a privileged account
.
Create a privileged account entry
The only entry types that can be added in your PAM vault (except for folders) are
Entra ID users
and managed
Providers
.
Privileged account in PAM
When creating your privileged account, you need to provide some information. See the table below.
General information
Option
Description
Name
Name of the privileged account entry.
Folder
Location of the entry inside the PAM vault. Leave it empty to create the entry at the root.
Connection information
Option
Description
Provider
Name of the PAM provider.
Username
Username of the privileged account. The username must match the real username used in the provider.
Current password
If you know the password, enter it here. If not, you can leave this field blank and reset the password on the entry after its creation. Editing your password in the
Edit credential
window only changes your password in the hub database. The password will not be updated on the domain. If you would like to change your password everywhere, click
Reset password
on the credential entry.
Password settings
Option
Description
Password policy mode
Select the password policy mode to use between:
Inherited
: Inherits the password policy specified in the parent folder.
Custom
: Select a custom password policy previously created.
From provider
: Uses the provider's password policy.
Verifying your configuration
To make sure that your configuration and the Devolutions Hub Services installation work properly, try resetting your password after having created the entry. To do so, select the entry in the
Navigation pane
. Then, click the ellipsis button at the top right and select
Reset password
.
Reset password
In the entry logs, you can see the different activities from the request to the password reset.
Entry logs
To see the password reset status, go to the
Tasks
report in
Reports â Privileged access â Tasks
. If it worked, you will see that the task status is set to
Completed
.
Completed password reset task
Share your feedback

---

*Downloaded on: 2026-02-18 13:09:47*