# Terraform provider

**Source URL:** https://docs.devolutions.net/pam/kb/knowledge-base/terraform-provider/

---

Terraform provider enables you to manage your Devolutions Server instance. To learn more about Terraform provider, consult our
GitHub.
This provider is a work in progress, expect breaking changes between releases.
Requirements
Terraform
1.0
Go
1.18
Devolutions Server
2025.2.4.0
Building the provider
Clone the repository
Enter the repository directory
Build the provider using the Go
install
command:
go
install
Adding dependencies
This provider uses
Go modules
. Please see the Go documentation for the most up to date information about using Go modules.
To add a new dependency
github.com/author/dependency
to your Terraform provider:
go
get github.com/author/dependency
go
mod tidy
Then commit the changes to
go.mod
and
go.sum
.
Using the provider
Visit the Terraform Registry at
https://registry.terraform.io/providers/Devolutions/dvls/latest
for usage information.
Developing the provider
If you wish to work on the provider, you will first need
Go
installed on your machine (see
Requirements
above).
To compile the provider, run
go install
. This will build the provider and put the provider binary in the
$GOPATH/bin
directory.
To generate or update documentation, run
go generate
.
In order to run the full suite of Acceptance tests, run
make testacc
.
Note:
Acceptance tests create real resources, and often cost money to run.
make testacc
Testing the provider while developing
In order to perform a test of the provider, create/update the
~/.terraformrc
(
%APPDATA%\terraform.rc
on Windows) file with the following content:
provider_installation {
  dev_overrides {
    "devolutions/dvls" = "/Users/USERNAME/go/bin"
  }
  direct {
  }
}
Replace
/Users/USERNAME/go/bin
with the path to the compiled provider binary according to your operating system and environment.
Then run the following command, assuming you are on macOS or Linux:
go build -o ~/go/bin/terraform-provider-dvls_v0.5.0
chmod +x ~/go/bin/terraform-provider-dvls_v0.5.0
Notes: the version number should match the version of the provider you are working on.
You can then create a
test.tf
or
example.tf
file with the required content; here is a sample:
provider "dvls" {
  base_uri   = "https://your-dvls-instance.com/"
  app_id     = "your-app-id"
  app_secret = "your-app-secret"
}

data "dvls_entry_website" "example" {
  id = "id-of-website-entry"
}

output "website_name" {
  value = data.dvls_entry_website.example.name
}

terraform {
  required_providers {
    dvls = {
      source = "devolutions/dvls"
    }
  }
}
Then run the following command:
terraform plan
This will be the output:
â Warning: Provider development overrides are in effect
â
â The following provider development overrides are set in the CLI configuration:
â  - devolutions/dvls in /Users/USERNAME/go/bin
â
â The behavior may therefore not match any released version of the provider and applying changes may cause the state to become incompatible
â with published releases.
âµ
data.dvls_entry_website.example: Reading...
data.dvls_entry_website.example: Read complete after 1s [id=123e4567-e89b-12d3-a456-426614174000]

Changes to Outputs:
  + website_name = "TestWebsite"
Please note that the
.gitignore
already ignores the
dev.tfrc
,
.terraform.lock.hcl
,
test.tf
,
example.tf
, and
terraform.tfstate
files and the folder
.terraform/
.
Share your feedback

---

*Downloaded on: 2026-02-18 13:11:01*