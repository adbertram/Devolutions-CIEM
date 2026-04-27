# Configure PAM provider to rotate its own password

**Source URL:** https://docs.devolutions.net/pam/kb/how-to-articles/configure-pam-provider-password-rotation/

---

Privileged users can rotate a PAM provider passwordâeither manually or on a scheduleâin a few simple steps.
This feature works with every PAM provider, except for Entra ID, as it is an APP registration.
Steps
Configure a PAM provider
.
Enter the PAM provider's details
Create the provider as an entry in a PAM vault.
Create the PAM provider as an entry
Click on the entry's
check synchronization status
button to very if it is accessible.
Checking access
Head back to the PAM provider and click the
Edit
button. Under
Credentials
, set the
Credential type
to
Linked credentials
.
Linked credentials option
Click on the
Linked credentials
field, and select the PAM entry created during step #2 in the
Privileged account
window. Click on
Ok
, then
Save
the PAM provider settings.
Linking provider credentials to the entry
The PAM provider password can then be rotated manually via the entry's
Reset password
button, or on a schedule by setting a password rotation schedule in the entry's
Properties
â
Password rotation schedule
.
Manual PAM provider password rotation
Scheduled PAM provider password rotation
See also
Devolutions Academy - Configuring an Active Directory Provider
Devolutions Academy - Configuring an Entra ID Provider
Share your feedback

---

*Downloaded on: 2026-02-18 13:10:36*