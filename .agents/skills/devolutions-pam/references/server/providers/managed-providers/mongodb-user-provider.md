# MongoDB provider

**Source URL:** https://docs.devolutions.net/pam/server/providers/managed-providers/mongodb-user-provider/

---

The MongoDB provider lists the minimum MongoDB privileges a provider user needs for account discovery
and password rotation in Devolutions Server.

Required MongoDB privileges:

- `listDatabases` on `cluster` to list databases for account discovery.
- `viewUser` for account discovery.
- `changePassword` for password rotation.

Provider roles can be limited to specific databases when only those databases should be covered.

---

*Downloaded on: 2026-05-05*
