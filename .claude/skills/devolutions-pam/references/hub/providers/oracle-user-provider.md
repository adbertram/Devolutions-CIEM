# Oracle user provider

**Source URL:** https://docs.devolutions.net/pam/hub/providers/oracle-user-provider/

---

The
Oracle user
provider allows Devolutions Hub Business to store Oracle account credentials to be used to achieve password rotation.
Oracle user provider configuration
General
SETTINGS
DESCRIPTION
Name
Display name of the provider.
Description
Optional description of the provider.
Host name
FQDN of the Oracle server against where the scan or the password rotation will be executed.
Service name
Name of the Oracle service.
Port
Set the port number used with to connect on the Oracle host.
Username
Username of the Oracle account with rights to reset passwords.
Password
Password of the Oracle user account.
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
PowerShell settings
SETTING
DESCRIPTION
PowerShell settings mode
Choose a PowerShell settings mode between:
Default (Data source settings)
: Use the default configuration for PowerShell as defined in
Administration
â
Privileged access
â
Settings
â
PowerShell default settings
.
Data source settings
: Select the PowerShell settings defined within the same data source.
Custom
: Create custom PowerShell settings for the provider.
Share your feedback

---

*Downloaded on: 2026-02-18 13:10:04*