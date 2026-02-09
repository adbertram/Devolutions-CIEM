# Discovery: Local PSU Setup

## Codebase Context

### Key Files

- `scripts/PSUniversal.psm1` - PowerShell module with management cmdlets for PSU (Connect-PSU, Install-PSUModule, Publish-PSUModule, Invoke-PSUCommand, etc.)
- `.env` - Contains PSU_URL (Azure instance) and PSU_TOKEN for authentication
- `_temp/psu-deploy.bicep` - Azure deployment template for PSU v5.5.4 using `ironmansoftware/universal:5.5.4-azure` Docker image
- `Devolutions.CIEM/.universal/dashboards.ps1` - PSU app registration using `New-PSUApp` with Module-based pattern
- `Devolutions.CIEM/Devolutions.CIEM.psd1` - Module manifest with v0.3.28, PowerShell 7.4+ requirement
- `docs/psu-deployment-methods.md` - Documentation covering various PSU deployment approaches

### Existing Patterns

- **Azure PSU Setup**: Currently running PSU v5.5.4 on Azure App Service (Linux) with `ironmansoftware/universal:5.5.4-azure` container image
- **Authentication Pattern**: PSUniversal.psm1 uses Connect-PSU to read PSU_URL/PSU_TOKEN from .env file
- **Module Publishing**: Publish-PSUModule auto-bumps version, publishes to PSGallery, then imports to PSU
- **PowerShell Version**: Local system has PowerShell 7.6.0-preview.6 installed
- **Module Structure**: Devolutions.CIEM auto-installs required Az.* and Microsoft.Graph.* modules on import

### Integration Points

- PSU REST API endpoints: `/api/v1/module`, `/api/v1/dashboard`, `/api/v1/script`, `/api/v1/configuration`
- Azure Kudu API for filesystem operations (used by Remove-PSUModule for cleanup)
- PowerShell Gallery as module distribution mechanism
- .env file for configuration (PSU_URL, PSU_TOKEN, NUGET_API_KEY)

---

## Q&A Results

### Wave: Clarify Task

**Q:** The codebase currently uses PSU v5.5.4 in Azure. Should the local instance match this exact version, or would you prefer the latest stable PSU v5 release?
**A:** Match Azure (5.5.4)

**Q:** PSU can run via Docker container (like Azure) or as a native macOS installation. Which approach do you prefer for local development?
**A:** Docker container if it can successfully run on macOS ARM

**Q:** The .env file currently points PSU_URL to Azure. Should we modify this file to point to localhost, or create a separate .env.local file?
**A:** Update to be PROD_PSU_URL and LOCAL_PSU_URL

### Wave: Success Criteria

**Q:** The PSUniversal.psm1 module auto-detects Azure hosting by checking if URL contains '.azurewebsites.net'. Should this be enhanced to support localhost detection?
**A:** Not necessary - the detection is for Azure Kudu API cleanup only, not general PSU operations. Connect-PSU works fine for any URL.

**Q:** What defines 'success' for this local PSU setup? What functionality must work?
**A:** PSU running + accessible (web UI loads at localhost)

### Wave: Technical Decisions

**Q:** The Azure deployment uses a JWT signing key for authentication. Should the local instance generate its own key, or use a hardcoded dev key?
**A:** Skip JWT config - let PSU use defaults

**Q:** Should the local PSU instance use SQLite (default) or configure a local PostgreSQL/SQL Server database?
**A:** SQLite (default)

**Q:** Should the local PSU use the same port as Azure (80/443) or a different port to avoid conflicts?
**A:** Use port 5000

**Q:** Where should the local PSU store its data (database, modules, logs)?
**A:** Should be identical to the Azure PSU (use Docker volume mapping to mirror Azure structure)

### Wave: Implementation Preferences

**Q:** Should the local PSU setup be documented, automated via script, or both?
**A:** Setup script only

**Q:** The current shell scripts (azure_psu_file_manager.sh, invoke_command_in_azure_webapp.sh) only work with Azure. Should these be updated to work with local PSU, or create new local-specific scripts?
**A:** Update existing scripts to support local PSU

### Wave: Edge Cases

**Q:** If the local PSU needs to be reset, what should be preserved?
**A:** Nothing - easy to recreate from scratch

### Wave: Risk Assessment

**Q:** Should the local PSU be set up to auto-start on system boot, or start manually when needed?
**A:** Manual start

**Q:** The PSU admin UI will be accessible at localhost. Should we set up authentication (admin user/password) or run in development mode?
**A:** Development mode (disable auth for easier local testing)

**Q:** The Publish-PSUModule function auto-connects to PSU and imports the module after publishing. Should this be updated to support publishing to both Azure AND local PSU?
**A:** Add -LocalOnly switch for quick local testing

**Q:** Should the local PSU installation files be committed to the repository or kept completely separate?
**A:** Add to .gitignore

---

## Key Decisions

1. **Version**: PSU v5.5.4 (match Azure exactly)
2. **Install Method**: Docker container (verify ARM compatibility on macOS)
3. **Port**: 5000
4. **Database**: SQLite (default)
5. **Auth**: Development mode (no auth)
6. **Data Storage**: Mirror Azure structure via Docker volumes
7. **Config**: Rename .env variables to PROD_PSU_URL/LOCAL_PSU_URL
8. **Scripts**: Update existing scripts to support both Azure and local
9. **Publishing**: Add -LocalOnly switch to Publish-PSUModule
10. **Auto-start**: Manual (no launchd/Docker restart policy)
11. **Git**: Add local PSU files to .gitignore
