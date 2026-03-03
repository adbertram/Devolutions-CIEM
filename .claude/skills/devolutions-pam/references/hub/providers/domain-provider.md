# Domain user provider

**Source URL:** https://docs.devolutions.net/pam/hub/providers/domain-provider/

---

The
Domain user
provider allows Devolutions Hub Business to store the domain account credentials to be used for Active Directory account discovery and to achieve password rotation or password propagation.
Domain user provider
General
SETTINGS
DESCRIPTION
Name
Display name of the provider.
Description
Description of the provider.
Domain name
FQDN of the domain against where the scan or the password rotation will be executed.
Protocol
Protocol used to contact the domain controller. Select between:
LDAP
LDAPS
Port
Set the port number used with the configured protocol.
Use Devolutions Gateway
Choose a Devolutions Devolutions Gateway from your list. Requires Devolutions Gateway to be
installed and configured
beforehand.
Domain controller
Set a Domain controller (optional).
Username
Username of the domain account.
Password
Password of the domain account.
Checkout policy
SETTINGS
DESCRIPTION
Checkout policy mode
Choose a
checkout policy mode
:
Default (inherited)
Inherited:
Inherit the checkout policy defined in
Administration
â
Privilege access management
â
Settings
â
Checkout policy.
Custom:
Defines a custom checkout policy or uses the checkout policies defined in
Administration
â
Privilege access management
â
Checkout policies.
Account lifecycle policy
SETTINGS
DESCRIPTION
Account lifecycle policy
Choose a
checkout policy mode
:
Default (inherited)
Inherited:
Inherit the account lifecycle policy defined in
Administration
â
Privilege access management
â
Settings
â
Account lifecycle policy
.
Custom:
Defines a custom checkout policy or uses the checkout policies defined in
Administration
â
Privilege access management
â
Account lifecycle policies
.
JIT privilege elevation
SETTINGS
DESCRIPTION
Select provider privileges to make available for temporary elevation
Select the Active Directory groups of which a privileged account will be elevated to member status. Click on the pen icon next to a selected group to assign a Devolutions Hub Business display name to it.
Enable privilege sets
Create privilege sets to group similar privileges together by assigning provider privileges and privileged accounts.
Temporary group name prefix (max: 27 characters)
Prefix of the Active Directory group name to be created, which will be a member of the selected group and in which the privileged account will be a member.
Temporary group creation location
Location (OU) where the temporary Active Directory group will exist in the Active Directory structure.
Propagation latency
Some domains may require additional time to apply permissions. Introducing latency helps prevent sessions from opening too quickly, which could result in a failure.
Share your feedback

---

*Downloaded on: 2026-02-18 13:10:01*