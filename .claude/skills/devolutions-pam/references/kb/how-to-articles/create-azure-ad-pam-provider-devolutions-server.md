# Create an Entra ID PAM provider (Devolutions Server)

**Source URL:** https://docs.devolutions.net/pam/kb/how-to-articles/create-azure-ad-pam-provider-devolutions-server/

---

The following guide provides steps to create an Entra ID user PAM provider for Devolutions Server.
In the Azure Portal
In a browser page, open the
Microsoft Azure Portal
and sign in to your account.
Select
Microsoft Entra ID
in the
Azure Services
section. If you do not see it, click on
More services
to make other services appear.
Microsoft Entra ID
In
App registrations
, click on
New registration
.
App registrations â New registration
Set the
Name
of your application.
Click
Register
at the bottom when done.
Set the Name and click Register
In Devolutions Server
Connect to your Devolutions Server.
Go to
Administration â Privileged Access â Providers
, then click on
Add
.
Administration â Privileged Access â Providers â Add
Select
Entra ID User
as the new PAM provider, then click
Continue
.
Add New PAM Provider â Entra ID User
In the
Provider
window, enter a
Name
(mandatory) and a
Description
(optional) for your new Entra ID user PAM Provider. If need be, select a
Password template
in the drop-down list.
Name, Description, and Password template
In the Azure Portal
In the
Overview
of your new app registration, copy the
Directory (tenant) ID
.
Copy the Directory (tenant) ID
In Devolutions Server
Paste the ID copied in the previous step in the
Tenant ID
field.
Tenant ID
In the Azure Portal
Still in the
Overview
of your new app registration, copy the
Application (client) ID
.
Copy the Application (client) ID
In Devolutions Server
Paste the ID copied in the previous step in the
Client ID
field.
Client ID
In the Azure Portal
In
Certificates & secrets
, click on
Client secrets
, then on
New client secret
.
New client secret
In the
Add a client secret
window, enter a
Description
and select an expiration date for this client secret, as per your best internal security practices.
Add a client secret
Click
Add
.
Copy the
Value
of this new client secret by clicking on the
Copy to clipboard
icon next to it.
Copy the Client Secret Value
In Devolutions Server
Paste the value copied in the previous step in the
Secret key
field.
Secret key
Test the connection to see if it works, then click
Save
. The
Account discovery configuration
window will appear: keep it open as it will be filled in a later step.
In the Azure Portal
Assigning API permissions as described in steps 20 to 26 is only useful if you want to perform Azure accounts discovery (scan). If this is not the case, to avoid assigning unnecessary permissions to the application, skip to step 27.
In
API permissions
, click
Add a permission
.
API permissions â Add a permission
In the
Resquest API permissions
window, select
Microsoft Graph
.
Microsoft Graph
Click
Application permissions
, then check the boxes next to the following Microsoft Graph API permissions to select them:
Group.Read.All
RoleManagement.Readwrite.Directory
User.Read.All
Select API permissions
Use the filter bar above the permissions list to find the ones you are looking for.
When all the above permissions have been selected, click
Add permissions
at the bottom.
The list of permissions will be updated to include those just selected. Remove any other unnecessary permissions using the ellipsis button next to them.
Remove Unnecessary Permissions
The permissions require admin consent. Click on the
Grant admin consent for < Your Organization >
button, then click
Yes
to confirm.
Grant admin consent for your organization
To confirm that the admin consent has been granted, check the
Status
of your permissions.
Granted Status
To grant the application the ability to rotate passwords, leave the
App registrations
to go back to Entra ID, then select
Roles and administrators
in the left menu.
In
All roles
, click on the
Helpdesk Administrator
role. If the accounts managed by the PAM module are members of any administrator roles or group âor if Privileged Identity Management (PIM) is usedâ, then the application needs the
Privileged Authentication Administrator
role.
All roles â Helpdesk Administrator
In
Assignments
, click on the
Add assignments
button.
Helpdesk Administrator â Add assignments
Filter the list to find the Azure application previously created, select it, then click
Add
.
Add assignments
Your new assignment should now be displayed in
Assignments
.
In Devolutions Server
The last steps are dedicated to configuring a scan for this provider. In the
Account discovery configuration
window that appeared when you saved your provider configuration in step 19, under
General
, enter a
Name
for this configuration.
Account discovery configuration name
Under
Configuration
, select
Groups
or
Roles
in the
Search mode
drop-down list. You can filter the
Search mode
for specific Entra ID groups or roles by clicking on the
Edit
button next to the drop-down list.
Account discovery configuration Search mode
Click
OK
when the configuration is done.
In Devolutions Server, go to
Administration â Privileged Access â Account discovery configurations
. If the
Start Scan on Save
option was left enabled during the account discovery configuration, the scan should have started by itself. During the process, the
Status
column displays an hourglass icon next to the scan entry.
Administration â Privileged Access â Account discovery configurations
When the process is complete, the hourglass icon changes to a green check mark. At that point, select accounts and import them into the privileged accounts like any other type of privileged account.
See also
Devolutions Academy - Configuring an Active Directory Provider
Devolutions Academy - Configuring an Entra ID Provider
Share your feedback

---

*Downloaded on: 2026-02-18 13:10:39*