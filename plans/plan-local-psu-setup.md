# Implementation Plan: Local PSU Setup

## Summary
Set up a local PowerShell Universal v5.5.4 instance via Docker to replace the slow Azure-hosted instance for faster development iteration.

The approach uses the ARM64-compatible PSU Docker image with volume mapping to mirror Azure's filesystem structure, updates the .env file to support both production (Azure) and local PSU URLs, and modifies existing scripts and PowerShell cmdlets to support a `--local` flag for quick local testing.

## Why This Approach

**Simplest solution:**
- Uses existing Docker infrastructure (no native macOS installation)
- Single setup script handles container lifecycle
- Existing PSUniversal.psm1 cmdlets work without modification (Connect-PSU accepts any URL)
- Local PSU uses SQLite (default) - no additional database setup required

**Alternatives considered:**
- Native macOS installation: Rejected - requires additional dependencies, harder to reset/recreate
- Running PSU in Azure Container Instance: Rejected - still has cold start issues, costs money
- Docker Compose: Rejected - overkill for single container

## Prerequisites

**Docker:**
- Docker Desktop installed and running
- ARM64 support verified (macOS Apple Silicon)

**Existing tools:**
- Az CLI (for Azure PSU management if needed)
- PowerShell 7.4+ (already installed - v7.6.0-preview.6)
- jq (for JSON parsing in shell scripts)

## Implementation Steps

### Step 1: Create local-psu directory structure
**Action:** Create directory for PSU data with same structure as Azure
**Verify:** Directory exists at project root

```bash
mkdir -p local-psu/Repository/{.universal,Modules,dashboards}
mkdir -p local-psu/LogFiles
```

**Why:** Docker volume mapping requires pre-existing directories. Mirroring Azure structure (`/home/Repository`, `/home/LogFiles`) ensures compatibility.

### Step 2: Update .gitignore
**File:** `.gitignore`
**Action:** Add local PSU directories to gitignore
**Verify:** `git status` shows local-psu/ as untracked

Add these lines after line 173:
```
# Local PSU instance
local-psu/
```

### Step 3: Update .env with dual PSU URLs
**File:** `.env`
**Action:** Rename `PSU_URL` to `PROD_PSU_URL` and add `LOCAL_PSU_URL`
**Verify:** `.env` contains both URLs

Replace:
```
PSU_URL=https://devolutions-ciem-psu.azurewebsites.net
PSU_TOKEN=<existing-token>
```

With:
```
# PSU Configuration
PROD_PSU_URL=https://devolutions-ciem-psu.azurewebsites.net
LOCAL_PSU_URL=http://localhost:5000

# Production PSU token
PSU_TOKEN=<existing-token>
```

**Note:** Local PSU runs in development mode (no auth), so no LOCAL_PSU_TOKEN needed.

### Step 4: Update PSUniversal.psm1 to support dual URLs
**File:** `scripts/PSUniversal.psm1`
**Action:** Update Connect-PSU to read `PROD_PSU_URL` by default, add `-Local` switch to use `LOCAL_PSU_URL`
**Verify:** `pwsh -c 'Import-Module ./scripts/PSUniversal.psm1; Connect-PSU -Local -Verbose'` connects to localhost

Changes at line 98-100 (in the switch statement):
```powershell
'PSU_URL' {
    if (-not $Url) { $Url = $value }
}
```

Becomes:
```powershell
'PROD_PSU_URL' {
    if (-not $Url) { $Url = $value }
}
'LOCAL_PSU_URL' {
    # Store for -Local switch
}
```

Then add `-Local` switch parameter at line 50-65 and update logic after .env parsing to:
```powershell
[Parameter()]
[switch]$Local
```

And after .env parsing (around line 110):
```powershell
# If -Local switch is set, override Url with LOCAL_PSU_URL from .env
if ($Local -and $envVars.ContainsKey('LOCAL_PSU_URL')) {
    $Url = $envVars['LOCAL_PSU_URL']
    Write-Verbose "Using local PSU URL: $Url"
}
```

**Implementation detail:** Store .env variables in a hashtable during parsing, then check for `LOCAL_PSU_URL` key if `-Local` is specified.

### Step 5: Create setup-local-psu.sh script
**File:** `scripts/setup-local-psu.sh`
**Action:** Create script to manage local PSU Docker container
**Verify:** `./scripts/setup-local-psu.sh status` shows container state

