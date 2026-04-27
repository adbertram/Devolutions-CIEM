# MySQL user provider

**Source URL:** https://docs.devolutions.net/pam/server/providers/password-reset-only-providers/mysql-user-provider/

---

The
MySQL user
provider allows Devolutions Server to store the MySQL account credentials to be used for MySQL accounts discovery or to achieve password rotation.
MySQL user provider
General
Option
Description
Name
Display name of the provider.
Template name
Description of the provider.
Properties
Option
Description
Host name
FQDN of the domain against where the scan or the password rotation will be executed.
Port
Set the port number used with to connect on the MySQL host.
Username
Username of the MySQL account with rights to list accounts.
Password
Password of the MySQL account.
Credentials
Option
Description
Credential type
Custom credential
or
Linked credential
options.
Password
Password of the MySQL account.
Linked credential
Credential directly linked to a PAM account.
Actions
Option
Description
Add PAM vault
Will create a PAM vault with the provider's name if enabled.
Password settings
Option
Description
Password template used on generation
Password template that will be used to generate the password during the reset password operation.
Share your feedback

---

*Downloaded on: 2026-02-18 13:09:36*