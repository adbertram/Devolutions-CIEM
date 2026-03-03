# PostgreSQL user provider

**Source URL:** https://docs.devolutions.net/pam/server/providers/managed-providers/postgresql-devolutions-server-provider/

---

The
PostgreSQL user
PAM provider is designed to extend native PostgreSQL capabilities by enabling auditable password change operations.
As PostgreSQL does not offer built-in support for logging password modifications, this provider bridges that gap by generating detailed audit logs for such events. Its integration supports improved security oversight and helps organizations meet compliance requirements related to privileged account management.
General
OPTION
DESCRIPTION
Name
Enter the provider name.
Description
Give additional context or notes about the provider.
Server
OPTION
DESCRIPTION
Server name
Enter the
Server name
.
Database name
Enter the
Database name
.
Credentials
OPTION
DESCRIPTION
Credential type
Select
Custom
as credential type and enter the username and password.
Select a
Linked credential
entry (e.g., from a PAM vault or user vault).
Actions
OPTION
DESCRIPTION
Add PAM vault
Automatically creates a
PAM vault
.
Add a new account discovery configuration
Will open the
Account discovery configuration
to discover the SQL accounts.
Share your feedback

---

*Downloaded on: 2026-02-18 13:09:29*