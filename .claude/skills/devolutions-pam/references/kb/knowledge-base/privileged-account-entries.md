# Methods for using personal PAM accounts in Remote Desktop Manager

**Source URL:** https://docs.devolutions.net/pam/kb/knowledge-base/privileged-account-entries/

---

You can configure Remote Desktop Manager Windows to automatically launch sessions using a PAM account from your user vault, or to prompt you with a list of available PAM accounts at launch. Both methods rely on creating a
Devolutions Server privileged account
entry and linking it to your session.
Use PAM account to automatically launch sessions
Open Remote Desktop Manager.
Go to your user vault.
Create a
Devolutions Server privileged account
entry.
Enter the server information.
Select your dedicated PAM account from the list.
Click
Add
to save the entry.
Go to the shared vault and select your session. For this example, we will use an RDP session.
Navigate to the ribbon of Remote Desktop Manager and click
Edit
â
User specific settings
â
Overwrite credentials
â
Linked
(user vault)
. From there, select the
Devolutions Server privileged account
you just created.
Open your RDP session. Youâll be prompted to check out the selected PAM account, and the session will automatically launch using this account.
Note:
User-specific settings
are applied only for your user.
Prompt for PAM accounts in sessions
In your shared vault, create a
Devolutions Server privileged account
entry.
Create a
Devolutions Server privileged account
entry.
Enter your Devolutions Server URL.
Enable both:
Use my account settings
Always prompt with list
Click
Add
to save the entry.
Navigate to
File
â
My account settings
â
Devolutions Server privileged account
, and confirm that your username is correctly entered.
Select an RDP session, for example, and go to
Edit
â
Credentials.
Select
Linked (vault)
, and choose the
Devolutions Server privileged account
entry you created.
When you double-click the RDP session, a list of available PAM accounts will appear.
Only the accounts that match your username in
My account settings
and that you have access to will be shown.
Related topics
Devolutions Academy â  Set up user vault credentials in Remote Desktop Manager
Set up user vault credentials in Remote Desktop Manager
Specific settings
Share your feedback

---

*Downloaded on: 2026-02-18 13:11:00*