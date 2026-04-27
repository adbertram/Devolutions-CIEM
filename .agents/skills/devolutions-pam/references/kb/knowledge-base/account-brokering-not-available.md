# Limitations on account brokering for specific tools

**Source URL:** https://docs.devolutions.net/pam/kb/knowledge-base/account-brokering-not-available/

---

Privileged Access Management (PAM) systems often restrict the visibility of passwords for security reasons. In Devolutions Server, and similar to some of our partners, we implement a dual permission approach: one allows viewing the password, and the other permits the use of the password through Remote Desktop Manager acting on your behalf. We refer to this functionality as account brokering, commonly known as "acting by proxy." Essentially, Remote Desktop Manager acts like a concierge who, instead of giving you a key, directly opens the door for you.
However, this functionality presents a challenge with Remote Desktop Manager, which was initially designed to prioritize ease-of-use, flexibility, and integration with nearly 160 different technologies. For some of these technologies, restricting password usage proved to be highly complex. The only viable solution to mitigate risk was to disable access to certain technologies entirely. Examples of these include command lines, PowerShell, and various management tools.
While it remains a possibility to enable these technologies in the future, currently, the risk of potential security breaches â especially considering that a malicious user could substitute a secure tool with a self-created, insecure one â is too great to address effectively at this time.
In Devolutions Server, granting permission to view the password can circumvent some issues, but if your security protocols prohibit this or if you utilize an integration that lacks this option, unfortunately, there is no current workaround available.
As part of our agreement with CyberArk, it is forbidden to ever display a password that has been obtained through our integration. For this reason, a significant number of built-in technologies in Remote Desktop Manager will trigger an error when you attempt to use a CyberArk credential.
Share your feedback

---

*Downloaded on: 2026-02-18 13:10:54*