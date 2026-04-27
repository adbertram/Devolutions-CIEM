# Propagation

**Source URL:** https://docs.devolutions.net/pam/concepts/propagation/

---

Propagation
is a customizable final action in a Devolutions PAM provider that executes after
password rotation
. It is implemented as an optional
PowerShell script
, allowing administrators to automate specific follow-up tasks required after a credential has been changed.
This flexibility helps address scenarios where updated credentials need to be pushed to external systems or software. For instance, propagation can update stored passwords in
Windows services
, scheduled tasks, or synchronize secrets with platforms like
Azure Key Vault as secrets
. It can also be used for notification or
compliance
purposes by triggering helpdesk tickets or sending alerts through services such as
Slack
or
Microsoft Teams
.
By supporting propagation, Devolutions PAM enhances post-rotation workflows, ensuring systems remain in sync and operations continue without disruption.
Propagation aliases
Password propagation
Propagation scripts
Related topics
Propagation scripts (Devolutions Server)
Import propagation template (Devolutions Server)
See also
Create script template (Devolutions Server)
Providers (Devolutions Server)
Share your feedback

---

*Downloaded on: 2026-02-18 13:08:41*