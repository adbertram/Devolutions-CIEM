# JIT elevation not revoking privileges for users

**Source URL:** https://docs.devolutions.net/pam/kb/troubleshooting-articles/jit-elevation-error/

---

In version 2023.3, privileges obtained through JIT elevation using an Entra ID (Azure) provider were not correctly revoked after elevation.
If the PAM check-in was done automatically by the scheduler (e.g., when the timer of a checkout was elapsed) it is possible the user is still part of the group it was originally elevated as.
Solution
Log in with an administrator account in the web interface for Devolutions Server.
Go to
Administration
â
Privileged Access
â
Providers
.
Click the
Settings
button on the Entra ID (Azure) provider.
Go to the Settings tab and review the groups in the
Just-In-Time (JIT) elevation
section.
In Microsoft Azure go to
Azure
â
Microsoft Entra ID
â
Groups
.
Review the desired group to make certain the user accounts used during the JIT elevation process are no longer part of the group(s).
Share your feedback

---

*Downloaded on: 2026-02-18 13:10:51*