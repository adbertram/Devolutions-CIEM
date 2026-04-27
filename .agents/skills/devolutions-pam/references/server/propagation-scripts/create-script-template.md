# Create script template

**Source URL:** https://docs.devolutions.net/pam/server/propagation-scripts/create-script-template/

---

Although Devolutions propose a wide variety of PowerShell script templates, administrators can make custom ones. Here are the steps to do it:
Log in to Devolutions Server with an administrator account.
Go to
Administration
â
Modules
â
Privileged access
â
Propagation
.
Click on
Script templates
.
Click on
Add
.
In the
General
tab, add a
Name
for this template.
It is possible to add a
Description
. The icon can also be changed by clicking on it.
In the
Propagation properties
tab, add the variables for the script by clicking on
+ Add property
. The variables added in this tab should represent the URL to the remote machine (i.e., ComputerIP, Username, Password and RootFolder).
In the
Property mapping
tab, add the variables for the script by clicking on
+ Add property
. The variables added in this tab should represent the
Field mapping
of the remote machine (i.e., FileName and FilePath).
In the
Script
tab, the previous variables appear as well as the
NewPassword
variable. This new variable will contain the new password for the account on script execution.
Click on
Generate base script
.
Click on
Edit
to modify or add to the script.
Click
Save
to save this configuration and close the window.
Learn more about custom scripts for this feature by visiting our
public GitHub
.
See also
Spotlight on password propagation: Keeping all passwords in sync across systems
Share your feedback

---

*Downloaded on: 2026-02-18 13:09:15*