# Just-in-time (JIT) elevation

**Source URL:** https://docs.devolutions.net/pam/server/just-in-time/

---

Just-in-time elevation is a security concept that pertains to providing temporary access to resources or services, ensuring that permissions are granted only for the specific time they are required and not a moment more. The Just-in-time feature in Devolutions Server grants temporary membership to selected Active Directory groups from a specified list.
The
Just-in-time elevation
feature is only available for Domain accounts.
Just-in-time elevation settings
Just-in-time (JIT) elevation
Option
Description
Select provider privileges to make available for temporary elevation
Select the Active Directory groups of which a privileged account will be elevated to member status. Click on the pen icon next to a selected group to assign a Devolutions Server display name to it.
Enable privilege sets
Create privilege sets to group similar privileges together by assigning provider privileges and privileged accounts.
Advanced
Option
Description
Temporary group name prefix
Prefix of the Active Directory group name to be created, which will be a member of the selected group and in which the privileged account will be a member.
Temporary group creation location
Location (OU) where the temporary Active Directory group will exist in the Active Directory structure.
Replication latency
Some domains may require additional time to apply permissions. Introducing latency helps prevent sessions from opening too quickly, which could result in a failure.
Example
The domain provider Just-in-time elevation configuration will allow privileged accounts to request elevation,  i.e., to become a temporary member of the following Active Directory groups: Remote Desktop Manager Admins; Remote Desktop Manager Service Desk or Remote Desktop Manager Admins - Universal. The temporary group name will start with RDM_JIT and will be created in the
Domain Groups\Vaults\Internal
OU.
JIT privilege elevation settings
The _backupoperator15 privileged account checkout process is requesting a 2 hours elevation to be part of the Remote Desktop Manager Admins Active Directory group.
Just-in-time Elevation settings
See also
Decoding just-in-time (JIT) elevation
JIT privilege elevation made efficient by Devolutions
Share your feedback

---

*Downloaded on: 2026-02-18 13:09:10*