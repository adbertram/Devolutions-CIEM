# Devolutions CIEM - PowerShell Universal App

This directory contains the PowerShell Universal v5 app for Devolutions CIEM (Cloud Infrastructure Entitlement Management).

## Directory Structure

```
psu-app/
├── .universal/              # PSU configuration files
│   ├── dashboards.ps1       # App registration
│   ├── environments.ps1     # PowerShell environment definitions
│   └── settings.ps1         # Server settings
├── apps/
│   └── DevolutionsCIEM/
│       └── app.ps1          # Main app code
├── Deploy-PSUApp.ps1        # Deployment script
└── README.md                # This file
```

## App Features

The CIEM dashboard app includes:

1. **Dashboard Page** (`/ciem`)
   - Summary cards showing finding counts
   - Severity distribution pie chart
   - Service distribution bar chart
   - Recent critical findings table

2. **Findings Page** (`/ciem/findings`)
   - Interactive data grid with all findings
   - Filtering and search capabilities
   - Expandable row details with remediation info
   - Link to Devolutions PAM for remediation

3. **Scan Page** (`/ciem/scan`)
   - Scan configuration form
   - Provider selection (Azure, AWS coming soon)
   - Scan history table

4. **About Page** (`/ciem/about`)
   - Module information
   - Feature list
   - Links to Devolutions resources

## Deployment Options

### Option 1: Manual Deployment via Admin Console (Recommended for PoC)

1. Navigate to the PSU admin console: https://devolutions-ciem-psu.azurewebsites.net/admin
2. Log in with your admin credentials
3. Go to **Apps** > **Apps**
4. Click **Create New App**
5. Enter:
   - Name: `DevolutionsCIEM`
   - Base URL: `/ciem`
6. Click **Create**
7. In the app editor, paste the contents of `apps/DevolutionsCIEM/app.ps1`
8. Click **Save**
9. Click the globe icon to view the app

### Option 2: File Upload via Kudu/SSH

For Azure Container Web Apps, you can upload files directly:

```bash
# Connect to Kudu console
# https://devolutions-ciem-psu.scm.azurewebsites.net/newui/kududebug

# Navigate to repository
cd /home/data/PowerShellUniversal/Repository

# Create directories
mkdir -p apps/DevolutionsCIEM
mkdir -p .universal

# Upload files (drag and drop in Kudu, or use SCP)
```

### Option 3: API Deployment

Use the Management API with an App Token:

```powershell
# First, create an App Token in PSU Admin Console:
# Settings > Security > App Tokens > Create

# Then run the deployment script
$AppToken = 'your-app-token-here'
./Deploy-PSUApp.ps1 -AppToken $AppToken
```

### Option 4: Git Integration

If Git sync is configured on your PSU instance:

1. Push this `psu-app` directory contents to your Git repository
2. PSU will automatically pull and deploy the changes

## Configuration

### Environment Variables (Azure)

Ensure these are set in your Azure Web App Configuration:

| Variable | Value |
|----------|-------|
| `WEBSITES_ENABLE_APP_SERVICE_STORAGE` | `true` |
| `ASPNETCORE_FORWARDEDHEADERS_ENABLED` | `true` |
| `Jwt__SigningKey` | (secure key) |
| `Api__Url` | `https://devolutions-ciem-psu.azurewebsites.net` |

### App Token Creation

1. Navigate to **Settings** > **Security** > **App Tokens**
2. Click **Create**
3. Name: `CIEM Deployment`
4. Role: `Administrator`
5. Copy the token (shown only once)

## Testing the App

After deployment:

1. Visit: https://devolutions-ciem-psu.azurewebsites.net/ciem
2. You should see the CIEM Dashboard with sample findings
3. Navigate through:
   - Dashboard (summary view)
   - Findings (detailed data grid)
   - Scan (configuration form)
   - About (information page)

## Troubleshooting

### App Not Loading

1. Check PSU logs: **Settings** > **General** > **View Logs**
2. Verify the app is started: **Apps** > **Apps** > Check status
3. Check PowerShell errors in the app Info panel

### API Errors

```powershell
# Test API connectivity
$token = 'your-token'
$headers = @{ Authorization = "Bearer $token" }
Invoke-RestMethod -Uri "https://devolutions-ciem-psu.azurewebsites.net/api/v1/app" -Headers $headers
```

### Container Issues

```bash
# View container logs
az webapp log tail --resource-group devolutions-ciem-rg --name devolutions-ciem-psu

# Restart the container
az webapp restart --resource-group devolutions-ciem-rg --name devolutions-ciem-psu
```

## Next Steps

To integrate with the actual CIEM module:

1. Deploy the `Devolutions.CIEM` module to PSU:
   - Upload to `Repository/Modules/` or
   - Install from PSGallery when published

2. Update `app.ps1` to call `Invoke-CIEMScan` instead of using sample data

3. Configure Azure authentication (Managed Identity recommended)

## References

- [PSU v5 Documentation](../../prowler/docs/psu-docs/)
- [Devolutions.CIEM Module](../Devolutions.CIEM/)
- [Architecture Planning](../docs/architecture-planning.md)
