# Local SSH user provider

**Source URL:** https://docs.devolutions.net/pam/server/providers/managed-providers/local-ssh-provider/

---

The
Local SSH user
provider allows Devolutions Server to store the SSH local account credentials to be used for SSH accounts discovery or to achieve password rotation.
Local SSH user provider
The wheel group under Linux is traditionally used to control access to root privileges via the sudo system. Members of this group are authorized to elevate their privileges to those of the system administrator, or root, usually after being authenticated by their personal password.
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
Host
IP address or host name where the SSH accounts are located.
Port
Set the port number used to communicate with the host.
Timeout (sec)
Set a timeout for communication with the host.
Credentials
Option
Description
Credential type
Custom credential
or
Linked credential
options.
Username
Username of the SSH account.
Password
Password of the SSH account.
Linked credential
Credential directly linked to a PAM account.
Actions
Option
Description
Add PAM vault
Create a PAM vault with the provider's name if enabled.
Add a new account discovery configuration
Will open the
Account discovery configuration
dialog if enabled.
Password settings
Option
Description
Password template used on generation
Password template used to generate the password during the reset password operation.
Share your feedback

---

*Downloaded on: 2026-02-18 13:09:28*