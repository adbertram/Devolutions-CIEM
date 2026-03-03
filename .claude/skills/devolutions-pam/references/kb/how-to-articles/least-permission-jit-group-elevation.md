# Least privileges for Active Directory provider

**Source URL:** https://docs.devolutions.net/pam/kb/how-to-articles/least-permission-jit-group-elevation/

---

Devolutions Server allows
just-in-time (JIT) group elevation
and
password rotation
by using an Active Directory account as a PAM provider. Read the instructions below to learn how to delegate control to said PAM provider in the Active Directory Users and Computers (ADUC) console.
To manage domain administrator accounts as privileged accounts in the PAM module, you must grant the PAM AD provider account access to the
AdminSDHolder
object. For detailed steps, see
Creating Management Accounts for Protected Accounts and Groups in Active Directory
.
JIT group elevation
Open the Active Directory Users and Computers (ADUC) console.
Right-click on the organizational unit (OU) containing the groups for the privileged accounts (or on a higher OU level to encompass all OUs in which the PAM provider account should have the ability to change group memberships), and select
Delegate Control...
Make sure to repeat this steps for the OU in which the temporary groups are created.
Delegate Control
In the Delegation of Control Wizard, click on
Next
to reach the
Users or Groups
dialog. Click on
Add
or select the account to use as the PAM provider account in Devolutions Server.
Add an account
Enter the object name to select, then click on
Check Names
. Click
OK
to confirm.
Enter the object name to select
Click
Next
.
Selected user
In
Tasks to Delegate
, select
Create a custom task to delegate
, then click
Next
.
Create a custom task to delegate
In
Active Directory Object Type
, select
Only the following objects in the folder
, then check the
Group objects
item. Then, tick both
Create selected objects in this folder
and
Delete selected objects in this folder
checkboxes, and click on
Next
.
Object type
In
Permissions
, only tick the
Property-specific
checkbox. Find and enable the
Write Members
permission, then click on
Next
.
Select permissions
Verify that the correct permission has been delegated, then click
Finish
to complete the process.
End of process
Password rotation
Open the Active Directory Users and Computers (ADUC) console.
Right-click on the organizational unit (OU) containing the privileged accounts (or on a higher OU level to encompass all OUs in which the PAM provider account should have the ability to rotate account passwords), and select
Delegate Control...
Delegate Control
In the Delegation of Control Wizard, click on
Next
to reach the
Users or Groups
dialog. Click on
Add
or select the account to use as the PAM provider account in Devolutions Server.
Add an account
Enter the object name to select, then click on
Check Names
. Click
OK
to confirm.
Enter the object name to select
Click
Next
.
Selected user
In
Tasks to Delegate
, select
Create a custom task to delegate
, then click
Next
.
Create a custom task to delegate
In
Active Directory Object Type
, select
Only the following objects in the folder
, then check the
User objects
item. Then, tick both
Create selected objects in this folder
and
Delete selected objects in this folder
checkboxes, and click on
Next
.
Object type
In
Permissions
, tick both the
General
and
Property-specific
checkboxes. Find and enable the following permissions, then click on
Next
.
Change password
Reset password
Read lockout Time
Write lockout Time
Read pwdLastSet
Write PwdLastSet
Read userAccountControl
Write userAccountControl
Select permissions
Verify that the correct permissions have been delegated, then click
Finish
to complete the process.
End of process
The password rotation feature uses the default built-in Devolutions Server password rules. To enforce domain-specific password rules, create a custom password policy under
Administration â Password policies
, then set it as the default password template in
Administration
â
System settings
â
Password management
â
Password policies
.
Share your feedback

---

*Downloaded on: 2026-02-18 13:10:44*