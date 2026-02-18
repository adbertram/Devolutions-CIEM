# Action script

**Source URL:** https://docs.devolutions.net/pam/concepts/action-script/

---

An
action script
is how a custom PAM provider implements its actions in Devolutions PAM. These scripts are user-defined PowerShell files that perform tasks such as password discovery, comparison, and rotation. When a
password rotation
is triggered, Devolutions PAM acts as a coordinator and executes the corresponding action script to complete the task.
While managed providers have their actions natively developed and fully integrated within Devolutions PAM, custom PAM providers give organizations the flexibility to integrate with virtually any system that supports script-based interactions. This allows secure automation of privileged account management without waiting for native support.
Action scripts are only available during the creation of
custom PAM provider templates
. Once created, action scripts are no longer visible when managing custom PAM providers.
Related topics
Custom PAM providers (Devolutions Server)
Troubleshooting action scripts in (Devolutions Server)
See also
Providers (Devolutions Server)
Managed providers (Devolutions Server)
Custom PAM providers (Devolutions Server)
Share your feedback

---

*Downloaded on: 2026-02-18 13:08:16*