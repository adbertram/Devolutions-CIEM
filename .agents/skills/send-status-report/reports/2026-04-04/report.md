Hey guys, here's what I've been working on this week:

- *Environment page* — New page for managing cloud environments connected to CIEM. You can view and configure your Azure/AWS environments directly in the app now.
- *Identity Hierarchy* — The system now maps identity parent-child relationships — managed identities tied to VMs, group memberships, etc. This feeds into the identity drill-down view.
- *Effective Role Assignments* — Computing and storing effective role assignments per identity, accounting for inherited permissions from groups and management group scope.
- *Identity Risk page* — New page showing per-identity risk signals and an overall risk summary. This is the start of the identity drill-down view Simon described — surfacing compound risk across an identity's entitlements.
- *Security graph engine* — Built the underlying graph model that maps identity-to-resource relationships and discovers attack paths (BloodHound-style path analysis for Azure).
- *Attack Paths page* — New page for visualizing attack paths from identities to sensitive resources.

Coming up next: dormant permission detection via sign-in log analysis, and role right-sizing recommendations.

Does this direction look good to you guys? Any feedback or priorities you'd like me to shift toward?
