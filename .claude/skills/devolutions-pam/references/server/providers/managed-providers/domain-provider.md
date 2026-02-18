# Domain user provider

**Source URL:** https://docs.devolutions.net/pam/server/providers/managed-providers/domain-provider/

---

The
Domain user
provider allows Devolutions Server to store the domain account credentials to be used for Active Directory account discovery and to achieve password rotation or password propagation.
Domain user provider
General
Option
Description
Name
Display name of the provider.
Description
Description of the provider.
Domain
Option
Description
Domain name
FQDN of the domain against where the scan or the password rotation will be executed.
Protocol
Protocol used to contact the domain controller.
Select between:
LDAP
LDAPS
Port
Set the port number used with the configured protocol.
Domain controller
Set a Domain controller (optional).
Use Devolutions Gateway
Choose a Devolutions Devolutions Gateway from your list. Requires Devolutions Gateway to be
installed and configured
beforehand.
Credentials
Option
Description
Credential type
Custom credential
or
Linked credential
options.
Username
Username of the domain account.
Password
Password of the domain account.
Linked credential
Credential directly linked to a PAM account.
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

*Downloaded on: 2026-02-18 13:09:27*