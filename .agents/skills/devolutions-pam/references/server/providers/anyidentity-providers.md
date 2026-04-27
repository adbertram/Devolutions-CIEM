# Custom PAM providers

**Source URL:** https://docs.devolutions.net/pam/server/providers/anyidentity-providers/

---

Devolutions PAM offers a variety of managed providers, but it is not feasible to support every identity provider. This is where custom PAM providers (formerly
AnyIdentity providers
) become essential.
Custom PAM providers are an extension of managed providers, designed to bridge the gap between the identity providers natively supported by the Devolutions PAM module through managed providers and the numerous other identity providers that Devolutions customers may be using.
A custom PAM provider can support various identity providers not natively supported by Devolutions PAM, such as:
Cloud-based identity providers
: Providers like Okta or Google Workspace, which manage access to cloud applications and services.
Custom applications
: Any in-house system your organization has developed that maintains its own user database and authentication mechanisms.
Legacy systems
: Older applications or databases that may not easily integrate with modern identity management solutions.
Custom PAM providers utilize various actions, written in PowerShell as action scripts, which are executed either on-demand or on a scheduled basis via account discovery configurations. These actions include discovering identity provider credentials, detecting credential changes, and rotating passwords for credentials.
Account discovery
: Enumerates credentials on an identity provider.
Heartbeat
: Detects whether a credential has changed since the last heartbeat.
Password rotation
: Changes account passwords to a new, secure password
If you are proficient in PowerShell, you can
create custom PAM providers
or utilize any of the
pre-built templates
.
Custom PAM provider
See also
YouTube - Devolutions PAM playlist
Devolutions Academy - Configuring a custom PAM provider
Devolutions Blog:
Inside the custom PAM provider workflow: account discovery
Inside the custom PAM provider workflow: heartbeat
Inside the custom PAM provider workflow: password rotation
Inside the custom PAM provider workflow: password propagation
Decoding custom PAM providers: customizable identity management for the modern enterprise
Spotlight on remote PAM with custom PAM providers and Devolutions Gateway
Share your feedback

---

*Downloaded on: 2026-02-18 13:09:20*