# Discovery: Port Prowler CLI to PowerShell Module

## Codebase Context

### Prowler Python Codebase Structure
- **Main entry point**: `prowler/prowler-cli.py` → calls `prowler/__main__.py`
- **Provider structure**: `prowler/prowler/providers/{azure,aws}/`
- **Check pattern**: Each check is in its own directory with:
  - `{check_name}.py` - Check implementation (Python class inheriting from `Check`)
  - `{check_name}.metadata.json` - Metadata (severity, description, remediation, categories)
  - Optional `{check_name}_fixer.py` - Automated remediation

### Check Framework
- Base class: `Check` in `prowler/lib/check/models.py`
- Report models: `Check_Report_Azure` and `Check_Report_AWS`
- Metadata model: `CheckMetadata` (Pydantic schema with severity, categories, remediation code)
- Service clients: Each service has a `{service}_client.py` and `{service}_service.py`

### Check Counts
- **Total Azure checks**: 166
- **Azure identity-focused services**:
  - Entra ID: 15 checks (conditional access, MFA, guest users, security defaults)
  - IAM (RBAC): 3 checks (custom roles, permissions)
  - Key Vault: 10 checks (access policies, RBAC, expiration)
  - Storage: 18 checks (access keys, public access, authorization)
- **Total identity-focused Azure checks**: ~46

### Key Patterns in Prowler

**Pattern 1: Service-Client Pattern** (`entra_client.py:4`, `iam_client.py:4`)
```python
entra_client = Entra(Provider.get_global_provider())
iam_client = IAM(Provider.get_global_provider())
```

**Pattern 2: Check Execution** (`entra_security_defaults_enabled.py:5-26`)
```python
class entra_security_defaults_enabled(Check):
    def execute(self) -> Check_Report_Azure:
        findings = []
        for tenant, security_default in entra_client.security_default.items():
            report = Check_Report_Azure(metadata=self.metadata(), resource=security_default)
            report.status = "FAIL" if not security_default.is_enabled else "PASS"
            findings.append(report)
        return findings
```

**Pattern 3: Metadata Structure** (`entra_security_defaults_enabled.metadata.json`)
```json
{
  "Provider": "azure",
  "CheckID": "entra_security_defaults_enabled",
  "Severity": "high",
  "Categories": [],
  "Remediation": {
    "Code": {"CLI": "", "Terraform": "", "Other": "..."},
    "Recommendation": {"Text": "...", "Url": "..."}
  }
}
```

**Pattern 4: Provider Authentication** (`azure_provider.py:12-17`)
- `DefaultAzureCredential` (auto-detect: managed identity, environment, CLI)
- `ClientSecretCredential` (service principal)
- `InteractiveBrowserCredential` (browser login)

---

## Q&A Results

### Wave 1: Clarify Task Scope

**Q:** Prowler has 166 Azure checks total, but only ~46 are identity-focused (15 Entra, 3 IAM/RBAC, 10 KeyVault access, 18 Storage access). Should we port ALL 46 identity-focused checks for V1, or start with a smaller MVP subset?
**A:** All 46 Azure checks - Port all identity-focused checks from Entra, IAM, KeyVault, Storage services

**Q:** For AWS, Prowler has 578 total checks with ~67 identity-focused (43+ IAM, 3 Secrets Manager, 21 S3 policies). Same question: all checks or MVP subset for V1?
**A:** Only Azure for V1 - AWS is out of scope

**Q:** Each Prowler check has a metadata.json file with CheckID, Severity, Description, Risk, Remediation (CLI/Terraform/NativeIaC), Categories, RelatedUrl. The architecture doc shows a simplified Finding object. Should we preserve all Prowler metadata fields or use a minimal subset?
**A:** Full metadata - Port all fields: Description, Risk, Remediation (CLI/Terraform), Categories, URLs

