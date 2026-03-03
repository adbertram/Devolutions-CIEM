# Create temporary accounts with JIT Provisioning

**Source URL:** https://docs.devolutions.net/pam/kb/how-to-articles/create-temporary-account-jit-provisioning/

---

Just-in-time (JIT) provisioning creates temporary accounts that are active only for the duration of a task or session. At checkout, the system generates an account with the necessary permissions, which is automatically removed upon check-in.
This guide explains how to configure JIT provisioning creation to create temporary accounts.
Configure JIT account creation
In
Administration
â
Privileged Access
â
Providers
, select your PAM Provider and click
Edit
.
Go to the
JIT privilege elevation
and locate
Advanced
.
Enter the path in the correct format for your Active Directory (e.g.,
OU=JITAccounts,DC=example,DC=com
) under
JIT Account creation location
.
Save your changes.
Add a new domain user PAM account
Go to your
PAM
Vault and
click
Add new entry
.
Select (
PAM)
â
Domain user
.
Fill in
Name
and
Username
.
Select your
Provider
in the
drop-down menu
.
Check the
Just-in-Time (JIT) account
checkbox.
Click
Add
to save the entry.
Understand the JIT process
When you check out the account, the system automatically creates it in Active Directory. It remains active for the duration of the checkout period, and upon check-in, the account is immediately deleted from Active Directory.
Share your feedback

---

*Downloaded on: 2026-02-18 13:10:41*