# Entra ID user provider

**Source URL:** https://docs.devolutions.net/pam/server/providers/managed-providers/azure-ad-user-provider/

---

The
Entra ID user
provider allows Devolutions Server to store the Entra ID application information to be used for account discovery or to achieve password rotation.
See
Create an Entra ID PAM provider
for more information about the configuration in Azure.
Entra ID user provider
General
OPTIONS
DESCRIPTION
Name
Display name of the provider.
Description
Custom description of the provider.
Server
OPTIONS
DESCRIPTION
Tenant ID
ID of the Azure tenant.
Client ID
ID of the Azure application.
Credentials
OPTIONS
DESCRIPTION
Credential type
Choose a credential type between:
Custom
: manually enter the Azure applicationâs secret key.
Linked credential
: retrieve credentials from an existing privileged account.
Secret key
Secret key of the Azure application.
Linked credential
Choose a privileged account from which to retrieve credentials. This option is only displayed when the
Credential type
is set to
Linked credential
.
Actions
OPTIONS
DESCRIPTION
Add a PAM vault
Automatically create a PAM vault for the new provider.
Add a new account discovery configuration
Opens the
Add new account discovery configuration
window once the provider is created with the providerâs information already filled in.
See also
Devolutions Academy - Configuring an Active Directory Provider
Devolutions Academy - Configuring an Entra ID Provider
Share your feedback

---

*Downloaded on: 2026-02-18 13:09:26*