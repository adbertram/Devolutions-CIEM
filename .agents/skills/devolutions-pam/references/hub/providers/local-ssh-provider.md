# Local SSH user provider

**Source URL:** https://docs.devolutions.net/pam/hub/providers/local-ssh-provider/

---

The
Local SSH user
provider allows Devolutions Hub Business to store the SSH local account credentials to be used for SSH accounts discovery or to achieve password rotation.
Local SSH user provider
General
SETTINGS
DESCRIPTION
Name
Display name of the provider.
Description
Optional description of the provider.
Host
IP address or host name where the SSH accounts are located.
Port
Set the port number used to communicate with the host.
Timeout (sec)
Set a timeout for communication with the host.
Use Devolutions Gateway
Choose a Devolutions Devolutions Gateway from your list. Requires Devolutions Gateway to be
installed and configured
beforehand.
Username
Username of the SSH account.
Password
Password of the SSH account.
Test connection
Ping to verify whether the connection works or not.
Checkout policy
SETTINGS
DESCRIPTION
Checkout policy mode
Choose a checkout policy mode between:
Default (inherited)
Inherited
Custom
Checkout mode
Choose whether checkouts are obligatory or not. This amounts to turning the checkouts on/off.
Approval mode
Determine if checkouts require approval or not.
Users can approve their own checkout
Determine if users can approve their own checkout request or whether they need the approval of an administrator.
Checkout reason
Force users to add a reason in checkout requests.
Checkout time (minutes)
Set the precise checkout time for all users, in minutes.
Max checkout time (minutes)
Set the maximum checkout time, but leave it to the users to specify their needs for each request.
Account lifecycle policy
SETTINGS
DESCRIPTION
Password policy
Choose a
password policy
previously configured in
Administration
â
Password policies
.
Synchronization schedule
Set a date and time for automatic synchronization between the provider and its user/user groups.
Share your feedback

---

*Downloaded on: 2026-02-18 13:10:02*