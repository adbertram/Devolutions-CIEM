# Action scripts troubleshoot in Devolutions Server

**Source URL:** https://docs.devolutions.net/pam/kb/troubleshooting-articles/troubleshooting-action-scripts/

---

When
action scripts
fail within custom PAM providers, it is essential to understand how to identify and troubleshoot the issue. Multiple issues can arise with a custom PAM provider due to the various steps involved. Additionally, custom PAM providers heavily rely on action scripts for functionality, and depending on the complexity of the identity provider, these action scripts can become intricate.
Problems may occur if the provider is not thoroughly tested beforehand. The following guidelines will help identify potential issues and provide steps for troubleshooting.
1. Identify the problem
The problem may not always be immediately apparent. While the action scripts may function correctly in isolation, custom PAM providers may not apply password changes as expected. For instance, if the action scripts are incorrectly built and return inaccurate information, custom PAM providers may use this information to make decisions, assuming everything is functioning properly when it is not.
In some cases, the issue may be more obvious, such as seeing an "Out of sync" warning message for the user in the Devolutions PAM vault or noticing a problem in the
PAM logs
.
"Out of sync" warning
2. Identify the action script involved
Since custom PAM providers operate primarily as a script orchestrator, the majority of its functionality depends on the action scripts. If an error appears in the Devolutions Server console, it is important to first identify which action script is involved. This requires an understanding of how custom PAM providers
map
functionality to the action scripts through its terminology.
Account discovery configuration: Account discovery configurations use the account discovery action script.
Synchronization: Custom PAM providers use the term "synchronization" to refer to running the heartbeat action script.
Password reset: Initiating a password reset in custom PAM providers involves both the password rotation and heartbeat action scripts.
3. Test action scripts outside of custom PAM providers.
After identifying the action scripts involved, it is advisable to test them outside of custom PAM providers to ensure that the issue does not originate from the action script itself. The same parameters defined via Script Parameters when creating the template should be passed to the script. It is crucial to verify that the PowerShell script returns the expected results for custom PAM providers:
Account discovery: Should output at least one
pscustomobject
object with
id
,
username
, and
secret
properties.
Heartbeat: Should have
username
and
secret
parameters and return a single boolean value, either
$true
or
$false
.
Password rotation: Should include parameters for the identity provider endpoint, endpoint username, endpoint password, and a specifically named parameter called
NewPassword
.
Share your feedback

---

*Downloaded on: 2026-02-18 13:10:52*