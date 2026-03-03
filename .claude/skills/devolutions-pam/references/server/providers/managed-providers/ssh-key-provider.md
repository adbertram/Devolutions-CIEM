# SSH key provider

**Source URL:** https://docs.devolutions.net/pam/server/providers/managed-providers/ssh-key-provider/

---

SSH key managed providers are used to securely store SSH keys, which can then be used for account discovery or to achieve password rotation. These SSH keys can be accessed by Remote Desktop Manager for various SSH entries and sessions.
SSH key provider
General
OPTION
DESCRIPTION
Â
Name
Â Display name of the provider.
Â
Description
Â Optional description of the provider.
Host
OPTION
DESCRIPTION
Â
Host
IP address or hostname where SSH key is located.
Â
Port
Set the port number used to communicate with the host.
Â
Timeout (sec)
Set a timeout for communication with the host.
Credentials
OPTION
DESCRIPTION
Â
Credential type
Custom credential
or
Linked credential
option.
Â
Username
Â Username of the SSH key account.
Â
Password
Â Password of the SSH key account.
See also
Devolutions Academy â Centralize SSH key rotation with Devolutions PAM
Share your feedback

---

*Downloaded on: 2026-02-18 13:09:31*