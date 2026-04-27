# Modify PAM usage policies

**Source URL:** https://docs.devolutions.net/pam/server/pam-usage-policies/

---

PAM
Usage Policies
determine which applications and entry types are available to users when working with PAM accounts, thus providing more control over user activity by restricting access to unessential or even unwanted features.
Making changes in these settings affects the entire Devolutions Server.
You can define usage policies by heading to
Administration
â
Privileged access
â
Usage policies
in Devolutions Server's web interface. There, applications and entry types can be toggled on and off, and entries can be controlled at an even more granular level by disabling specific types, e.g.,
Telnet
,
SFTP
,
VMRC
, etc.
Determine what apps and entry types are supported in Devolutions Server's web interface
Remember to validate that PAM accounts are working properly and features are disabled based on your choice. Also, make sure connections saved with PAM credentials are blocked at runtime before disabling a specific connection type.
Share your feedback

---

*Downloaded on: 2026-02-18 13:09:12*