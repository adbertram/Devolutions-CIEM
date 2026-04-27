# Windows local accounts

**Source URL:** https://docs.devolutions.net/pam/server/providers/anyidentity-providers/windows-local-account/

---

The
Windows local accounts
provider enables the management of local Windows accounts across multiple hosts. While the
Windows account
provider already exists within Devolutions Server, it is limited to managing accounts on a single host. This custom PAM provider extends that capability.
Windows local accounts provider configuration
The pre-built template for this custom PAM provider can be found
on GitHub
.
General
Option
Description
Name
Display name of the Provider.
Template name
Template of the Provider.
Properties
Option
Description
Description
Description of the provider.
Host
IP Address or host name where the Windows local accounts are located.
ExcludeDisabledAccountsInDiscovery
Exclude disabled accounts when in discovery mode.
HostsLDAPSearchFilter
Add LDAP search filter(s).
Credentials
Option
Description
Credential type
Custom credentials or Linked credential options.
Username
Username of the Windows local account with rights to list accounts.
Password
Password of the Windows local account.
Linked credential
Credential directly linked to a PAM account.
Actions
Option
Description
Add PAM vault
Will create a PAM vault with the provider's name if enabled.
Add a new account discovery configuration
Will open the Account discovery configuration dialog if enabled.
Share your feedback

---

*Downloaded on: 2026-02-18 13:09:23*