**Q:** Architecture doc shows 'Data/CheckMetadata.psd1' for check definitions. Should this be one large .psd1 file, individual .psd1 per check (like Prowler's .metadata.json), or something else?
**A:** Centralize checks and metadata as much as possible - prefer single consolidated file

### Wave 2: Success Criteria

**Q:** The architecture doc mentions 'findings stored as job output (snapshot per scan)'. Should completed scans return findings to the PSU job output, write to a JSON file, or both?
**A:** PSU job output only - Return findings array from Invoke-CIEMScan, no file writes

**Q:** For test validation, should we verify check logic against real Azure environments, or use mocked data (like Prowler's test fixtures)?
**A:** Real environment tests - Test against live Azure with known-state resources

**Q:** Prowler checks return PASS/FAIL/MANUAL/SKIPPED statuses. The architecture doc shows PASS/FAIL. Should we support all four statuses or just PASS/FAIL?
**A:** All four statuses - Include MANUAL for checks requiring human review

**Q:** When a check encounters an API error (permission denied, throttling), should it throw an exception, return a SKIPPED finding, or log and continue?
**A:** Return SKIPPED finding - Add finding with status=SKIPPED, continue scan

### Wave 3: Technical Decisions

**Q:** Prowler's Azure Entra service uses Microsoft Graph SDK with async/await. PowerShell has Microsoft.Graph module. Should we use Graph SDK cmdlets (Connect-MgGraph, Get-MgUser) or Az.Resources REST calls?
**A:** Invoke-AzRestMethod as much as possible to prevent depending on other cmdlets

**Q:** Prowler initializes service clients once with global provider. In PowerShell, should we follow a similar singleton pattern or pass context to each check?
**A:** Singleton services - Initialize $script:EntraService once, checks reference it

**Q:** Prowler's Check base class has a metadata() method that loads .metadata.json. Should PowerShell checks follow OOP (classes) or functional (functions with metadata lookup)?
**A:** Each check should be defined in a JSON file and we have a single main function called Invoke-CIEMScan that invokes them

**Q:** The architecture doc shows Check IDs like 'azure_entra_mfa_disabled' (snake_case like Prowler). Should we keep these IDs or use PowerShell conventions (PascalCase)?
**A:** Keep Prowler IDs - Use azure_entra_mfa_disabled for direct mapping

**Q:** Prowler's 'service layer' pre-loads Azure/AWS resources once at scan start, then checks iterate over cached data. Should PowerShell checks pre-load resources upfront or query APIs as each check runs?
**A:** Pre-load resources - Invoke-AzRestMethod once per resource type, cache results for all checks

**Q:** Azure authentication: architecture doc mentions Managed Identity, Service Principal, Az CLI context. Should we auto-detect in order (like Prowler) or require explicit parameter?
**A:** Auto-detect (Prowler pattern) - Try Managed Identity → Environment Vars → Az CLI context → prompt

### Wave 4: Implementation Preferences

**Q:** The architecture doc shows module structure with Private/Azure/Checks/. Should each check be a separate .ps1 file (like Prowler's directories) or group checks by service in single files?
**A:** One file per check - Private/Azure/Checks/Check-EntraSecurityDefaults.ps1 (46 Azure files)

**Q:** Prowler has remediation code in metadata.json (CLI, Terraform, CloudFormation). Architecture doc says PAM integration is placeholder. Should we port remediation metadata or skip it?
**A:** Link to PAM only - Generic 'See Devolutions PAM' message, no specific remediation

**Q:** Should the PSU App pages be part of the module package (.universal/apps.ps1) or separate/optional?
**A:** Build app later - V1 is module-only, app is V2 feature

**Q:** The architecture doc shows Get-CIEMProviders, Get-CIEMChecks functions. Should these list available providers/checks from metadata, or also show enabled status based on authentication state?
**A:** Static list - Return all checks regardless of auth state

**Q:** For parallel execution, should checks run sequentially, or use PowerShell jobs/runspaces for concurrency (like Prowler's threading)?
**A:** ForEach-Object -Parallel - Use PS7+ parallel foreach for check execution

**Q:** Some Prowler checks depend on other checks (DependsOn field in metadata.json). Should we implement check dependencies or run all checks independently?
**A:** Support dependencies - Parse DependsOn, ensure prerequisite checks run first

### Wave 5: Risks and Unknowns

**Q:** Should we create similar test fixtures (mock Azure responses) for PowerShell Pester tests, or rely solely on real environment integration tests?
**A:** Integration tests only - Test against real Azure, no mock fixtures

**Q:** Prowler's Azure checks handle multi-tenancy (iterate over tenants). Should our module support scanning multiple Azure tenants in one run?
**A:** Tenant parameter - Support -TenantId parameter but default to current context tenant

**Q:** If upstream Prowler adds/changes checks, how should we handle updates?
**A:** Skip for now - not a concern for V1

---

## Key Decisions Summary

| Aspect | Decision |
|--------|----------|
| **Provider Scope** | Azure only for V1 (no AWS) |
| **Check Count** | All 46 identity-focused Azure checks |
| **Metadata** | Full metadata in centralized file, keep Prowler IDs |
| **API Approach** | Invoke-AzRestMethod (avoid external module dependencies) |
| **Authentication** | Auto-detect (Managed Identity → Env → CLI → Interactive) |
| **Service Pattern** | Singleton services with pre-loaded resources |
| **Check Definition** | JSON file defines checks, single Invoke-CIEMScan executes them |
| **Check Files** | One .ps1 file per check for logic |
| **Output** | Return findings array (PSU job output), no file writes |
| **Status Codes** | PASS/FAIL/MANUAL/SKIPPED |
| **Error Handling** | Return SKIPPED finding on errors, continue scan |
| **Execution** | ForEach-Object -Parallel |
| **Dependencies** | Support DependsOn between checks |
| **Multi-Tenancy** | -TenantId parameter, default to current context |
| **Remediation** | Link to Devolutions PAM only |
| **PSU App** | V2 feature, not V1 |
| **Testing** | Real environment integration tests only |
