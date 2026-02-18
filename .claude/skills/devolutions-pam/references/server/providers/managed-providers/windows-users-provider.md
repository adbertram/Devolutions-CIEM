# Windows user provider

**Source URL:** https://docs.devolutions.net/pam/server/providers/managed-providers/windows-users-provider/

---

The
Windows user
provider allows Devolutions Server to store the Windows account credentials to be used for Windows local accounts discovery or to achieve password rotation. See the
Create Windows user provider
knowledge base article for more information on its configuration.
The
scheduler service
must be installed and running to use this feature.
If you use a different administrator than the default built-in one, you need to disable the "User Account Control: Admin Approval Mode for the Built-in Administrator account" policy. See Microsoft's article for more information:
Description of User Account Control and remote restrictions in Windows Vista
.
Windows user provider
General
Option
Description
Name
Display name of the provider.
Description
Optional description of the provider.
Host
Option
Description
Computer name
Computer name of the Windows machine.
Credentials
Option
Description
Credential type
Custom credential
or
Linked credential
options.
Username
Username of the Windows local account with rights to list accounts.
Password
Password of the Windows local account.
Linked credential
Credential directly linked to a PAM account.
Enable CredSSP support
Protocol for delegating credentials to target server.
Actions
Option
Description
Add PAM vault
Will create a PAM vault with the provider's name if enabled.
Add a new account discovery configuration
Will open the
Account discovery configuration
dialog if enabled.
Password settings
Option
Description
Password template used on generation
Password template that will be used to generate the password during the reset password operation.
Share your feedback

---

*Downloaded on: 2026-02-18 13:09:33*