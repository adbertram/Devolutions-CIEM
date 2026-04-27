# Test Workflow - Playwright UI Testing

<required_reading>
Before testing, understand the page structure by reviewing `./Devolutions.CIEM/Devolutions.CIEM.psm1` (search for the page you're testing).
</required_reading>

<process>
## Step 1: Navigate to the page

```
mcp__playwright__browser_navigate to:
https://devolutions-ciem-psu.azurewebsites.net/ciem/ciem/[page]
```

Pages: config, findings, scan, about (or just /ciem/ciem/ for dashboard)

## Step 2: Take a snapshot

Use `mcp__playwright__browser_snapshot` to see the page's accessibility tree. This shows all interactive elements with their `ref` IDs.

## Step 3: Interact with elements

Use the `ref` from the snapshot:
- `mcp__playwright__browser_click` - Click buttons, links
- `mcp__playwright__browser_fill_form` - Fill multiple form fields
- `mcp__playwright__browser_type` - Type into a specific field

## Step 4: Verify results

Take another snapshot after interactions to verify:
- Expected elements appear
- Toast messages show success/error
- Form values are correct

## Common Test Scenarios

**Config Page - Save credentials:**
1. Navigate to /ciem/ciem/config
2. Fill Tenant ID, Client ID, Client Secret fields
3. Click "Save Configuration" button
4. Verify success toast appears

**Config Page - Verify saved values:**
1. Navigate to /ciem/ciem/config
2. Snapshot the page
3. Check that Tenant ID and Client ID show stored values
4. Client Secret should show "********" if a secret is stored
</process>

<success_criteria>
- Page loads without "Page Not Found" error
- Expected elements are present in snapshot
- Interactions produce expected results
- No JavaScript errors in console
</success_criteria>
