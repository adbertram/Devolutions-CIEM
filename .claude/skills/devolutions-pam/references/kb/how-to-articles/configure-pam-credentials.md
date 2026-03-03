# Configure Devolutions Server PAM in Remote Desktop Manager

**Source URL:** https://docs.devolutions.net/pam/kb/how-to-articles/configure-pam-credentials/

---

This topic covers multiple ways to configure and use the Devolutions Server PAM feature in Remote Desktop Manager.
Another alternative would be to use the
PAM dashboard
and launch sessions from it.
Steps
Go to
Properties
â
Common
â
General
â
Credentials
and select
Privileged account
from the dropdown.
Click on the ellipsis button and select an account configured in the PAM module.
Multiple Users
If every user has a privileged account they want to use, here are the steps:
Under
Properties
â
Common
â
General
, set the option in the
Credentials
dropdown to
My privileged account
.
Then those users need to set the desired PAM account under
File
â
My Account Settings
â
My Defaults
â
My Privileged Account
.
Select the
DVLS Privileged Account
option under
Privileged Access Management
.
Input the Devolutions Server URL,
Username
and select the PAM account.
It is also possible to check the
Always prompt with list option
to select which account to login with every time.
Share your feedback

---

*Downloaded on: 2026-02-18 13:10:35*