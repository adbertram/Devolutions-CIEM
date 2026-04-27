# Password rotation

**Source URL:** https://docs.devolutions.net/pam/concepts/password-rotation/

---

Password rotation
is the process of automatically changing stored passwords on a regular basis to improve security and reduce risk from credential exposure. This concept is essential in privileged access management as it helps protect critical accounts from unauthorized access.
In Devolutions PAM, password rotation involves
discovering accounts
from an
identity provider
, comparing stored and actual passwords, and changing them when needed. The new passwords are securely stored and linked to the corresponding entries. These operations are managed using discovery, heartbeat, and password rotation mechanisms to enforce password policies and credential accuracy.
While built-in providers handle these steps internally, fully customized control is only available by creating
custom PAM provider templates
. This option enables flexible integration with external systems and custom workflows for password lifecycle management.
Password rotation differs from a password reset, which is typically a one-time manual operation triggered by a specific event, such as a forgotten password or suspected compromise. In contrast, rotation is a recurring, proactive process that helps maintain ongoing security
compliance
. While both result in a new password, rotation is scheduled and automated, whereas reset is reactive and often user-initiated.
Password rotation aliases
Credential rotation
Automatic password update
Privileged account rotation
Related topics
Account discovery (Devolutions Hub Business)
Password rotation (Devolutions Server)
See also
Heartbeat (Devolutions Server)
Share your feedback

---

*Downloaded on: 2026-02-18 13:08:34*