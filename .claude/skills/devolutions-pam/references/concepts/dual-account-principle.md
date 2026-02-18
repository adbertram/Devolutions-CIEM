# Dual account principle

**Source URL:** https://docs.devolutions.net/pam/concepts/dual-account-principle/

---

The
dual account principle
in Devolutions PAM is a best practice that enhances security by requiring privileged users to operate with two distinct
privileged accounts
. One is a
low privileged account
for routine tasks such as reading emails and browsing the web. The other is a
high privileged account
used strictly for administrative actions, like modifying system settings or accessing sensitive resources on the infrastructure.
This separation reduces the risk of compromise by limiting the exposure of elevated privileges during everyday use. If malware or phishing compromises the low privileged account, the attacker cannot immediately access critical infrastructure.
In Devolutions PAM, this principle is enforced by assigning specific roles and permissions to each account type. Automated workflows and access controls can ensure that elevated credentials are only used when necessary, helping to maintain operational security and
compliance
.
Dual account principle aliases
Dual identity principle
High privilege accounts
Administrator account
Dash account
Related topics
Roles and permissions (PAM) in Devolutions Server
See also
Glossary of Common Privileged Access Management (PAM) Terms
Need Cybersecurity Insurance? Then You Probably Need PAM, Too
Devolutions Academy â Make use of the dual account principal
Share your feedback

---

*Downloaded on: 2026-02-18 13:08:27*