# PostgreSQL user provider

**Source URL:** https://docs.devolutions.net/pam/hub/providers/postgresql-provider/

---

The
PostgreSQL user
provider is designed to extend native PostgreSQL capabilities by enabling auditable password change operations.
As PostgreSQL does not offer built-in support for logging password modifications, this provider bridges that gap by generating detailed audit logs for such events. Its integration supports improved security oversight and helps organizations meet compliance requirements related to privileged account management.
PostgreSQL user provider configuration
General
SETTINGS
DESCRIPTION
Name
Enter a name for the provider.
Description
Give additional context or notes about the provider. This is optional.
Host
Enter the IP address or hostname of the PostgreSQL database.
Username
Enter the PostgreSQL username.
Database name
Choose a name for the database.
Password
Enter the PostgreSQL userâs password.
Advanced
SETTINGS
DESCRIPTION
Connection settings
Add additional PostgreSQL connection settings.
Checkout policy
SETTINGS
DESCRIPTION
Checkout policy mode
Choose a checkout policy mode between:
Default (inherited)
Inherited
Custom
Checkout mode
Choose whether checkouts are obligatory or not. This amounts to turning the checkouts on/off.
Approval mode
Determine if checkouts require approval or not.
Users can approve their own checkout
Determine if users can approve their own checkout request or whether they need the approval of an administrator.
Checkout reason
Force users to add a reason in checkout requests.
Checkout time (minutes)
Set the precise checkout time for all users, in minutes.
Max checkout time (minutes)
Set the maximum checkout time, but leave it to the users to specify their needs for each request.
Account lifecycle policy
SETTINGS
DESCRIPTION
Password policy
Choose a
password policy
previously configured in
Administration
â
Password policies
.
Synchronization schedule
Set a date and time for automatic synchronization between the provider and its user/user groups.
Share your feedback

---

*Downloaded on: 2026-02-18 13:10:05*