# PSU Deployment Methods for Devolutions.CIEM

This document covers all available methods to deploy the Devolutions.CIEM PowerShell module to a PowerShell Universal v5 server running on Azure App Service.

## Context

- **PSU Version**: 5.5.4+
- **Hosting**: Azure App Service (Linux container)
- **Container Image**: `ironmansoftware/universal:5.x.x-azure`
- **Challenge**: Deployment packages require SQL database storage, which isn't configured by default

---

## Method Comparison

| Method | SQL Required | Complexity | Automation | Best For |
|--------|--------------|------------|------------|----------|
| [Repository Modules Folder](#1-repository-modules-folder) | No | Low | Medium | Simple deployments |
| [Deployment Packages](#2-deployment-packages) | No (SQLite OK)* | Medium | High | Versioned rollback |
| [Kudu/SCM Upload](#3-kuduscm-file-upload) | No | Low | High | CI/CD pipelines |
| [Custom Container Image](#4-custom-container-image) | No | High | High | Reproducible builds |
| [PSU Gallery](#5-psu-gallery-publication) | No | Medium | N/A | Public distribution |
| [Environment Startup](#6-environment-startup-scripts) | No | Low | Medium | Dynamic installation |
| [Root Module Config](#7-root-module-configuration) | No | High | High | Complete app distribution |

*Note: Deployment package **selection** requires SQL database. Upload works with SQLite but applying fails with "Deployment storage not supported" error.

---

## 1. Repository Modules Folder

PSU automatically adds `{Repository}/Modules/` to `$ENV:PSModulePath`. Any module placed here is available to all PSU processes.

### Storage Location

| Platform | Path |
|----------|------|
| Azure Linux Container | `/home/data/UniversalAutomation/Repository/Modules/` |
| Windows | `%ProgramData%\UniversalAutomation\Repository\Modules` |

### Implementation

**Option A: Copy via Kudu Console**
```bash
# Access: https://{sitename}.scm.azurewebsites.net/DebugConsole
cd /home/data/UniversalAutomation/Repository/Modules
# Upload module folder via drag-and-drop
```

**Option B: Use Save-Module in PSU Script**
```powershell
# Run as PSU script with elevated permissions
$modulesPath = '/home/data/UniversalAutomation/Repository/Modules'
Save-Module -Name Devolutions.CIEM -Path $modulesPath -Force
```

**Option C: Admin Console**
1. Navigate to Platform > Modules
2. Click "Create New Module" or search PowerShell Gallery
3. Install directly

### Pros/Cons

| Pros | Cons |
|------|------|
| Simple, no database required | Manual process for updates |
| Modules auto-load on startup | No version rollback |
| Works with SQLite/LiteDB | Requires file system access |

---

## 2. Deployment Packages

Deployment packages are PSU configuration snapshots packaged as NuPkg files. They can bundle modules in the `Modules/` directory.

### Package Structure

```
Devolutions.CIEM.PSUApp/
├── .universal/
│   └── dashboards.ps1    # App registration
├── apps/
│   └── DevolutionsCIEM/
│       └── app.ps1       # App content
├── Modules/
│   └── Devolutions.CIEM/ # Bundled module
├── Devolutions.CIEM.PSUApp.psd1
└── Devolutions.CIEM.PSUApp.psm1
```

### Creating a Package

```powershell
# Requires: Microsoft.PowerShell.PSResourceGet
Compress-PSResource -Path ./Devolutions.CIEM.PSUApp -DestinationPath ./ -PassThru
```

### Uploading

```powershell
# Upload via REST API
$Form = @{
    Name        = 'DevolutionsCIEM'
    Version     = '1.0.0'
    Description = 'CIEM App with Module'
    File        = Get-Item ./Devolutions.CIEM.PSUApp.1.0.0.nupkg
}
Invoke-RestMethod -Uri "$PSUServerUrl/api/v1/deployment" `
    -Headers @{ Authorization = "Bearer $AppToken" } `
    -Method Post -Form $Form
```

### Applying (Requires SQL)

```powershell
# This FAILS without SQL database configured
Get-PSUDeployment -Name 'DevolutionsCIEM' -Version '1.0.0' | Select-PSUDeployment

# Error: "Deployment storage not supported"
```

### Enabling SQL Database

To use deployment packages fully, configure SQL:

```bash
# Azure App Service environment variables
Plugins__0=SQL
Data__ConnectionString=Server=tcp:yourserver.database.windows.net,1433;Database=psu;...
```

### Pros/Cons

| Pros | Cons |
|------|------|
| Versioned, immutable deployments | Selection requires SQL database |
| Rollback capability | More complex setup |
| Bundles modules with config | Cannot use with Git sync |

---

## 3. Kudu/SCM File Upload

Azure App Service provides Kudu for direct file management via REST API.

### Access

- **Web Console**: `https://{sitename}.scm.azurewebsites.net`
- **API Base**: `https://{sitename}.scm.azurewebsites.net/api`

### Authentication

```powershell
# Get credentials from publish profile
$publishProfile = Get-AzWebAppPublishingProfile `
    -ResourceGroupName 'devolutions-ciem-rg' `
    -Name 'devolutions-ciem-psu'

# Or use deployment credentials
$username = '$devolutions-ciem-psu'
$password = '<from publish profile or Azure Portal>'
$base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${username}:${password}"))
$headers = @{ Authorization = "Basic $base64Auth" }
```

### VFS API (Single Files)

```powershell
# Upload single file
$modulePath = "/home/data/UniversalAutomation/Repository/Modules/Devolutions.CIEM"
Invoke-RestMethod `
    -Uri "https://devolutions-ciem-psu.scm.azurewebsites.net/api/vfs${modulePath}/Devolutions.CIEM.psm1" `
    -Method PUT `
    -Headers $headers `
    -InFile "./Devolutions.CIEM.psm1" `
    -ContentType "application/octet-stream"
```

### ZIP API (Bulk Upload)

```powershell
# Create module ZIP
Compress-Archive -Path ./Devolutions.CIEM/* -DestinationPath ./Devolutions.CIEM.zip

# Upload and extract to Modules folder
Invoke-RestMethod `
    -Uri "https://devolutions-ciem-psu.scm.azurewebsites.net/api/zip/home/data/UniversalAutomation/Repository/Modules/Devolutions.CIEM/" `
    -Method PUT `
    -Headers $headers `
    -InFile "./Devolutions.CIEM.zip" `
    -ContentType "application/zip"
```

### Pros/Cons

| Pros | Cons |
|------|------|
| Direct file access | Requires Kudu credentials |
| Works without SQL | Manual credential management |
| Scriptable for CI/CD | Azure-specific |
| Atomic ZIP uploads | |

---

## 4. Custom Container Image

Build a Docker image with modules pre-installed.

### Dockerfile

```dockerfile
FROM ironmansoftware/universal:5.5.4-azure

# Install module from PowerShell Gallery
RUN pwsh -Command "Install-Module -Name Az.Accounts -Force -Scope AllUsers"

# Or copy local module
COPY ./Devolutions.CIEM /root/.local/share/powershell/Modules/Devolutions.CIEM/

# Alternative: Copy to Repository location (requires volume mount)
# COPY ./Devolutions.CIEM /home/data/UniversalAutomation/Repository/Modules/Devolutions.CIEM/
```

### Build and Push

```bash
# Build
docker build -t devolutions-ciem-psu:1.0.0 .

# Push to Azure Container Registry
az acr login --name devolutionsacr
docker tag devolutions-ciem-psu:1.0.0 devolutionsacr.azurecr.io/psu:1.0.0
docker push devolutionsacr.azurecr.io/psu:1.0.0

# Update App Service
az webapp config container set \
    --resource-group devolutions-ciem-rg \
    --name devolutions-ciem-psu \
    --docker-custom-image-name devolutionsacr.azurecr.io/psu:1.0.0
```

### Pros/Cons

| Pros | Cons |
|------|------|
| Reproducible deployments | Requires container registry |
| Version controlled | Rebuild on module updates |
| Includes all dependencies | More complex CI/CD |
| Fast container startup | |

---

## 5. PSU Gallery Publication

Publish module to PowerShell Gallery with `PowerShellUniversal` tag for discovery in PSU Gallery.

### Module Manifest Requirements

```powershell
# Devolutions.CIEM.psd1
@{
    RootModule = 'Devolutions.CIEM.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    Author = 'Devolutions'
    CompanyName = 'Devolutions Inc.'
    Description = 'Cloud Infrastructure Entitlement Management for PowerShell Universal'

    PrivateData = @{
        PSData = @{
            # Required for PSU Gallery discovery
            Tags = @('PowerShellUniversal', 'CIEM', 'Security', 'Azure', 'AWS')
            ProjectUri = 'https://github.com/Devolutions/Devolutions-CIEM'
        }
    }

    RequiredModules = @(
        @{ ModuleName = 'Az.Accounts'; ModuleVersion = '4.0.0' }
    )
}
```

### Publication

```powershell
# Test manifest
Test-ModuleManifest -Path ./Devolutions.CIEM/Devolutions.CIEM.psd1

# Publish
Publish-Module -Path ./Devolutions.CIEM -NuGetApiKey $apiKey -Repository PSGallery
```

### Installation by Users

1. PSU Admin Console > Platform > Gallery
2. Search "Devolutions.CIEM"
3. Click Install

### Pros/Cons

| Pros | Cons |
|------|------|
| Automatic distribution | Public visibility |
| Built-in version management | ~1 hour sync delay |
| Easy user installation | Requires PS Gallery account |
| Update notifications (v5.5+) | |

---

## 6. Environment Startup Scripts

Install modules dynamically when PSU environment starts.

### Environment Configuration

```powershell
# .universal/environments.ps1
New-PSUEnvironment -Name 'CIEM' `
    -Path '/opt/microsoft/powershell/7/pwsh' `
    -StartupScript 'ciem-startup.ps1' `
    -Modules @('Az.Accounts', 'Az.Resources')
```

### Startup Script

```powershell
# ciem-startup.ps1
$modulesPath = '/home/data/UniversalAutomation/Repository/Modules'

if (-not (Test-Path "$modulesPath/Devolutions.CIEM")) {
    Write-Host "Installing Devolutions.CIEM module..."
    Save-Module -Name Devolutions.CIEM -Path $modulesPath -Force
}

Import-Module Devolutions.CIEM -Force
```

### Initialize Script (Pre-Configuration)

```powershell
# .universal/initialize.ps1
# Runs before PSU configuration loads
$modulesPath = '/home/data/UniversalAutomation/Repository/Modules'

if (-not (Test-Path "$modulesPath/Devolutions.CIEM")) {
    Save-Module -Name Devolutions.CIEM -Path $modulesPath -Force
}
```

### Pros/Cons

| Pros | Cons |
|------|------|
| Dynamic installation | Startup latency |
| No manual intervention | Requires Gallery access |
| Self-healing | Network dependency |

---

## 7. Root Module Configuration

Define entire PSU configuration as a module with dependencies.

### Module Structure

```
Devolutions.CIEM.PSU/
├── Devolutions.CIEM.PSU.psd1
├── Devolutions.CIEM.PSU.psm1
└── .universal/
    ├── dashboards.ps1
    ├── scripts.ps1
    ├── endpoints.ps1
    └── environments.ps1
```

### Manifest with Dependencies

```powershell
# Devolutions.CIEM.PSU.psd1
@{
    RootModule = 'Devolutions.CIEM.PSU.psm1'
    ModuleVersion = '1.0.0'
    Description = 'Devolutions CIEM for PowerShell Universal'

    RequiredModules = @(
        'Devolutions.CIEM',
        'Az.Accounts',
        'Az.Resources'
    )

    PrivateData = @{
        PSData = @{
            Tags = @('PowerShellUniversal')
        }
    }
}
```

### Configure PSU to Use Root Module

```powershell
# Via appsettings.json
{
    "RootModule": "Devolutions.CIEM.PSU",
    "RootModuleVersion": "1.0.0"
}

# Or environment variable
RootModule=Devolutions.CIEM.PSU
RootModuleVersion=1.0.0
```

### Pros/Cons

| Pros | Cons |
|------|------|
| Complete app distribution | Complex module structure |
| Dependencies auto-resolved | Read-only resources in PSU |
| Publishable to PS Gallery | Requires versioning discipline |

---

## Recommended Approach for This Project

Given the constraints (no SQL database, Azure App Service, need to bundle module):

### For Development/Testing

**Use Kudu ZIP Upload** - Simple, scriptable, no SQL required

```powershell
# In Deploy-PSUApp.ps1
# 1. Upload module via Kudu ZIP API
# 2. Update app content via REST API
```

### For Production Distribution

**Publish to PSU Gallery** - Users install via Admin Console

1. Add `PowerShellUniversal` tag to module manifest
2. Publish Devolutions.CIEM to PowerShell Gallery
3. Users discover and install via PSU Gallery UI

### For Fully Automated CI/CD

**Custom Container Image** - Most reproducible

1. Build Docker image with module pre-installed
2. Push to Azure Container Registry
3. Update App Service container reference

---

## Current Deploy Script Status

The `Deploy-PSUApp.ps1` script currently uses deployment packages, which fail to apply without SQL. It should be updated to use one of:

1. **Kudu ZIP API** for module upload + REST API for app content
2. **Direct REST API** for app content only (current workaround)

See GitHub issue tracking this: [TODO: Create issue]

---

---

## Publishing to PSU Gallery (Marketplace)

This section covers how to publish Devolutions.CIEM to the PSU Gallery so users can install it directly from the PSU Admin Console.

### PSU Gallery vs Marketplace

- **"Gallery"** is the current term in PSU v5
- **"Marketplace"** was used in v3/v4
- In v5.2+, the Gallery connects directly to **PowerShell Gallery** and discovers modules tagged with `PowerShellUniversal`

### How It Works

1. Publish module to **PowerShell Gallery** with `PowerShellUniversal` tag
2. PSU syncs with PowerShell Gallery (cached for 5 minutes)
3. Module appears in PSU Admin Console > Platform > Gallery
4. Users click Install to download to `{Repository}/Modules/`

### Module Structure for PSU Apps

```
Devolutions.CIEM.PSUApp/
├── .universal/
│   └── dashboards.ps1          # PSU App registration
├── pages/
│   ├── Dashboard.ps1
│   ├── Findings.ps1
│   ├── Scan.ps1
│   └── Config.ps1
├── Devolutions.CIEM.PSUApp.psd1   # Module manifest
├── Devolutions.CIEM.PSUApp.psm1   # Module script
└── README.md
```

### Module Manifest for Gallery

```powershell
# Devolutions.CIEM.PSUApp.psd1
@{
    RootModule = 'Devolutions.CIEM.PSUApp.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    Author = 'Devolutions'
    CompanyName = 'Devolutions Inc.'
    Description = 'Cloud Infrastructure Entitlement Management app for PowerShell Universal'

    RequiredModules = @('Devolutions.CIEM')

    # Include .universal folder
    FileList = @('.universal/dashboards.ps1')

    PrivateData = @{
        PSData = @{
            # REQUIRED for PSU Gallery discovery
            Tags = @('PowerShellUniversal', 'app', 'CIEM', 'Security', 'Azure', 'AWS', 'Identity')

            LicenseUri = 'https://github.com/Devolutions/Devolutions-CIEM/blob/main/LICENSE'
            ProjectUri = 'https://github.com/Devolutions/Devolutions-CIEM'
            IconUri = 'https://devolutions.net/images/ciem-icon.png'

            # Display name in PSU Gallery
            DisplayName = 'Devolutions CIEM'
        }
    }
}
```

### The `.universal/dashboards.ps1` File

```powershell
# Registers the app with PSU
New-PSUApp -Name 'Devolutions CIEM' `
    -BaseUrl '/ciem' `
    -FilePath 'pages/Dashboard.ps1' `
    -Description 'Cloud Infrastructure Entitlement Management' `
    -AutoDeploy
```

### Required Tags

| Tag | Purpose |
|-----|---------|
| `PowerShellUniversal` | **Required** - Makes module discoverable in PSU Gallery |
| `app` | Categorizes as containing an App/Dashboard |

### Publishing to PowerShell Gallery

```powershell
# 1. Test manifest
Test-ModuleManifest -Path ./Devolutions.CIEM.PSUApp/Devolutions.CIEM.PSUApp.psd1

# 2. Publish core module first (if using Option B)
Publish-Module -Path ./Devolutions.CIEM -NuGetApiKey $apiKey

# 3. Publish PSU app module
Publish-Module -Path ./Devolutions.CIEM.PSUApp -NuGetApiKey $apiKey

# Module appears in PSU Gallery within ~5 minutes
```

### Examples of Published PSU Apps

| Module | Structure |
|--------|-----------|
| [PowerShellUniversal.Apps.ActiveDirectory](https://www.powershellgallery.com/packages/PowerShellUniversal.Apps.ActiveDirectory) | Self-contained |
| [PowerShellUniversal.Apps.NetworkUtilities](https://www.powershellgallery.com/packages/PowerShellUniversal.Apps.NetworkUtilities) | Self-contained |
| [PowerShellUniversal.Apps.Pester](https://www.powershellgallery.com/packages/PowerShellUniversal.Apps.Pester) | Self-contained |

**Source code:** [github.com/ironmansoftware/gallery](https://github.com/ironmansoftware/gallery)

### Recommended Architecture for Devolutions.CIEM

Given the business requirement (lead gen for Devolutions PAM):

**Option A (Single Module)** is recommended because:
1. Users get everything with one install
2. No dependency confusion
3. The module can still export check functions for CLI use

```powershell
# Devolutions.CIEM.psd1
@{
    # Core module - contains checks AND PSU app
    RootModule = 'Devolutions.CIEM.psm1'

    # Export check functions for CLI users
    FunctionsToExport = @(
        'Invoke-CIEMScan',
        'Get-CIEMCheck',
        'Test-CIEMCheck'
    )

    # PSU resources in .universal/ loaded automatically
    PrivateData = @{
        PSData = @{
            Tags = @('PowerShellUniversal', 'app', 'CIEM', 'Security')
        }
    }
}
```

---

## References

- [PSU Azure Hosting](https://docs.powershelluniversal.com/config/hosting/azure)
- [PSU Modules](https://docs.powershelluniversal.com/platform/modules)
- [PSU Deployments](https://docs.powershelluniversal.com/config/deployments)
- [PSU Gallery](https://docs.powershelluniversal.com/platform/library)
- [PSU Environments](https://docs.powershelluniversal.com/config/environments)
- [Kudu REST API](https://github.com/projectkudu/kudu/wiki/REST-API)
- [PSU Management API](https://docs.powershelluniversal.com/config/management-api)
- [Ironman Software Gallery Examples](https://github.com/ironmansoftware/gallery)
- [PSU v5.2 Release Notes](https://blog.ironmansoftware.com/powershell-universal-v52/)
