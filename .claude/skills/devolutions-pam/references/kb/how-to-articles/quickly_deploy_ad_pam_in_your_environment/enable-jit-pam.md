# Enable Just-in-Time elevation and provisioning

**Source URL:** https://docs.devolutions.net/pam/kb/how-to-articles/quickly_deploy_ad_pam_in_your_environment/enable-jit-pam/

---

After
deploying AD PAM in your environment
, you can enable Just-in-Time elevation and provisioning to grant temporary privileged access on demand.
Just-in-Time elevation
Add the
permission to create user groups
to your PAM domain provider account in AD.
Identify the user groups in AD you would like to be available for Just-in-Time elevation.
Back in Devolutions Server or Devolutions Hub Business, go to
Administration
â
Privileged access
â
Providers
, and click
Edit
on your PAM provider.
Select the
JIT privilege elevation
section on the left menu.
Select the user group identified earlier.
If you would like to limit the JIT access to specific accounts, click
Enable Privilege Sets
.
Add a prefix to the group name, such as
DVLS-JIT-
.
Select a location for the temporary groups to be created.
If you have multiple DC, configure a
Replication latency
to make sure the JIT has time to replicate between all DCs. Click
Save
.
Just-in-Time provisioning
Open the Active Directory User and Computers (ADUC) console, right-click on the organizational unit (OU) containing your PAM account, and select
Delegate Control...
.
Follow the wizard, and make sure to check the
Create, delete, and manage user accounts
permission during the task delegation step.
For least privileges purposes, you can
Create a custom task
to delegate
to add only the minimal permissions required to create users in AD.
Back in Devolutions Server or Devolutions Hub Business, go to
Administration
â
Privileged access
â
Providers
, and click
Edit
on your PAM provider.
Open the
JIT privilege elevation
tab, and select the user group identified earlier.
Choose a location for the temporary users to be created.
If you have multiple Domain controllers (DCs), configure
Replication latency
to give JIT changes enough time to replicate across all DCs, and click on
Save
.
In your
PAM
vault
, add a new domain user.
Enter the username for the account.
Check the
Just-In-Time (JIT) account
check box, and click
Save
.
Share your feedback

---

*Downloaded on: 2026-02-18 13:10:48*