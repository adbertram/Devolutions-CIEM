# Apply password rotation to PAM provider credentials

**Source URL:** https://docs.devolutions.net/pam/kb/how-to-articles/password-rotation-pam-provider-credentials/

---

This workflow is used to apply a PAM managed account as a PAM provider identity. The objective is to have a
password rotation
applied to the PAM provider's credentials.
A
PAM vault
must be set up before following the steps below.
Open Devolutions Server.
Go to
Administration
â
Privileged access
â
Providers
to create a provider.
Administration â Privileged access â Providers
In the provider window, select
Custom
in the
Credential type
drop-down menu.
Open a PAM vault.
Add a
Domain user
to the PAM vault by clicking
+ icon (Add)
.
Add a domain user to the PAM vault
Manually populate the fields and select the
provider
.
Enter the
username
and the
current password
.
Populate the fields and select the provider
Apply the
Password rotation schedule
.
Click
Add
.
The account is out of sync (not verified yet).
Right-click
on the account.
Select
Check
Synchronization Status
.
The synchronization status should turn green.
Go back to
Administration
â
Privileged access
â
Providers
.
Select your provider and change the
Custom credentials
for
Linked credential
.
The
Privileged account
window opens.
Select the account added beforehand.
Click
OK
to save and close the window.
Share your feedback

---

*Downloaded on: 2026-02-18 13:10:46*