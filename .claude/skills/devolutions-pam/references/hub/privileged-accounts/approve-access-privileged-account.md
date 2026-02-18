# Approve access to a privileged account

**Source URL:** https://docs.devolutions.net/pam/hub/privileged-accounts/approve-access-privileged-account/

---

The following topic focuses on approving a check out request from the Devolutions Hub Business web interface. Note that this functionality is also available in Remote Desktop Manager with Devolutions Hub Business, either by accessing the privileged account entry in the PAM vault, or by connecting to a linked remote session.
You can also view and approve check out requests in Remote Desktop Manager even if the request was made in Devolutions Hub Business.
The
Check out
feature allows users to request temporary access to a privileged account entry in a PAM vault. The approver must then approve or deny the request.
View privileged account check out requests
When a user sends you a check out request, you will be automatically notified by email. You can click on
Go to entry dashboard
to view the request directly in the entry in Devolutions Hub Business.
Check out request email
Once you are on the entry, you will see a
Check out request
section near the top. Clicking on
View details
opens the
Check out request
window, which is described in the next section.
Check out request from the entry
Note that you can also see all pending check out requests from a selected vault in the
Check out requests
box of the
Dashboard
.
Check out request from the dashboard
Approve/Deny check out requests
The duration of the access begins when the request is approved.
When the entry is selected, clicking on
View details
in the
Check out request
section allows you to see information about the request as well as
Approve/Deny
it.
View details
In the top section, you can view the
Requested duration
. You can override this duration by specifying a new time frame in the
Authorized duration
drop-down list next to it.
Further down is the requester's message. You can add your own message as well.
Finally, you can
Approve
or
Deny
the check out request by clicking on the corresponding button.
Approve/Deny check out request
Once the request is approved, the user can proceed to view/copy the password account (per their assigned permission).
Make sure to give the right permissions to your users so they can use the privileged accounts they requested access to.
We recommend the
Privileged operator
role, as it contains the minimum permissions required to be able to use and access privileged account entries, namely
View vault
,
Connect (Execute)
,
View password
, and
View sensitive
. The difference between the
Privileged operator
and
Operator
roles is that the latter does not include the
View password
permission, which is necessary to be able to use the privileged accounts.
Alternatively, you can assign a specific role at the privileged account entry level and just give access to the vault itself.
You can force a check in of the entry to end the user's access by either:
Clicking on
Force check in
at the top of the entry
Overview
.
Force check in from the entry overview
Clicking on
View details
again, then
Force check in
.
Force check in from View details
When you check in the entry, the privileged account password automatically resets and the old password is rendered useless. Be sure you want to do this first, since to regain access to the entry, they will need to make another request. Otherwise, their access will end within the set time frame.
To learn more about the end user experience in Devolutions Hub Business, visit
Request access to a privileged account
.
For ways to monitor privileged account activity, take a look at the
Privileged access reports
.
Share your feedback

---

*Downloaded on: 2026-02-18 13:09:49*