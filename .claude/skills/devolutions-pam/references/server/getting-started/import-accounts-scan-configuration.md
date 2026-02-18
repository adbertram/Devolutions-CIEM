# Import accounts from an account discovery configuration

**Source URL:** https://docs.devolutions.net/pam/server/getting-started/import-accounts-scan-configuration/

---

Once a list of accounts has been discovered, the next step is to import privileged accounts into a Devolutions PAM vault. If a vault was selected during the creation of the provider, a vault with the same name as the provider will have been created; otherwise, it will be necessary to
create one manually
.
Import accounts
To import accounts into a vault, select each discovered user and click on
Import selected accounts
.
Select the
Provider
and the
Path
to the vault where the accounts will be added.
To reset passwords immediately for all imported accounts, select the
Reset password on import
option. This will automatically initiate a heartbeat and password rotation action on every imported account.
Click
OK
to import the accounts into the vault.
Once imported, the accounts should appear under the providerâs vault.
Verifying heartbeat and password rotation actions on import
At this stage, the provider should have executed the heartbeat and password rotation actions, checking and resetting the account passwords if the
Reset password on import
option was selected. Verification of this process is recommended.
To verify, click on the account and navigate to the
Logs
category.
Account logs
Within the logs, three key messages should be present:
Entry added
: Indicates that a new account has been added to the vault.
PAM password reset - Success
: Confirms that the provider executed the password rotation action and successfully changed the password.
Check synchronization - Success
: Confirms that the heartbeat action compared the current password stored by Devolutions PAM with the password assigned to the account, confirming they match.
If all these messages are present, it can be confirmed that the provider has successfully executed all actions.
Although importing a new account into a vault automatically initiates a heartbeat and password rotation action, these actions can also be tested at any time.
While viewing the account in the vault, the heartbeat action can be tested by right-clicking on the account and selecting
Check synchronization status:
Check synchronization status
Or by clicking on the atom symbol:
Check synchronization status
If successful, the
Check synchronization - Success
message will appear in the account logs.
Share your feedback

---

*Downloaded on: 2026-02-18 13:09:08*