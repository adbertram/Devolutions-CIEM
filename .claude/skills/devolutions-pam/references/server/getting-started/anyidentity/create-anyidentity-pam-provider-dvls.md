# Create a custom PAM provider in Devolutions Server

**Source URL:** https://docs.devolutions.net/pam/server/getting-started/anyidentity/create-anyidentity-pam-provider-dvls/

---

Custom PAM providers are built and managed using templates. Templates leverage the efforts of Devolutions and the community to build providers, reducing the need for users to create them from scratch.
A template is an object within Devolutions PAM that serves as a framework for constructing a custom PAM provider.
Templates guide Devolutions Server in mapping the action script parameters and outputs to Devolutions PAM internal properties, facilitating the input and exchange of information. Templates enable users to populate the properties of an identity provider to create a provider.
Create a custom template
or
import one of the templates
that already exist.
The
WinRM
needs to be enabled for this to work.
Create a custom PAM template
Once the
action scripts
have been created, the next step is to develop the custom PAM template within Devolutions Server.
In Devolutions Server, go to
Administration â Privileged access â Providers
.
Click on
Custom PAM templates
.
Click
Add
to create a new template.
In
General
, provide a
Name
(mandatory) and a
Description
(optional) for your new template. It is also possible to change the displayed icon.
Three actions can be enabled, each with their own script. Check the boxes next to the ones that you wish this provider to implement.
Password rotation
, to reset account passwords.
Heartbeat
, to synchronize accounts.
Account discovery
, for scanning.
While it is not mandatory to enable each action, it is recommended to do so to fully leverage the benefits of a custom PAM provider.
In
Provider properties
and
Account properties
, set the fields that the providers and accounts will implement.
Provider properties
define the attributes the custom PAM provider uses to authenticate and connect to an identity provider. These properties may include username, password, hostname, or any other unique attribute of an identity provider.
Account properties
are attributes related to a specific account on an identity provider. Common account properties include ID, username, and secret. Account properties uniquely identify provider accounts and provide a value to store an account's password or other secure credentials.
Add properties by clicking on
Add property
. For each property, provide a
Name
and a
Type
. If the Below is a list of the different types:
Boolean
Description
(string)
Int
Password
(SecureString)
Sensitive Data
(SecureString)
String
Unique Identifier
(string)
Username
(string)
Make sure to provide a Unique Identifier type if you plan on using account discovery. This field helps track which account have been added since the last scan.
Check the
Mandatory
box next to a property if the fields are required for creation/editing.
For each action that was enabled in the
General
section, go to the corresponding section in the left menu.
Map the properties of the provider/account that the script needs to work by providing the following:
Name
: Name of the variable in the script.
Source
: If the value is provided by the provider or the account.
Property
: The source property that will be injected into the script.
All actions have associated action scripts with at least two or three parameters. Custom PAM providers must understand how to map a property to a script parameter to define the relationship between the custom PAM provider object (provider or account) and each action script. Script parameters allow you to specify to the custom PAM provider which parameters each of your action scripts possesses and which custom PAM provider property that script parameter should be mapped to. If need be, you can add other script parameters.
Insert the script of the action by either browsing on your computer to find it or manually editing the
Script
field. You can also generate a base script to build upon.
Test your script once it is complete, then
Save
your new template. Your new custom PAM template has been created and can be found in the templates list. You can skip to
Create a custom PAM provider
.
Template example
Below is an example of values for a completed custom PAM template based on the following action scripts:
[
CmdletBinding
()]
param
(
    [
Parameter
(
Mandatory
)]
    [
string
]
$IdentityProviderEndpoint
,

    [
Parameter
(
Mandatory
)]
    [
string
]
$IdentityProviderEndpointUserName
,

    [
Parameter
(
Mandatory
)]
    [
securestring
]
$IdentityProviderEndpointPassword
)
[
CmdletBinding
()]
param
(
    [
Parameter
(
Mandatory
)]
    [
string
]
$IdentityProviderEndpoint
,

    [
Parameter
(
Mandatory
)]
    [
string
]
$IdentityProviderEndpointUserName
,

    [
Parameter
(
Mandatory
)]
    [
securestring
]
$IdentityProviderEndpointPassword
,

    [
Parameter
(
Mandatory
)]
    [
securestring
]
$NewPassword
,

    [
Parameter
(
Mandatory
)]
    [
string
]
$AccountUserName
)
[
CmdletBinding
()]
param
(
    [
Parameter
(
Mandatory
)]
    [
string
]
$IdentityProviderEndpoint
,

    [
Parameter
(
Mandatory
)]
    [
string
]
$IdentityProviderEndpointUserName
,

    [
Parameter
(
Mandatory
)]
    [
securestring
]
$IdentityProviderEndpointPassword
,

    [
Parameter
(
Mandatory
)]
    [
securestring
]
$AccountSecret
,

    [
Parameter
(
Mandatory
)]
    [
string
]
$AccountUserName
)
Provider properties
Property name
Property type
Mandatory
IdentityProviderEndpoint
String
Yes
IdentityProviderEndpointUserName
UserName
Yes
IdentityProviderEndpointPassword
Password
Yes
Account properties
Property name
Property type
Mandatory
AccountUserName
UniqueIdentifier
Yes
AccountSecret
Password
Yes
Script parameter types
Parameter name
Action(s)
Property
Source
Mandatory
IdentityProviderEndpoint
Password rotation, Heartbeat, Account discovery
IdentityProviderEndpoint
Provider
Yes
IdentityProviderEndpointUserName
Password rotation, Heartbeat, Account discovery
IdentityProviderEndpointUserName
Provider
Yes
IdentityProviderEndpointPassword
Password rotation, Heartbeat, Account discovery
IdentityProviderEndpointPassword
Provider
Yes
NewPassword
Password Rotation
N/A
System
Yes
AccountUserName
Password rotation, Heartbeat
AccountUserName
Account
Yes
AccountSecret
Heartbeat
AccountSecret
Account
Yes
Import a custom PAM template
You can access our public
GitHub repository
to find custom PAM providers made by the Devolutions team and instructions on how to use them.
In Devolutions Server, go to
Administration â Privileged access â Providers
.
Click on
Custom PAM templates
.
Click on
Import
.
Upload your .json file, then click on
Import
.
Adapt the template settings if need be, then click on
Save
.
Your template has now been imported and can be found in the
Custom PAM templates
list.
Create a custom PAM provider
Once your template has been created or imported, you are ready to create a custom PAM provider.
Go to
Administration â Privileged access â Providers
, then click
Add
.
Go to
Custom
in the left menu, then select your new template in the list. Click
Continue
.
In the
Provider
configuration page, provide a
Name
and a
Username
, as this information is mandatory. Then, if necessary, set the other options according to your needs.
Click
Save
.
Your new custom PAM provider has been created and can be found in the providers list.
See also
Devolutions Academy - Configuring a custom PAM provider
Share your feedback

---

*Downloaded on: 2026-02-18 13:09:05*