# AWS IAM provider

**Source URL:** https://docs.devolutions.net/pam/hub/providers/aws-iam-provider/

---

Integrating an AWS IAM provider with Devolutions Hub Business allows you to centralize identity and access management by leveraging your existing AWS credentials. This configuration enables
account discovery
,
heartbeat
monitoring, and
password rotation
for your AWS resources.
Prerequisite
Create a user in AWS who will act as a provider.
Create an access key.
The following permissions are required for the AWS identity provider:
ACTION
DESCRIPTION
iam:GetUser
To ensure the necessary permissions are in place before proceeding.
iam:SimulatePrincipalPolicy
To ensure the necessary permissions are in place before proceeding.
Account discovery
ACTION
DESCRIPTION
iam:ListAccessKeys
To get a list of access keys.
iam:ListUsers
To get a list of IAM users.
Password reset - Password
ACTION
DESCRIPTION
iam:GetLoginProfile
To check whether a login profile needs to be created or updated.
iam:CreateLoginProfile
To generate a password if non exists.
iam:UpdateLoginProfile
To update the password.
Password reset - Access key
ACTION
DESCRIPTION
iam:CreateAccessKey
To generate an access key on import or rotation.
iam:DeleteAccessKey
To delete the previous access key after rotation.
iam:UpdateAccessKey
To disable the previous access key before deletion.
iam:ListUserTags
To verify if we need to update the tag of an access key
iam:TagUser
To add a tag to the user in the format
<accessKeyId, message>
. Note that tags are applied to the user, not the access key.
iam:UntagUser
To remove an existing access key tag.
.JSON policy for the AWS console
Here is the full .JSON policy for the AWS console. It can be used on a user or a group.
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "iam:SimulatePrincipalPolicy",
                "iam:GetUser",
                "iam:ListUsers",
                "iam:ListAccessKeys",
                "iam:GetLoginProfile",
                "iam:CreateLoginProfile",
                "iam:UpdateLoginProfile",
                "iam:CreateAccessKey",
                "iam:DeleteAccessKey",
                "iam:UpdateAccessKey",
                "iam:ListUserTags",
                "iam:TagUser",
                "iam:UntagUser"
            ],
            "Resource": "*"
        }
    ]
}
Configure the AWS IAM provider for Devolutions Hub Business
To create the AWS IAM user provider in Devolutions Hub Business, add a new entry.
Navigate to the
Providers
tab and select
AWS IAM - Provider
.
Enter a name and choose a folder.
Enter the access key and the secret key from AWS.
To do a reset password on import, a
password policy
must be created that follows the
AWS default password policy
.
Go to the
Password rotation
tab.
Select the password policy previously created in the drop-down menu.
Click
Add
to close the window.
Share your feedback

---

*Downloaded on: 2026-02-18 13:09:58*