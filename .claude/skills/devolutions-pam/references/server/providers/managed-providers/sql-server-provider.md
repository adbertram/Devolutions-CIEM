# SQL Server provider

**Source URL:** https://docs.devolutions.net/pam/server/providers/managed-providers/sql-server-provider/

---

The
SQL Server
provider allows Devolutions Server to store the SQL account credentials to be used for SQL accounts discovery or to achieve password rotation.
Devolutions' PAM module requires SQL server 2016 and up.
SQL Server provider dialog
General
Option
Description
Name
Display name of the provider.
Description
Optional description of the provider.
Server
Option
Description
Server name
Hostname of the SQL Server.
Credentials
Option
Description
Credential type
Custom credential
or
Linked credential
options.
Username
Username of the SQL account with rights to list accounts.
Password
Password of the SQL account.
Linked credential
Credential directly linked to a PAM account.
Actions
Option
Description
Add PAM
vault
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
Least privileges information required for password rotation of an SQL PAM Provider
Minimum Rights For PAM SQL Server
Scenario
Where to grant
Minimal rights
Minimal T-SQL command
Option for multiple targets
1. Ping() only
Connection database (master if DatabaseName is empty)
Mapped USER; public role is sufficient
CREATE USER [PamServiceLogin] FOR LOGIN [PamServiceLogin];
Â
2. ResetPassword â Instance LOGIN
Server + connection database
See server metadata; ALTER the targeted login; USER in the connection
GRANT VIEW ANY DEFINITION TO [PamServiceLogin];
GRANT ALTER ON LOGIN::[TargetLogin] TO [PamServiceLogin];
GRANT ALTER ANY LOGIN TO [PamServiceLogin];
3. ResetPassword â Contained USER
Target database
Mapped USER; See database metadata; ALTER the targeted user
CREATE USER [PamServiceLogin] FOR LOGIN [PamServiceLogin];
GRANT VIEW DEFINITION TO [PamServiceLogin];
GRANT ALTER ON USER::[TargetUser] TO [PamServiceLogin];
Â
Share your feedback

---

*Downloaded on: 2026-02-18 13:09:30*