# Quickly deploy AD PAM in your environment

**Source URL:** https://docs.devolutions.net/pam/kb/how-to-articles/quickly_deploy_ad_pam_in_your_environment/

---

This guide walks you through the steps to set up Devolutions PAM in your environment quickly, so you can protect privileged accounts, enforce policies, and gain control over sensitive access with minimal configuration time.
Devolutions Server (self-hosted)
Configure a
PAM Domain service account
.
The PAM Domain service account will be required at a later stage. Make sure to keep the username and password handy.
An optional step is to create a test account for PAM.
Make sure the
Scheduler service
is running.
Configure your
PAM domain provider
in Devolutions Server by going to
Administration
â
Privileged access
â
Providers
.
Click the plus sign in the top right to add a new provider.
Select
Domain user
and continue.
Enter the required configuration and specify the Domain service account created in step 1. Click
Save
.
Set up the account discovery configuration (prompted when saving the PAM provider).
Select the OUs where the privileged account (or test account) is located.
Check
Start scan on save
under
Actions.
Click
Save.
Open the providerâs properties and navigate to the
Checkout policy
tab.
Create a
check-out policy
and a
PAM
vault
.
Import accounts
from the
Scan
.
Here is the risk level associated with each account discovered during a scan.
Group name
Privilege tier
Description
Domain admins
Tier 0
Full control over domain resources.
Enterprise admins
Tier 0
Full control over forest-wide configuration.
Schema admins
Tier 0
Can modify the AD schema.
Administrators
Tier 0
Built-in administrators on all domain controllers.
Account operators
Tier 1
Can manage user/group accounts. Risk of privilege escalation.
Server operators
Tier 1
Can log on locally to DCs and manage services.
Backup operators
Tier 1
Can back up protected system files; often overlooked.
Group policy creator owners
Tier 1
Can create/edit GPOs âcan introduce persistence.
DNS admins
Tier 1
Can control DNS zones âpotential for domain spoofing.
Configure an entry
to use the PAM account.
Devolutions Hub Business (Cloud)
Configure a
PAM Domain service account
.
The PAM Domain service account will be required at a later stage. Make sure to keep the username and password handy.
An optional step is to create a test account for PAM.
Install the
PAM service
.
Configure your
PAM domain provider
in Devolutions Hub Business by going to
Administration
â
Privileged access
â
Providers
.
Click the plus sign in the top right to add a new provider.
Select
Domain user
and continue.
Enter the required configuration and specify the Domain service account created in step 1. Click
Save
.
Open the providerâs properties and navigate to the
Checkout policy
tab.
Create a
check-out policy
and a PAM vault by clicking
Add vault
.
Add vault
Configure an entry
to use the PAM account.
Run the
Account discovery
next to the provider.
Account discovery
Select the OUs where the privileged account (or test account) is located.
Here is the risk level associated with each account discovered during an
Account discovery
.
Group name
Privilege tier
Description
Domain admins
Tier 0
Full control over domain resources.
Enterprise admins
Tier 0
Full control over forest-wide configuration.
Schema admins
Tier 0
Can modify the AD schema.
Administrators
Tier 0
Built-in administrators on all domain controllers.
Account operators
Tier 1
Can manage user/group accounts. Risk of privilege escalation.
Server operators
Tier 1
Can log on locally to DCs and manage services.
Backup operators
Tier 1
Can back up protected system files; often overlooked.
Group policy creator owners
Tier 1
Can create/edit GPOs âcan introduce persistence.
DNS admins
Tier 1
Can control DNS zones âpotential for domain spoofing.
After selecting the destination, security, and password settings, click
Import
.
Read
Enable Just-in-Time elevation and provisioning
to grant temporary privileged access on demand.
See also
Devolutions Academy â Devolutions PAM
Share your feedback

---

*Downloaded on: 2026-02-18 13:10:47*