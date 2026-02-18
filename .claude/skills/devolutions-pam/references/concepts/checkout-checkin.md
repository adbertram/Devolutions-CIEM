# Check-out/Check-in

**Source URL:** https://docs.devolutions.net/pam/concepts/checkout-checkin/

---

Check-out
and
check-in
are processes used to secure and manage
privileged accounts
.
Check-out
refers to reserving a privileged account for exclusive use, effectively locking it from access by others.
Check-in
releases this lock, typically followed by a
password rotation
to ensure account security. This mechanism ensures that credentials are not reused without oversight.
Check-in can occur manually, automatically at the end of the check-out period, or when a session is closed in Remote Desktop Manager, depending on user configuration. This provides flexibility while helping to enforce secure practices. With
just-in-time (JIT) access
, group or role memberships of privileged accounts are temporarily modified upon check-out and restored on check-in, limiting access to only what is needed during the session.
This functionality supports secure, time-bound access to sensitive resources, helping organizations control and monitor privileged usage, especially when combined with logging and session auditing features in Devolutions PAM and Devolutions Server.
Aliases
Account retrieval (CyberArk)
Privileged account reservation
Related topics
Approve access to a privileged account in Devolutions Hub Business
Request access to a privileged account in Devolutions Hub Business
Check-out requests report in Devolutions Hub Business
See also
Privileged accounts (Devolutions Server)
Privileged accounts (Devolutions Hub Business)
Devolutions Blog:
Spotlight on automatic privileged account check-in
Glossary of Common Privileged Access Management (PAM) Terms
Need Cybersecurity Insurance? Then You Probably Need PAM, Too
Share your feedback

---

*Downloaded on: 2026-02-18 13:08:22*