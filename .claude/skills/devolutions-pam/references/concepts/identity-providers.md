# Identity provider

**Source URL:** https://docs.devolutions.net/pam/concepts/identity-providers/

---

An
identity provider
(IdP) is an external service that stores and manages user identities and credentials. Devolutions PAM interacts with these providers to perform identity-related actions such as
password rotations
, account validations, and session authorizations. Identity providers are never internal to Devolutions PAM; they serve as external sources that the platform accesses through configured providers.
Common identity providers include
Microsoft Active Directory
,
MySQL databases
,
Windows operating systems
, and
Linux operating systems
. Each of these systems handles the core functions of
authentication, authorization, and accounting (AAA)
, which are foundational for managing access securely.
Within Devolutions PAM, identity providers are essential to executing privileged tasks on managed accounts. Administrators can automate interactions with these external sources using actions, helping to streamline credential management while maintaining strict control and auditability.
Identity provider aliases
IdP
authentication provider
Identity as a service (IDaaS) provider
Related topics
Providers (Devolutions Server)
Providers (Devolutions Hub Business)
See also
Create an Entra ID PAM provider (Devolutions Hub Business)
Create an Entra ID PAM provider (Devolutions Server)
Create Windows users provider (Devolutions Server)
Glossary of Common Privileged Access Management (PAM) Terms
Need Cybersecurity Insurance? Then You Probably Need PAM, Too
Share your feedback

---

*Downloaded on: 2026-02-18 13:08:29*