Script structure:
```bash
#!/bin/bash
set -euo pipefail

CONTAINER_NAME="devolutions-ciem-psu-local"
IMAGE="ironmansoftware/universal:5.5.4-ubuntu-latest-arm64v8"
PORT=5000
DATA_DIR="$(cd "$(dirname "$0")/.." && pwd)/local-psu"

start() {
    # Check if already running
    # Pull image if needed
    # Run container with volume mounts
    docker run -d \
        --name "$CONTAINER_NAME" \
        -p "$PORT:5000" \
        -v "$DATA_DIR:/home" \
        -e "Data__RepositoryPath=/home/Repository" \
        -e "Data__ConnectionString=/home/database.db" \
        -e "UnattendedInstall=true" \
        "$IMAGE"
}

stop() {
    docker stop "$CONTAINER_NAME" || true
}

remove() {
    stop
    docker rm "$CONTAINER_NAME" || true
}

reset() {
    # Stop/remove container and wipe data directory
}

logs() {
    docker logs "$CONTAINER_NAME" "${@:-}"
}

status() {
    # Check if container exists and is running
    # Show PSU health endpoint status
}

case "${1:-}" in
    start|stop|remove|reset|logs|status) "$1" "${@:2}" ;;
    *) echo "Usage: $0 {start|stop|remove|reset|logs|status}" ;;
esac
```

**Environment variables:**
- `UnattendedInstall=true` - Skip first-time setup wizard (creates default admin user)
- `Data__RepositoryPath=/home/Repository` - Use volume-mapped directory
- `Data__ConnectionString=/home/database.db` - Use SQLite in volume

### CHECKPOINT: Verify local PSU starts and is accessible
**Run:** `./scripts/setup-local-psu.sh start && sleep 10 && curl -s http://localhost:5000/api/v1/alive`
**Expected:** `{"alive": true, "loading": false}` after PSU finishes loading (may take 30-60 seconds)

### Step 6: Add -LocalOnly switch to Publish-PSUModule
**File:** `scripts/PSUniversal.psm1`
**Action:** Add `-LocalOnly` switch to skip PSGallery publish and only import to local PSU
**Verify:** `Publish-PSUModule -ModulePath ./Devolutions.CIEM -LocalOnly` imports without publishing

Find the Publish-PSUModule function (search for `function Publish-PSUModule`) and:

1. Add parameter around the param block:
```powershell
[Parameter()]
[switch]$LocalOnly
```

2. Add logic after parameter validation to skip PSGallery steps:
```powershell
if ($LocalOnly) {
    Write-Host "LocalOnly mode: Skipping version bump and PSGallery publish"
    # Skip directly to Install-PSUModule
} else {
    # Existing PSGallery publish workflow
}
```

3. Update the Connect-PSU call to use `-Local`:
```powershell
if ($LocalOnly) {
    Connect-PSU -Local
} else {
    Connect-PSU  # Uses PROD_PSU_URL
}
```

**Why:** During development, you often want to test module changes locally without publishing to PSGallery. This workflow allows `Publish-PSUModule -LocalOnly` to copy the module to `local-psu/Repository/Modules/` and import it to local PSU.

### Step 7: Update azure_psu_file_manager.sh with --local flag
**File:** `scripts/azure_psu_file_manager.sh`
**Action:** Add `--local` flag to support local PSU filesystem operations
**Verify:** `./scripts/azure_psu_file_manager.sh --local list` shows local PSU directory structure

Changes:

1. Add flag parsing at top (before command switch):
```bash
LOCAL_MODE=false
if [[ "${1:-}" == "--local" ]]; then
    LOCAL_MODE=true
    shift
fi
```

2. Update functions to check `$LOCAL_MODE`:
```bash
list_files() {
    local path="${1:-}"

    if [[ "$LOCAL_MODE" == "true" ]]; then
        # Use local filesystem
        ls -la "$DATA_DIR/$path" 2>/dev/null || echo "Directory not found: $DATA_DIR/$path"
    else
        # Existing Azure Kudu API logic
        local creds
        creds=$(get_credentials)
        # ... rest of Azure logic
    fi
}
```

3. Apply same pattern to `read_file()` and `exec_cmd()`:
- Local mode: `cat "$DATA_DIR/$path"`
- Local mode exec: Direct bash execution instead of Kudu API

**Note:** The script header variables should define `DATA_DIR`:
```bash
DATA_DIR="$(cd "$(dirname "$0")/.." && pwd)/local-psu"
```

### Step 8: Update invoke_command_in_azure_webapp.sh with --local flag
**File:** `scripts/invoke_command_in_azure_webapp.sh`
**Action:** Add `--local` flag to support local PSU operations
**Verify:** `./scripts/invoke_command_in_azure_webapp.sh --local preset health` shows local PSU health

Similar pattern to Step 7:

1. Add flag parsing
2. Update `run()` function to execute commands locally:
```bash
run() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        # Execute command locally (in PSU container via docker exec)
        docker exec devolutions-ciem-psu-local bash -c "$1"
    else
        # Existing Azure Kudu API logic
    fi
}
```

3. Update `api()` function to use localhost URL:
```bash
api() {
    local endpoint="$1"
    local base_url

    if [[ "$LOCAL_MODE" == "true" ]]; then
        base_url="http://localhost:5000"
        # No auth needed for local (dev mode)
        curl -s "$base_url$endpoint"
    else
        # Existing Azure API logic with PSU_TOKEN
    fi
}
```

4. Update presets to work with both modes (health, version, apps, etc.)

