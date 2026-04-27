# Create a custom PAM provider from a template

**Source URL:** https://docs.devolutions.net/pam/server/getting-started/anyidentity/import-anyidentity-pam-provider/

---

Create a custom PAM provider from a template by following the steps below.
To create the provider, first navigate to
Administration â Privileged access
in Devolutions Server and select
Providers
.
Click on the + sign to add a provider.
Select Custom and then choose your template. An existing provider template named
Windows Local Accounts
is displayed here.
Define a name and provide values for all of the provider properties.
Custom PAM providers are designed for connecting to a single identity provider endpoint. It is generally recommended to create one custom PAM provider per identity provider.
After providing values for all of the provider properties, there is an option to
add a PAM vault
for the provider or to add an account discovery configuration. By default,
Add PAM vault
is selected. See
account discovery configuration
to learn about adding an account discovery configuration.
Add PAM vault
On this page, a credential can also be specified to run all actions under, or a specific Windows host can be designated to execute the actions.
Credential and Windows host
By default, a custom PAM provider executes all actions on Devolutions Server under the
NETWORK SERVICE
user account. If a username and password are specified under
Run as
, custom PAM providers will first attempt to authenticate to the Devolutions Server using that user account and execute all action scripts under that account. If a
Host name
is specified, the custom PAM provider assumes a remote Windows host and will attempt to run all action scripts locally on that host via
PowerShell remoting
.
Finally, under
Settings
, a custom
password policy
can be provided, if necessary. All available custom password policies can be found under
Administration
â
Password policies
. When the password rotation action runs, it will use the password policy defined here to generate a new password.
Password template
See also
Devolutions Academy - Configuring a custom PAM provider
Share your feedback

---

*Downloaded on: 2026-02-18 13:09:06*