---
description: Database CRUD convention for new tables
paths: ["psu-app/**"]
---

# Database CRUD Convention (MANDATORY)

**Every database table MUST have a corresponding class and full CRUD functions.**

## Required per table

1. **Class** — In the owning module's `Classes/` directory. Properties match table columns (PascalCase).
2. **New-CIEM[Azure]<Entity>** — INSERT. Fails if record exists. Returns created object.
3. **Get-CIEM[Azure]<Entity>** — SELECT with optional filter parameters. Returns `[ClassName[]]`.
4. **Update-CIEM[Azure]<Entity>** — UPDATE partial fields via `$PSBoundParameters.ContainsKey`. Supports `-PassThru`.
5. **Save-CIEM[Azure]<Entity>** — INSERT OR REPLACE (upsert). Fire-and-forget for bulk operations.
6. **Remove-CIEM[Azure]<Entity>** — DELETE with `SupportsShouldProcess`. Supports `-Id`, `-ProviderId` (bulk), and `-InputObject`.

## Parameter set pattern

Every write function (New/Update/Save/Remove) must have two parameter sets:
- **ByProperties** — Individual typed parameters for each column
- **InputObject** — Accepts `[ClassName[]]` (array) with `ValueFromPipeline` for pipeline and bulk support

## Naming

- Base module tables: `Verb-CIEM<Entity>` (e.g., `New-CIEMCheck`)
- Azure module tables: `Verb-CIEMAzure<Entity>` (e.g., `New-CIEMAzureSecurityPrincipal`)
- AWS module tables: `Verb-CIEMAWS<Entity>` (future)

## When adding a new table

1. Add schema to the appropriate `Data/*.sql` file
2. Create the class in `Classes/`
3. Create all 5 CRUD functions in `Public/`
4. Add functions to the module's `.psd1` `FunctionsToExport`
5. If the table is provider-specific collected data, integrate with the provider's `Save/Get-CIEMCollectedData`
