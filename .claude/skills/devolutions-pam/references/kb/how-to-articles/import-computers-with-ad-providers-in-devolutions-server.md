# Import computers from Domain user providers in Devolutions Server

**Source URL:** https://docs.devolutions.net/pam/kb/how-to-articles/import-computers-with-ad-providers-in-devolutions-server/

---

Administrators can import machines into their Privileged Access Management (PAM) vaults using Active Directory providers and
Account discovery configurations
features.
To import machines into PAM vaults, a
domain provider
must first be configured
Administration
â
Pirivileged access
â
Providers
.
Here are the required steps:
Head over to
Administration
â
Privileged access
â
Account discovery configurations
.
Account discovery configurations
Either
Add a new account discovery configuration
or
Edit
and existing one, provided it is scanning a
Domain user provider
.
In the
Account discovery configuration
window, check the
Include computers in scan
box and click the
Browse domain containers
button.
Include computers in scan
Check the
Computers
container and click on
Select
.
Containers list
Click
Ok
and press the
Start
button to launch the newly created/edited account discovery configuration.
Lauching a new scan
Click either on the
View result
button or on the number shown in the
Results
column. Then, check the box next to the comuters you wish to import and click on the
Import selected computers
button.
Computer selection
Choose the PAM vault in which to import the computers and click
Ok
.
Set PAM vault
The machines should be added to the PAM vault in the form of entries.
Share your feedback

---

*Downloaded on: 2026-02-18 13:10:43*