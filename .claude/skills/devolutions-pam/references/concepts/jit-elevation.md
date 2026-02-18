# Just-in-time elevation

**Source URL:** https://docs.devolutions.net/pam/concepts/jit-elevation/

---

Just-in-time (JIT) elevation
in Devolutions PAM temporarily grants elevated privileges to user accounts only when needed, reducing the risk of standing permissions that can be exploited. This approach supports both standard and
zero-standing privilege (ZSP)
accounts.
For
standard accounts
, JIT elevation adds group memberships or roles at
check-out
, and removes them upon
check-in
. This means the account retains its base permissions but temporarily gains additional access during the session.
For
ZSP accounts
, which have no group memberships or privileges at rest, JIT elevation dynamically assigns the required access at
check-out
and ensures it is fully revoked upon
check-in
. Security teams can monitor ZSP accounts to verify they remain empty between uses, helping maintain strict control and audit readiness.
By implementing JIT elevation, Devolutions PAM helps organizations improve security, enforce
least-privilege
, and limit exposure time for sensitive access.
Just-in-time (JIT) elevation aliases
JIT (privilege) elevation
Temporary privilege elevation
On-demand elevation (CyberArk)
Related topics
Just-in-time (JIT) elevation in Devolutions Server
See also
Decoding just-in-time (JIT) elevation
Devolutions Academy â Demystifying just-in-time elevation and provisioning with Devolutions PAM
Glossary of Common Privileged Access Management (PAM) Terms
JIT privilege elevation made efficient by Devolutions
Need Cybersecurity Insurance? Then You Probably Need PAM, Too
Share your feedback

---

*Downloaded on: 2026-02-18 13:08:30*