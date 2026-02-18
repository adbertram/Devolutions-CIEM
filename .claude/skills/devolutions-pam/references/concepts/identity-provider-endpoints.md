# Identity provider endpoints

**Source URL:** https://docs.devolutions.net/pam/concepts/identity-provider-endpoints/

---

Identity provider (IdP) endpoints
define the specific connection point used by a provider to authenticate with an
identity provider
. This could be a DNS name for an Active Directory domain controller, an IP address for a Linux system, or a URL for a REST API, for example.
In Devolutions PAM, managed providers already have their identity provider endpoints pre-integrated. However, when using custom PAM providers, these endpoints must be explicitly configured. This typically happens within
action scripts
, ensuring the provider knows where and how to authenticate.
This distinction is crucial for flexible integrations, especially in hybrid environments or when working with custom identity systems. Properly configuring identity provider endpoints ensures secure and seamless authentication flows.
Identity provider endpoints aliases
IdP endpoints
Related topics
Create a custom PAM provider action script in Devolutions Server
Identity provider endpoint script parameters
Test action scripts outside of custom PAM providers
See also
Custom PAM providers
Create a custom PAM provider in Devolutions Server
Import a custom PAM provider
Share your feedback

---

*Downloaded on: 2026-02-18 13:08:28*