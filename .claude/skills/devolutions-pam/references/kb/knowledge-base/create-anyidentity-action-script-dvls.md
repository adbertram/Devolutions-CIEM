# Custom PAM provider action scripts in Devolutions Server

**Source URL:** https://docs.devolutions.net/pam/kb/knowledge-base/create-anyidentity-action-script-dvls/

---

Using custom PAM providers requires the creation of action scripts, which are placed in the
Script
section of every action during the template-building process.
Action scripts are PowerShell scripts executed by Devolutions PAM, and the same best practices applicable to any PowerShell script should be adhered to. However, there are specific nuances to consider when writing action scripts.
Proficiency in PowerShell scripting is essential for creating custom PAM providers. It is recommended that individuals possess at least an intermediate level of scripting skill before attempting to create action scripts.
Identity provider endpoint script parameters
Each action script must include a set of parameters through which the custom PAM provider pass values. While the specifics may vary, action scripts have to share a common set of parameters to connect to the identity provider endpoint. Below is an example of how to define these:
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
Although there is flexibility in naming the parameters within action scripts (provided that they match what is specified during the template-building process in custom PAM providers), it is advisable to use a standard set of parameters to maintain consistency and clarity in naming conventions.
In this example, each parameter is marked as mandatory, forcing the provider to use them. Make sure to use the
securestring
type for the
IdentityEndpointPassword
parameter, as custom PAM providers mandate it to prevent the transmission and processing of plaintext passwords.
When constructing the custom PAM provider template, these identity provider endpoint parameters correspond to those defined during the template creation process.
Password rotation parameters with the required NewPassword parameter
Handling optional, default parameters
When you need to provide the ability to pass a value to a script parameter but not require it, that parameter is considered optional, and is only used when a value is passed to it.
During the creation of a custom PAM provider template, it is possible to define provider and account properties, and specify whether they are mandatory or optional.
Optional provider properties
The parameters within the action script for the provider mentioned above may be structured as follows, with each matching the custom PAM provider template's properties and default values assigned to the optional parameters.
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
()]
    [
string
]
$Instance
=
'.'
,

    [
Parameter
()]
    [
int
]
$Port
=
1433
)
Write-Host
"Using the instance of [
$Instance
] and the port of [
$Port
] here in the code somewhere."
Should this PowerShell script be executed outside of the custom PAM provider without the optional parameters being specified, it would operate as expected, using the default values.
.\actionscript.ps1
-IdentityProviderEndpoint
'hostname'
-IdentityProviderEndpointUserName
'admin'
-IdentityProviderEndpointPassword
(
ConvertTo-SecureString
-String
'P@$$word'
-AsPlainText
-Force
)
ab_how-to-articles-create-anyidentity-action-scripts_3-8.png
However, when constructing the custom PAM provider template and providing only the mandatory parameters, relying on the scriptâs internal default values, custom PAM providers overrides these defaults.
Script testing results with overidden parameter values
When custom PAM providers executes an action script, it invariably passes values to all parameters. In instances where no value is defined, custom PAM providers pass a
null
value, or if the parameter is of an integer type, a
0
value.
To circumvent this, default values should not be set within the script parameters. Instead, conditions within the script should determine default values.
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
()]
    [
string
]
$Instance
,

    [
Parameter
()]
    [
int
]
$Port
)
if
(!
$Instance
) {
$Instance
=
'.'
}
if
(!
$Port
) {
$Port
=
1433
}
Write-Output
"Using the instance of [
$Instance
] and the port of [
$Port
] here in the code somewhere."
Although it is not generally recommended by PowerShell best practices, providing default parameter values in this manner is a requirement for custom PAM providers.
Script testing results with default parameter values
Handling output
Action scripts are ultimately executed within the custom PAM providers environment. Any output they generate is interpreted, stored, and/or displayed in the Devolutions Server web interface.
To ensure that action scripts produce the expected output, it is recommended that they return output in only four ways:
Use the
throw
keyword to generate a terminating error using the error stream.
Use the
Write-Error
cmdlet to generate a non-terminating error using the error stream.
Use the
Write-Output
cmdlet to return information to the output stream.
Output information directly to the output stream.
Below are examples of action scripts and the corresponding results within the
Test script
functionality of custom PAM providersâ
Results
area.
Write-Verbose
-Message
'This is a verbose message.'
Write-Information
-MessageData
'information action'
Write-Output
'output stream here'
Write-Host
'write-host output here'
Write-Error
'error'
ab_how-to-articles-create-anyidentity-action-scripts_7-8.png
Write-Verbose
-Message
'This is a verbose message.'
Write-Information
-MessageData
'information action'
Write-Output
'output stream here'
'output stream here directly'
Write-Host
'write-host output here'
ab_how-to-articles-create-anyidentity-action-scripts_7-8.png
To ensure that an action script returns information to the custom PAM provider, it is advised
not
to use `Write-Verbose`, `Write-Information`, or `Write-Host`.
Account discovery
The initial action executed by a custom PAM provider is the account discovery action, which enumerates the accounts on an identity provider and populates the Devolutions Server database for subsequent management.
Required input parameters
The account discovery action script is relatively straightforward, as it primarily requires common endpoint script parameters. No additional parameters are necessary unless dictated by the specific identity provider.
Required output
Each account discovery action script must return one or more
PSCustomObject
type objects, with each object representing an individual account and containing three properties:
id
,
username
, and
secret
.
The
id
property must serve as a unique identifier for each account. While this identifier is typically a username, it can be any unique identifier for the account.
The
username
property should serve as a label for each account. This label is generally a username but can be any identifier that represents the account.
The
secret
property is the password identifier. This can take the form of an encrypted string or a plaintext password, which is then used to compare with other secrets via the heartbeat action.
If the identity provider's code does not natively return this object with the specified properties, it is necessary to convert it by creating a
PSCustomObject
. Below is an example of how to accomplish this.
## some code that returns an object for each account
$accounts
=
Get-AccountFromIdentityProvider
## Create custom fields for Select-Object to return the id and username properties instead of name, and name
$selectProps
=
@
(
@
{
'n'
=
'id'
;e={
$_
.name}}
## "convert" the name property from the account to id
@
{
'n'
=
'username'
;e={
$_
.name}}
## "convert" the name property from the account to username
@
{
'n'
=
'secret'
;e={
$_
.password_hash}}
## "convert" the password_hash property from the account to secret
)
## Pass each account to Select-Object to return the property names
$accounts
|
Select-Object
-Property
$selectProps
When creating a custom PAM provider template and testing it (instructions provided below) with an
account discovery configuration
, the
Username
and
Unique Identifier
fields are populated with the property values for the
username
and
id
properties from the action script.
ab_how-to-articles-create-anyidentity-action-scripts_8-8.png
Heartbeat
Following the retrieval of all accounts from the identity provider by the account discovery action, a heartbeat action is initiated. This reads the current password value of an account and compares it to the value stored by PAM. If the two values differ, a change is detected.
Required input parameters
In addition to the common endpoint parameters, a heartbeat action script must include at least two parameters:
username
and
secret
, which are respectively a
string
and a
securestring
.
Required output
A heartbeat action script returns a single boolean object (
$true
or
$false
) to indicate whether the current password value of an account matches the value known to the PAM modules.
Below is an example of a heartbeat action script.
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
string
]
$UserName
,

    [
Parameter
(
Mandatory
)]
    [
securestring
]
$Secret
)
## Code to query for a single user account here. Let's say it is $account.
## Convert the password to a secure string.
$secPw
=
$account
.password |
ConvertTo-SecureString
-AsPlainText
-Force
## Compare the results.
$secPw
-eq
$Secret
Password rotation
When custom PAM providers executes the heartbeat action and the action script returns a
$false
value, indicating that the new password differs from the password on the identity provider, the password rotation action is triggered.
This action is responsible for synchronizing passwords generated by the PAM module with the identity provider.
Required input parameters
In addition to the common endpoint parameters, a password rotation action script must include one parameter:
NewPassword
. This is a
securestring
parameter that allows custom PAM providers to pass the new password value to the action script.
Required output
The password rotation script should only return a boolean
$true
value if the password change is successful.
Below is a basic example of a password rotation action script.
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
)
## $result = Dowhatevertochangethepasword
if
(
$Result
) {
$True
}
else
{
Write-Error
"Failed to update secret."
}
Share your feedback

---

*Downloaded on: 2026-02-18 13:10:57*