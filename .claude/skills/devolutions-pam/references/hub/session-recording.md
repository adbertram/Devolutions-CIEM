# Session recording

**Source URL:** https://docs.devolutions.net/pam/hub/session-recording/

---

This guide outlines the configuration required to enable session recording in Devolutions Hub Business PAM using Devolutions Gateway. The connection types supported for session recording are RDP, ARD, VNC and SSH.
Create an
application identity
and assign the following permissions:
View entries
Manage privileged access tasks
Manage gateways
Download
Devolutions Hub Services
, and install it on the gateway.
Devolutions Hub Services can be installed on a separate machine that has access to the gateway ports.
After reading and accepting the
End-user license agreement
, check
PAM
from the
Custom setup
feature list.
Install the PAM module
Enter your
Host URL
, as well as the
Application secret
and
Application key
you save at the end of step 1. You can then test your connection to see if everything is working properly. Click on
Finish
.
Enter PAM service information
Go to the web interface of Devolutions Hub Business. Navigate to
Administration
â
System settings
and select
Enable Devolutions Gateway recording
setting.
Devolutions Gateway recording setting
Set the
Recording property
of the relevant entry to
Remote
by going to
Session recording
â
Recording
.
Set the Recording property to Remote
Verify that the connection works and the session recording is functional. To view the session recording in the web interface of Devolutions Hub Business or in a Remote Desktop Manager data source, navigate to the relevant entry (RDP, for example) and open the
Recordings
tab.
Recordings
See also
Devolutions Academy â Creating an application identity and application services
Devolutions Academy â  Enabling session recording in Devolutions Hub Business
Share your feedback

---

*Downloaded on: 2026-02-18 13:10:06*