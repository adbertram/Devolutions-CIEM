# Least privilege

**Source URL:** https://docs.devolutions.net/pam/concepts/least-privilege/

---

The principle of
least privilege
(PoLP) is a foundational security concept requiring that users, applications, and systems be granted only the minimum access necessary to perform their duties. This limits the potential impact of compromised accounts or software vulnerabilities, helping organizations control risk exposure and protect sensitive resources.
In practice, least privilege can be enhanced with
just-in-time (JIT) elevation
, which provides temporary, time-bound access to
privileged accounts
or systems only when needed. This reduces standing privileges and simplifies auditing.
Least privilege differs from
zero-standing privilege (ZSP)
, which seeks to eliminate all persistent privileged access entirely, relying solely on JIT access. While both approaches reduce exposure, least privilege often includes static but limited access rights, whereas ZSP aims for a complete absence of baseline privileges.
Devolutions PAM supports least privilege by allowing role-based access controls, session approvals, and time-limited credential use, aligning with best practices for secure access.
Least privilege aliases
PoLP
Principle of least privilege
Minimal access rights
Related topics
Permissions/RBAC/Roles
External PAM integrations
Least privileges for Active Directory
See also
Zero standing privilege
Share your feedback

---

*Downloaded on: 2026-02-18 13:08:32*