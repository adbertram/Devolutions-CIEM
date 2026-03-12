# Data Model Architecture — Review Fixes

## Blocking Issues

- [x] 1. Replace `az graph query` with Resource Graph REST API via `Invoke-AzureApi` — updated Data Sources, New Dependencies, discovery flow
- [x] 2. Keep `azure_provider_apis` table — moved to Tables to Keep, removed from Tables to Drop
- [x] 3. Rate limiting is Phase 1 — added to Implementation Constraints, removed from Known Gaps
- [x] 4. Atomic clear-then-insert — discovery flow split into Phase 1 (collect to memory) + Phase 2 (single transaction)
- [x] 5. Transaction wrapping — documented in Implementation Constraints
- [x] 6. Replace Identities module entirely — added to Code to Delete, new data model supersedes it

## Should Address

- [x] 7. CIEM prefix on all private functions — updated all private function names
- [x] 8. `azure_resource_types` CRUD mostly private — only `Get-` is public, rest moved to private section
- [x] 9. `-All` switch on Remove functions — added to all 5 Remove function signatures
- [x] 10. Renamed `Invoke-CIEMAzureResourceDiscovery` → `Start-CIEMAzureDiscovery`
- [x] 11. Added `partial` status + `WarningCount` to `CIEMAzureDiscoveryRun` class
- [x] 12. Module folder → `Azure/Discovery` (consistent with `Azure/Infrastructure`)
- [x] 13. Drop `CIEMProvider.IsDefault` — noted in providers table description + Phase 1 rollout
- [x] 14. Phase 2 projection classes marked as "illustrative, final shape TBD"
- [x] 15. `signInActivity` on SPs requires Graph beta — noted in Entra endpoints table
- [x] 16. Schema migration strategy — new section added with 5-step migration in `New-CIEMDatabase`
