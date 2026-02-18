# Entra ID user provider

**Source URL:** https://docs.devolutions.net/pam/hub/providers/azure-ad-user-provider/

---

The Entra ID user provider allows Devolutions Hub Business to store the Entra ID application information to be used for Entra ID automatic password rotation.
Entra ID user provider
General
Option
Description
Name
Display name of the provider.
Description
Description of the provider.
Tenant ID
ID of the Azure tenant.
Client ID
ID of the Azure application.
Secret key
Secret key of the Azure application.
Test connection
Test the connection. If the connection fails, check the validity of the information you have entered and try again.
Checkout policy
Option
Description
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
Checkout policy
.
Custom:
Defines a custom checkout policy or uses the checkout policies defined in
Administration
â
Privilege access management
â
Checkout policies.
Account lifecycle policy mode
Option
Description
Account lifecycle policy mode
Choose a
checkout policy mode
:
Default (inherited)
Inherited:
Inherit the
account lifecycle policy
defined in
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
Option
Description
Select provider privileges to make available for temporary elevation
Select the Active Directory groups of which a privileged account will be elevated to member status. Click on the pen icon next to a selected group to assign a Devolutions Hub Business display name to it.
Enable privilege sets
Create privilege sets to group similar privileges together by assigning provider privileges and privileged accounts.
See also
Devolutions Academy - Understanding the PAM Provider
Share your feedback

---

*Downloaded on: 2026-02-18 13:09:59*