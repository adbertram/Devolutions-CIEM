Hey guys, here's what I've been working on this week:

*Environment Explorer page* — New page that visualizes your Azure infrastructure hierarchy as an interactive graph. You can see tenants, subscriptions, resource groups, and resources laid out visually, with expand/collapse navigation. Includes summary counters (tenants, subscriptions, resource groups, resources) and switchable views (Infrastructure vs Permissions).

*Identity Hierarchy* — Built out the identity hierarchy model that maps how identities relate to each other (e.g., group memberships, service principal ownership chains). This is foundational for the identity drill-down view where you can trace an identity's full entitlement picture.

*Effective Role Assignments* — Added tracking for effective role assignments, which resolves inherited permissions across the Azure hierarchy. This means we can now show not just direct role assignments, but also what permissions an identity actually has through group memberships and management group inheritance.

*Identity-first data model refinements* — Continued shaping the data model around the identity-first approach Simon outlined. The system now organizes everything around identities as the primary axis, with entitlements and risk signals flowing from there.

Coming up next: deeper identity drill-down views and dormant permission detection using sign-in log analysis.

Does this direction look good to you guys? Any feedback or priorities you'd like me to shift toward?