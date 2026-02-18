# Zero standing privilege

**Source URL:** https://docs.devolutions.net/pam/concepts/zero-standing-privileges/

---

Zero standing privilege
(ZSP) is a security model where accounts are created with no permanent permissions or group memberships. In this model, access rights are granted only when required and revoked immediately after use. This minimizes the attack surface and limits what an attacker could do if the account is compromised.
In Devolutions PAM, ZSP accounts are designed to exist without any default privileges. When elevated access is needed, privileges are granted
just-in-time
for the duration of the task, then automatically removed. This dynamic approach protects sensitive systems while supporting operational needs.
ZSP is often compared to the principle of
least privilege
(PoLP), which restricts users to the minimum permissions necessary to perform their tasks. The key difference is that the PoLP maintains a continuous, minimal level of access, while ZSP eliminates all standing access until explicitly required. ZSP offers greater security for high-risk environments by reducing exposure time to privileged credentials.
Zero standing privilege aliases
ZSP
No standing privilege
See also
Glossary of Common Privileged Access Management (PAM) Terms
Need Cybersecurity Insurance? Then You Probably Need PAM, Too
Share your feedback

---

*Downloaded on: 2026-02-18 13:08:50*