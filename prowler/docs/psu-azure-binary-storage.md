# PSU Azure App Service: Binary Storage Reference

This document covers where to store binary files (executables, native libraries, CLI tools) when running PowerShell Universal (PSU) in Azure App Service using the `ironmansoftware/universal:*-azure` container image.

## Azure App Service Persistent Storage

### The `/home` Directory

Azure App Service Linux containers have two types of storage:

| Storage Type | Persistence | Location | Limits |
|--------------|-------------|----------|--------|
| File system storage | Persistent (if enabled) | `/home` | Included in App Service plan quota (e.g., 250GB for P2V3) |
| Host disk space | NOT persistent | Outside `/home` | 15GB limit per instance |

**Critical**: Set `WEBSITES_ENABLE_APP_SERVICE_STORAGE=true` to enable persistent storage. Without this, files in `/home` will NOT persist across restarts.

### Storage Characteristics

The `/home` directory is a **mounted network share**:
- **Pros**: Shared across scale-out instances, persists across restarts
- **Cons**: Cannot use file-based databases like SQLite (no exclusive locks), network latency

**References:**
- [Azure App Service on Linux FAQ](https://learn.microsoft.com/en-us/troubleshoot/azure/app-service/faqs-app-service-linux)
- [Configure Custom Container](https://learn.microsoft.com/en-us/azure/app-service/configure-custom-container)

---

## PSU Repository Location in Azure

### Default Container Paths

The `ironmansoftware/universal:*-azure` container writes to `/home` by default:

| Environment Variable | Default Value | Purpose |
|---------------------|---------------|---------|
| `Data__RepositoryPath` | `/home/data/Repository` | Configuration files, scripts, apps |
| `Data__ConnectionString` | `/home/data/database.db` | LiteDB database |
| `Logging__Path` | `/home/data/logs/log.txt` | Log files |
| `UniversalDashboard__AssetsFolder` | `/home/data/UniversalDashboard` | Dashboard assets |

### Modules Directory

PSU adds `[Repository]/Modules` to `$ENV:PSModulePath` for all environments. Modules installed via:
- PSU Admin Console (Platform > Modules)
- PowerShell Gallery
- Manual placement

Are stored in: `/home/data/Repository/Modules/`

**Reference:** `docs/psu-docs/platform/modules.md`, `docs/psu-docs/config/repository.md`

---

## Where to Place External Binaries

### Option 1: Inside a PSU Module (Recommended for Gallery Distribution)

Include binaries in the module folder structure:

```
MyModule/
  1.0.0/
    MyModule.psd1
    MyModule.psm1
    .universal/
      apps.ps1          # PSU resource definitions
    bin/
      linux-x64/
        mytool          # Linux x64 binary
      linux-arm64/
        mytool          # Linux ARM64 binary
```

**Advantages:**
- Distributed automatically via PSU Gallery
- Version controlled with module
- No manual installation steps

**Loading the binary in PowerShell:**
```powershell
$ModulePath = Split-Path -Parent $PSScriptRoot
$BinaryPath = Join-Path $ModulePath "bin" "linux-x64" "mytool"
& $BinaryPath --help
```

### Option 2: Repository Bin Directory

Place binaries in a dedicated folder within the repository:

```
/home/data/Repository/
  bin/
    linux-x64/
      mytool
  .universal/
    environments.ps1   # Configure PSModulePath or startup scripts
```

Configure in `environments.ps1`:
```powershell
New-PSUEnvironment -Name 'CIEM' -Path 'pwsh' -StartupScript 'startup.ps1'
```

In `startup.ps1`:
```powershell
$env:PATH = "/home/data/Repository/bin/linux-x64:$env:PATH"
```

### Option 3: Published Folder (For HTTP Access)

If binaries need to be downloadable:

```powershell
New-PSUPublishedFolder -Path '/home/data/binaries' -RequestPath '/binaries'
```

**Reference:** `docs/psu-docs/platform/published-folders.md`

---

## Including Binaries in PowerShell Modules

### NuGet/Module Runtime Folder Structure

PowerShell 7 supports native library loading from runtime-specific folders:

```
MyModule/
  1.0.0/
    MyModule.psd1
    MyModule.psm1
    lib/
      netstandard2.0/
        MyLibrary.dll
    runtimes/
      linux-x64/
        native/
          libmynative.so
      linux-arm64/
        native/
          libmynative.so
      win-x64/
        native/
          mynative.dll
```

**For standalone executables** (not .NET libraries), use a custom structure:

```
MyModule/
  1.0.0/
    MyModule.psd1
    MyModule.psm1
    tools/
      linux-x64/
        mytool           # chmod +x required
      linux-arm64/
        mytool
```

**Reference:** [Writing Portable Modules](https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/writing-portable-modules)

### Detecting Platform at Runtime

```powershell
function Get-BinaryPath {
    param([string]$BinaryName)

    $ModuleBase = $PSScriptRoot

    $rid = if ($IsLinux) {
        if ([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture -eq 'Arm64') {
            'linux-arm64'
        } else {
            'linux-x64'
        }
    } elseif ($IsMacOS) {
        if ([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture -eq 'Arm64') {
            'osx-arm64'
        } else {
            'osx-x64'
        }
    } else {
        'win-x64'
    }

    Join-Path $ModuleBase 'tools' $rid $BinaryName
}
```

---

## Azure-Specific Considerations

### Container Filesystem Constraints

| Consideration | Details |
|---------------|---------|
| Network share latency | `/home` is a network mount; avoid high-frequency file I/O |
| No SQLite | Cannot acquire exclusive locks on network shares |
| 15GB host disk limit | Data outside `/home` is lost on restart and has a 15GB limit |
| Scale-out sharing | `/home` is shared across all instances when scaled out |

### Recommended Architecture for CIEM

```
/home/data/Repository/
  Modules/
    Devolutions.CIEM/
      1.0.0/
        Devolutions.CIEM.psd1
        Devolutions.CIEM.psm1
        .universal/
          apps.ps1
          endpoints.ps1
        tools/
          linux-x64/
            prowler           # Cloud security scanner
```

### Performance Tips

1. **Minimize binary size** - Container images should be small
2. **Lazy-load binaries** - Only invoke when needed
3. **Cache results** - Use `$Cache:` scope for frequently accessed data
4. **Consider SQL backend** - For production, use Azure SQL instead of LiteDB

### Container Image Selection

| Tag | Use Case |
|-----|----------|
| `ironmansoftware/universal:5.4.4-azure` | Production Azure App Service |
| `ironmansoftware/universal:latest` | Development/testing |
| `ironmansoftware/universal:5.x-modules` | Pre-installed Az modules |

---

## PSU Gallery Distribution

When distributing via PSU Gallery:

1. **Tag your module** with `PowerShellUniversal` in the manifest:
   ```powershell
   @{
       ModuleVersion = '1.0.0'
       PrivateData = @{
           PSData = @{
               Tags = @('PowerShellUniversal', 'CIEM', 'Security')
           }
       }
   }
   ```

2. **Include binaries** in the module package (they will be downloaded with the module)

3. **Document platform requirements** in README if binaries are platform-specific

4. **Test on Azure** before publishing - the `ironmansoftware/universal:*-azure` image runs on Linux

**Reference:** `docs/psu-docs/platform/library.md`

---

## Summary

| Question | Answer |
|----------|--------|
| Where does PSU store its repository in Azure? | `/home/data/Repository/` (with `WEBSITES_ENABLE_APP_SERVICE_STORAGE=true`) |
| Where should binaries go? | Inside module at `tools/linux-x64/` or repository at `bin/linux-x64/` |
| Can modules include binaries? | Yes, include in module folder and reference via `$PSScriptRoot` |
| What persists across restarts? | Only `/home` directory (when persistence enabled) |
| What's the storage limit? | App Service plan quota for `/home`, 15GB for container filesystem |

---

## References

### PSU Documentation (Local)
- `docs/psu-docs/config/hosting/azure.md` - Azure hosting configuration
- `docs/psu-docs/platform/modules.md` - Module management
- `docs/psu-docs/platform/library.md` - PSU Gallery
- `docs/psu-docs/config/repository.md` - Repository structure
- `docs/psu-docs/getting-started/docker.md` - Docker configuration

### Microsoft Documentation
- [Azure App Service on Linux FAQ](https://learn.microsoft.com/en-us/troubleshoot/azure/app-service/faqs-app-service-linux)
- [Configure Custom Container](https://learn.microsoft.com/en-us/azure/app-service/configure-custom-container)
- [Mount Azure Storage](https://learn.microsoft.com/en-us/azure/app-service/configure-connect-to-azure-storage)
- [Writing Portable Modules](https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/writing-portable-modules)

### Community Resources
- [PSU Forum: Docker on Azure App Service](https://forums.ironmansoftware.com/t/deploy-powershell-universal-as-a-docker-image-via-azure-app-service/8233)
- [Docker Hub: ironmansoftware/universal](https://hub.docker.com/r/ironmansoftware/universal)
