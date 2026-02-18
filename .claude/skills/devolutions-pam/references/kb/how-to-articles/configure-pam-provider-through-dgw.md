# Configure PAM domain account provider through Devolutions Gateway

**Source URL:** https://docs.devolutions.net/pam/kb/how-to-articles/configure-pam-provider-through-dgw/

---

This option makes it possible to support Active Directory domain accounts in Devolutions Server PAM for multiple domains on different networks, via Devolutions Gateway. It gives you the ability to use Devolutions Server PAM to manage several Active Directory domains at once and isolate Devolutions Server from the rest of Active Directory to force use of Devolutions Gateway. This feature is especially useful for MSP's needing to access multiple subnets from different clients.
Configuration
Connect to the Devolutions Server web interface.
Go to
Administration
â
Privileged access
â
Providers
.
Click
Edit
on an already configured
Domain provider
.
Read more about
domain providers
.
Enable
Use Devolutions Gateway
under the
Domain
section.
Click on the ellipsis button to choose the Devolutions Gateway and then click on
Select
.
Click on
Edit
to choose the
Domain controller
(which is now mandatory because of the
Use Devolutions Gateway
option).
Click on
Save
in the
Preferred domain controller
window.
To save these settings and close the window click on
Save
.
Share your feedback

---

*Downloaded on: 2026-02-18 13:10:37*