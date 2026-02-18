# Action property

**Source URL:** https://docs.devolutions.net/pam/concepts/action-property/

---

An
action property
is a parameter assigned to an action that passes specific data needed to complete it. In Devolutions PAM, action properties are critical for securely managing and automating tasks such as
password rotation
and
account discovery
. Each action includes a set of properties (some required, some optional) grouped into two categories: provider properties and account properties.
Provider properties are used once per session to connect to an
identity provider
, typically using administrative credentials. For example, Devolutions PAM may use a provider property like a username and password to authenticate to the identity provider before managing accounts.
Account properties are tied to individual user accounts on the identity provider. These include values like account username, password, or unique identifiers that let Devolutions PAM perform specific actions, such as rotating a password for that particular account.
Together, action properties streamline
privileged task automation
by ensuring the right data is securely supplied to each action.
Action property aliases
Action parameter
See also
Providers (Devolutions Server)
Providers (Devolutions Hub Business)
Password rotation (Devolutions Server)
Password rotation policies (Devolutions Hub Business)
Share your feedback

---

*Downloaded on: 2026-02-18 13:08:15*