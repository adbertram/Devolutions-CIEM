# Install Devolutions Hub Services to enable PAM and encryption integration

**Source URL:** https://docs.devolutions.net/pam/hub/pam-service/

---

The Devolutions Hub Services installer facilitates the installation and configuration of different features such as the Privileged Access Management module, the
Encryption Service (SSO-enabled feature)
and the
Hub Reporting service
. The installed service will establish communication between your Devolutions Hub Business and your internal resources.
Create an Application identity
In Devolutions Hub, click on
Administration
â
Application identities
.
Select
Add application identity (+)
.
Add a new application identity
Enter a name and click
Add
.
Copy the
Application secret
and
Application key
, and paste them somewhere safe. Alternatively, you can download them as a PDF file. These will be needed during Devolutions Hub Services installation later on.
Save the given Application secret and Application key
Edit permissions for application identities
In Devolutions Hub, Click
Administration
â
System permissions
.
Click the
Edit
icon (
+
).
Edit system permissions
In the
System
tab, give both
Manage privileged access tasks
and
Manage privileged access providers
permissions to your application identity created during step 1. Click on
Update
.
Add permissions to your application identity
You need to grant permission on the vault either at
System level
or
Individual PAM vault level
.
For all system vaults
In Devolutions Hub, go to
Administration
â
Configuration and security
â
System permissions
.
Click the
Edit
button.
Edit system permissions
Select
Vaults
and choose your
Application user
in the drop-down menu under the
Contributor
section.
Click
Update
to close the window.
For a specific PAM vault
In Devolutions Hub, go to
Administration â Management â Vaults
Click the
Add
button (
+
).
Add a new PAM vault
Select
PAM vault
in the menu to create your PAM vault.
Choose a vault content type
Go to the
Security
menu and select the
Edit
tab.
Choose your
Application user
in the drop-down menu under the
Contributor
section.
Add application user to Contributers
Click
Add
to close the window.
Installation of Devolutions Hub Services
Download Devolutions Hub Services
, and launch the installer.
After reading and accepting the
End-user license agreement
, check
PAM
from the
Custom setup
feature list.
Install the PAM feature
Enter your
Host
URL, as well as the
Application secret
and
Application key
you saved at the end of step 1. You can then test your connection to see if everything is working properly. Click on
Finish
.
Create an application service
To create an application service, go to
Administration
, then select
Application services
under
Configuration and security
.
Click on Application services
Click on the
Add (+)
button and select
PAM service
. Some information is needed, such as an
Application service
name
, a
Description
, and the
Application identity
.
Select PAM service
Check Devolutions Hub Services logs
Devolutions Hub Services' logs are available in
Windows Event Viewer
. The service should be able to connect to the created provider. The provider needs to be added in Devolutions Hub.
It is also possible to see the Devolutions Hub Services as a service in the Services window of Windows which shows the current status and where it can be started or stopped.
See also
Application services
Manage application identities
Quickly deploy AD PAM in your environment
Share your feedback

---

*Downloaded on: 2026-02-18 13:09:51*