### Step 9: Update download-psu-logs.sh with --local flag
**File:** `scripts/download-psu-logs.sh`
**Action:** Add `--local` flag to download logs from local PSU
**Verify:** `./scripts/download-psu-logs.sh --local` downloads local PSU logs

Changes:

1. Add flag parsing
2. Update log sources to use Docker logs and local filesystem:
```bash
if [[ "$LOCAL_MODE" == "true" ]]; then
    # Docker container logs
    docker logs devolutions-ciem-psu-local > "$output_file"

    # Append filesystem logs
    cat "$DATA_DIR/LogFiles/"*.log >> "$output_file" 2>/dev/null || true
else
    # Existing Azure logic (database, Docker, API)
fi
```

## Testing Strategy

**Initial setup verification:**
```bash
# Start local PSU
./scripts/setup-local-psu.sh start

# Wait for PSU to finish loading
while [[ $(curl -s http://localhost:5000/api/v1/alive | jq -r '.loading') == "true" ]]; do
    echo "PSU loading..."
    sleep 5
done

# Verify web UI accessible
open http://localhost:5000

# Verify PowerShell connection
pwsh -c 'Import-Module ./scripts/PSUniversal.psm1; Connect-PSU -Local; Get-PSUModule'
```

**Module publishing workflow:**
```bash
# Test local-only publish
pwsh -c 'Import-Module ./scripts/PSUniversal.psm1; Publish-PSUModule -ModulePath ./Devolutions.CIEM -LocalOnly'

# Verify module imported
./scripts/azure_psu_file_manager.sh --local list Repository/Modules
```

**Script flag verification:**
```bash
# Test file manager
./scripts/azure_psu_file_manager.sh --local list
./scripts/azure_psu_file_manager.sh --local read Repository/.universal/dashboards.ps1

# Test command runner
./scripts/invoke_command_in_azure_webapp.sh --local preset health
./scripts/invoke_command_in_azure_webapp.sh --local run "ls -la /home/Repository"

# Test log downloader
./scripts/download-psu-logs.sh --local
```

**Production workflow unchanged:**
```bash
# Verify production workflow still works (no --local flag)
pwsh -c 'Import-Module ./scripts/PSUniversal.psm1; Connect-PSU; Get-PSUModule'
./scripts/azure_psu_file_manager.sh list Repository/Modules
```

## What's NOT Included

**Deferred complexity:**
- No HTTPS/SSL for local instance (dev mode only)
- No authentication setup (using UnattendedInstall mode)
- No auto-start on system boot (manual start only)
- No backup/restore workflow (easy to reset from scratch)
- No local PSU version management (locked to 5.5.4)

**Future enhancements:**
- Docker Compose for multi-container setup (if we add local SQL Server later)
- Sync workflow to copy modules from Azure to local PSU
- Local PSU upgrade script (bump version in setup-local-psu.sh)

## Implementation Corrections

### Correction 1 - 2026-02-09
**Step:** 5 (setup-local-psu.sh)
**Issue:** PSU Docker images labeled "arm64v8" are ALL mislabeled - they contain amd64 binaries (verified via ELF header). Port 5000 is used by macOS AirPlay.
**Fix:** Switched from Docker to native macOS binary. Downloaded `Universal.osx-arm64.2026.1.0.zip` from blob storage. Port changed to 5001.
**Reason:** Native ARM64 binary provides full performance. Docker images are all amd64 (confirmed across 5.5.4, 5.6.13, and 2026.1.0).

### Correction 2 - 2026-02-09
**Step:** 5 (setup-local-psu.sh)
**Issue:** PSU binary was unsigned, macOS killed it with SIGKILL on first run attempt.
**Fix:** Added ad-hoc code signing (`codesign -s -`) for the binary and all .dylib files during install.

### Correction 3 - 2026-02-09
**Step:** 5 (appsettings.json)
**Issue:** Kestrel endpoint config in appsettings.json hardcoded port 5000. Env var override key case sensitivity (`HTTP` vs `Http`) caused it to be ignored.
**Fix:** Updated appsettings.json Kestrel endpoint to port 5001. Script uses `Kestrel__Endpoints__HTTP__Url` (uppercase HTTP).

### Correction 4 - 2026-02-09
**Step:** 5 (status command)
**Issue:** `status` command ran `Universal.Server --version` which launched a full PSU server process instead of printing version.
**Fix:** Changed to display `$PSU_VERSION` variable instead of running the binary.

## Success Criteria

- [ ] PSU web UI accessible at http://localhost:5001
- [ ] `Connect-PSU -Local` connects successfully from PowerShell
- [ ] `setup-local-psu.sh start` starts container without errors
- [ ] Volume-mapped directories visible in container filesystem
- [ ] `Publish-PSUModule -LocalOnly` imports module to local PSU
- [ ] All shell scripts support `--local` flag
- [ ] Production workflows unchanged (no `--local` flag = Azure)
- [ ] `local-psu/` directory ignored by git
