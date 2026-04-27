# Cisco user provider

**Source URL:** https://docs.devolutions.net/pam/hub/providers/cisco-user-provider/

---

The
Cisco User
provider in Devolutions Hub Business is designed to securely store Cisco account credentials used for password rotation.
General
OPTION
DESCRIPTION
Name
Specify a descriptive name for the provider.
Description
Add context or notes about the provider's purpose.
Hostname
(required)
Enter the Cisco serverâs address.
Port
Type the port number.
Password
(required)
Enter the associated password for the Cisco user.
Checkout policy
OPTION
DESCRIPTION
Checkout policy mode
Default (Inherited)
: This mode uses the
default checkout policy
defined in
Administration
â
Privileged access
â
Settings
â
PAM checkout policy
.
Inherited
: Inherit the checkout policy from a higher-level entry.
Custom
: Configure a custom policy for this specific provider.
Account lifecycle policy
OPTION
DESCRIPTION
Password rotation
Select the password policy. Password policies are created in
Administration
â
Management
â
Password policies
.
Synchronization
Default (Inherited)
: This mode uses the
default PAM synchronization policy
defined in
Administration
â
Privileged access
â
Settings
â
PAM account lifecycle policy
â
PAM synchronization policy
.
None
: Disables synchronization.
Inherited
: Inherit the
PAM synchronization policy
from a higher-level entry.
Custom
: Define a custom synchronization interval (e.g., hourly, daily).
PowerShell settings
OPTION
DESCRIPTION
PowerShell settings mode
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

*Downloaded on: 2026-02-18 13:10:00*