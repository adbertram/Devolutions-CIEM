const { execFileSync, execSync } = require('child_process');
const { testConfig } = require('./test-config');

const PSU_STATUS = { Queued: 0, Running: 1, Completed: 2, Failed: 3, Canceled: 5, TimedOut: 9, Warning: 10, WarningOutput: 11 };
const PSU_STATUS_NAMES = Object.fromEntries(Object.entries(PSU_STATUS).map(([k, v]) => [v, k]));
const PSU_TERMINAL_STATUSES = [PSU_STATUS.Completed, PSU_STATUS.Failed, PSU_STATUS.Canceled, PSU_STATUS.TimedOut, PSU_STATUS.Warning, PSU_STATUS.WarningOutput];
const LONG_RUNNING_ATTACK_PATH_RULE_ID = 'e2e-long-running-remediation';
const LONG_RUNNING_ATTACK_PATH_SCRIPT_NAME = 'e2e-long-running-remediation';
const LONG_RUNNING_ATTACK_PATH_REMEDIATION_SCRIPT_PATH = `modules/Devolutions.CIEM.Graph/Data/attack_path_remediation_scripts/${LONG_RUNNING_ATTACK_PATH_SCRIPT_NAME}.ps1`;

async function isPSUReady() {
  try {
    const url = `${testConfig.urls.psu}${testConfig.psu.healthEndpoint}`;
    const response = await fetch(url);
    if (!response.ok) return false;
    const data = await response.json();
    return data.loading === false;
  } catch {
    return false;
  }
}

function startPSU() {
  assertPublishPointDatabaseAccess();
  const sshHost = testConfig.environment.publishPointSsh;
  console.log('[psu] Starting PSU server via launchctl...');
  execSync(`ssh ${sshHost} "sudo launchctl kickstart -k system/com.psu.server"`, {
    stdio: 'inherit',
    timeout: 30000
  });
}

async function waitForPSU(timeoutMs = testConfig.timeouts.serverStart) {
  const start = Date.now();
  const pollInterval = 2000;
  console.log(`[psu] Waiting for PSU to be ready (timeout: ${timeoutMs / 1000}s)...`);

  while (Date.now() - start < timeoutMs) {
    if (await isPSUReady()) {
      console.log(`[psu] PSU is ready (took ${Math.round((Date.now() - start) / 1000)}s)`);
      return;
    }
    await new Promise(r => setTimeout(r, pollInterval));
  }

  throw new Error(`PSU server did not become ready within ${timeoutMs / 1000}s`);
}

/**
 * Get the local PSU app token from the LOCAL_PSU_TOKEN environment variable.
 */
function getPSUToken() {
  return testConfig.psu.token;
}

/**
 * Get PSU API headers with auth token.
 */
function getPSUHeaders() {
  const token = getPSUToken();
  return {
    'Authorization': `Bearer ${token}`,
    'Accept': 'application/json',
    'Content-Type': 'application/json'
  };
}

/**
 * Cancel all running and queued PSU jobs.
 * Returns { cancelled: number, running: number, queued: number }.
 */
async function cancelRunningPSUJobs() {
  const baseUrl = testConfig.urls.psu;
  const headers = getPSUHeaders();

  // PSU job API returns paginated { page: [...], total: N } — filter by status
  const runningRes = await fetch(`${baseUrl}/api/v1/job?status=1&take=100`, { headers });
  const runningData = await runningRes.json().catch(() => ({ page: [] }));
  const running = runningData.page || [];
  const queuedRes = await fetch(`${baseUrl}/api/v1/job?status=0&take=100`, { headers });
  const queuedData = await queuedRes.json().catch(() => ({ page: [] }));
  const queued = queuedData.page || [];

  const toCancel = [...running, ...queued];
  let cancelled = 0;
  for (const job of toCancel) {
    await fetch(`${baseUrl}/api/v1/job/${job.id}/cancel`, { method: 'POST', headers }).catch(() => {});
    cancelled++;
  }

  return { cancelled, running: running.length, queued: queued.length };
}

/**
 * Run a PowerShell command inside PSU via the CIEMExecutor script.
 * Returns a result object with job metadata and output — caller is responsible for assertions.
 *
 * @returns {{ jobId: number, status: string, statusCode: number, startTime: string, endTime: string, output: object[], pipelineOutput: any }}
 */
async function runPSUCommand(command, timeoutMs = 30000) {
  const baseUrl = testConfig.urls.psu;
  const headers = getPSUHeaders();

  // Find or create the executor script
  const scriptsRes = await fetch(`${baseUrl}/api/v1/script`, { headers });
  const scripts = await scriptsRes.json();
  let executor = scripts.find(s => s.name === 'CIEMExecutor.ps1');

  if (!executor) {
    const createRes = await fetch(`${baseUrl}/api/v1/script`, {
      method: 'POST', headers,
      body: JSON.stringify({
        name: 'CIEMExecutor.ps1',
        fullPath: 'CIEMExecutor.ps1',
        content: 'param([string]$ScriptContent)\n& ([scriptblock]::Create($ScriptContent))',
        description: 'Persistent executor for E2E tests',
        maxHistory: 100
      })
    });
    executor = await createRes.json();
  }

  // Invoke the command
  const encoded = encodeURIComponent(command);
  const invokeRes = await fetch(`${baseUrl}/api/v1/script/${executor.id}?ScriptContent=${encoded}`, {
    method: 'POST', headers, body: '{}'
  });
  if (!invokeRes.ok) {
    return { jobId: null, status: 'InvocationFailed', statusCode: -1, httpStatus: invokeRes.status, error: invokeRes.statusText };
  }
  const jobResponse = await invokeRes.json();
  const jobId = typeof jobResponse === 'number' ? jobResponse : jobResponse.id;

  // Poll for terminal status
  const start = Date.now();
  let job = null;
  while (Date.now() - start < timeoutMs) {
    const jobRes = await fetch(`${baseUrl}/api/v1/job/${jobId}`, { headers });
    job = await jobRes.json();
    if (PSU_TERMINAL_STATUSES.includes(job.status)) break;
    await new Promise(r => setTimeout(r, 500));
  }

  if (!job || !PSU_TERMINAL_STATUSES.includes(job.status)) {
    return { jobId, status: 'TimedOut', statusCode: -1, elapsedMs: Date.now() - start };
  }

  // Fetch output and pipeline output
  const outputRes = await fetch(`${baseUrl}/api/v1/job/${jobId}/output`, { headers });
  const output = await outputRes.json().catch(() => []);

  const pipelineRes = await fetch(`${baseUrl}/api/v1/job/${jobId}/pipelineOutput`, { headers });
  const pipeline = await pipelineRes.json().catch(() => null);
  let pipelineOutput = null;
  if (pipeline && pipeline.length > 0 && pipeline[0].jsonData) {
    pipelineOutput = JSON.parse(pipeline[0].jsonData);
  }

  return {
    jobId,
    status: PSU_STATUS_NAMES[job.status] || `Unknown(${job.status})`,
    statusCode: job.status,
    startTime: job.startTime,
    endTime: job.endTime,
    output,
    pipelineOutput
  };
}

function curlJson(args, timeoutMs = 30000) {
  const output = execFileSync('curl', ['-sS', '--fail', ...args], {
    encoding: 'utf8',
    timeout: timeoutMs,
    maxBuffer: 256 * 1024 * 1024
  }).trim();

  if (!output) return null;
  return JSON.parse(output);
}

function runPSUCommandSync(command, timeoutMs = 30000) {
  const baseUrl = testConfig.urls.psu;
  const headers = getPSUHeaders();
  const headerArgs = Object.entries(headers).flatMap(([key, value]) => ['-H', `${key}: ${value}`]);

  const scripts = curlJson([...headerArgs, `${baseUrl}/api/v1/script`], timeoutMs);
  let executor = scripts.find(s => s.name === 'CIEMExecutor.ps1');

  if (!executor) {
    executor = curlJson([
      ...headerArgs,
      '-X', 'POST',
      '--data', JSON.stringify({
        name: 'CIEMExecutor.ps1',
        fullPath: 'CIEMExecutor.ps1',
        content: 'param([string]$ScriptContent)\n& ([scriptblock]::Create($ScriptContent))',
        description: 'Persistent executor for E2E tests',
        maxHistory: 100
      }),
      `${baseUrl}/api/v1/script`
    ], timeoutMs);
  }

  const jobResponse = curlJson([
    ...headerArgs,
    '-X', 'POST',
    '--data', '{}',
    `${baseUrl}/api/v1/script/${executor.id}?ScriptContent=${encodeURIComponent(command)}`
  ], timeoutMs);
  const jobId = typeof jobResponse === 'number' ? jobResponse : jobResponse.id;

  const start = Date.now();
  let job = null;
  while (Date.now() - start < timeoutMs) {
    job = curlJson([...headerArgs, `${baseUrl}/api/v1/job/${jobId}`], timeoutMs);
    if (PSU_TERMINAL_STATUSES.includes(job.status)) break;
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 500);
  }

  if (!job || !PSU_TERMINAL_STATUSES.includes(job.status)) {
    return { jobId, status: 'TimedOut', statusCode: -1, elapsedMs: Date.now() - start };
  }

  const output = curlJson([...headerArgs, `${baseUrl}/api/v1/job/${jobId}/output`], timeoutMs) || [];
  const pipeline = curlJson([...headerArgs, `${baseUrl}/api/v1/job/${jobId}/pipelineOutput`], timeoutMs) || null;
  let pipelineOutput = null;
  if (pipeline && pipeline.length > 0 && pipeline[0].jsonData) {
    pipelineOutput = JSON.parse(pipeline[0].jsonData);
  }

  return {
    jobId,
    status: PSU_STATUS_NAMES[job.status] || `Unknown(${job.status})`,
    statusCode: job.status,
    startTime: job.startTime,
    endTime: job.endTime,
    output,
    pipelineOutput
  };
}

function registerLongRunningAttackPathRemediationScript() {
  const command = `
    $relativeScriptPath = '${LONG_RUNNING_ATTACK_PATH_REMEDIATION_SCRIPT_PATH}'
    $module = Get-Module -ListAvailable -Name Devolutions.CIEM | Sort-Object Version -Descending | Select-Object -First 1
    if ($null -eq $module) {
      throw 'Cannot register E2E long-running attack path remediation script because Devolutions.CIEM is not installed.'
    }

    $moduleRoot = Split-Path -Path $module.Path -Parent
    $scriptPath = Join-Path $moduleRoot $relativeScriptPath
    New-Item -Path (Split-Path -Path $scriptPath -Parent) -ItemType Directory -Force | Out-Null
    $content = @'
<#
.SYNOPSIS
Remediates the attack path finding "{{PATTERN_NAME}}".

.DESCRIPTION
This E2E remediation fixture keeps the remediation job running long enough to verify
the close-warning dialog for an active attack path remediation execution.
#>

Write-Information 'E2E long-running attack path remediation started.' -InformationAction Continue
Start-Sleep -Seconds 60
Write-Information 'E2E long-running attack path remediation completed.' -InformationAction Continue
'@
    Set-Content -LiteralPath $scriptPath -Value $content -NoNewline -Encoding UTF8

    [pscustomobject]@{ Status = 'Registered'; Path = $scriptPath; RelativePath = $relativeScriptPath }
  `;
  const result = runPSUCommandSync(command, 30000);
  if (result.status !== 'Completed') {
    throw new Error(`Failed to register E2E long-running attack path remediation script: ${JSON.stringify(result)}`);
  }
  return result;
}

function removeLongRunningAttackPathRemediationScript() {
  const command = `
    $relativeScriptPath = '${LONG_RUNNING_ATTACK_PATH_REMEDIATION_SCRIPT_PATH}'
    $module = Get-Module -ListAvailable -Name Devolutions.CIEM | Sort-Object Version -Descending | Select-Object -First 1
    if ($null -eq $module) {
      [pscustomobject]@{ Status = 'Removed'; Removed = 0; RelativePath = $relativeScriptPath }
      return
    }

    $moduleRoot = Split-Path -Path $module.Path -Parent
    $scriptPath = Join-Path $moduleRoot $relativeScriptPath
    $removed = 0
    if (Test-Path -LiteralPath $scriptPath -PathType Leaf) {
      Remove-Item -LiteralPath $scriptPath -Force
      $removed = 1
    }

    [pscustomobject]@{ Status = 'Removed'; Path = $scriptPath; RelativePath = $relativeScriptPath; Removed = $removed }
  `;
  const result = runPSUCommandSync(command, 30000);
  if (result.status !== 'Completed') {
    throw new Error(`Failed to remove E2E long-running attack path remediation script: ${JSON.stringify(result)}`);
  }
  return result;
}

/**
 * Deactivate any active Azure auth profile. Returns the previously active profile ID (or null).
 * Caller should assert the result in the test.
 */
async function deactivateAzureAuthProfile() {
  const result = await runPSUCommand(`
    $profiles = @(Get-CIEMAzureAuthenticationProfile)
    $activeProfile = $profiles | Where-Object { [bool]$_.IsActive } | Select-Object -First 1
    if ($activeProfile) {
      $activeId = $activeProfile.Id
      $now = (Get-Date).ToString('o')
      $cacheProfiles = @(Get-PSUCache -Key 'CIEM:AuthProfiles:Azure' -ErrorAction SilentlyContinue)
      foreach ($p in $cacheProfiles) { $p.IsActive = $false; $p.UpdatedAt = $now }
      Set-PSUCache -Key 'CIEM:AuthProfiles:Azure' -Value $cacheProfiles -Persist
      $activeId
    } else {
      'none'
    }
  `);
  const data = result.pipelineOutput;
  if (data && data.length > 0) {
    const val = data[0].value;
    return { previousActiveId: val === 'none' ? null : val, result };
  }
  return { previousActiveId: null, result };
}

/**
 * Reactivate an Azure auth profile by ID.
 */
async function activateAzureAuthProfile(profileId) {
  return await runPSUCommand(`Set-CIEMAzureAuthenticationProfileActive -Id '${profileId}'`);
}

/**
 * Returns the count of active Azure auth profiles (0 or 1+).
 */
async function getActiveAzureAuthProfileCount() {
  const result = await runPSUCommand(`
    $profiles = @(Get-PSUCache -Key 'CIEM:AuthProfiles:Azure' -ErrorAction SilentlyContinue)
    @($profiles | Where-Object { [bool]$_.IsActive }).Count
  `);
  if (result.statusCode === -1) return { count: -1, result };
  const data = result.pipelineOutput;
  if (data && data.length > 0) {
    return { count: parseInt(data[0].value) || 0, result };
  }
  return { count: 0, result };
}

/**
 * Execute a PowerShell command inside PSU and return the parsed pipeline output.
 * Throws on non-terminal status or if the job has errors.
 * For commands that emit JSON via ConvertTo-Json, returns the parsed object/array.
 * For scalar values (counts, strings), returns the raw string.
 */
async function runPSUQuery(command, timeoutMs = 30000) {
  const result = await runPSUCommand(command, timeoutMs);
  if (result.statusCode === -1) {
    throw new Error(`PSU command failed: ${result.status} — ${result.error || 'unknown'}`);
  }
  const errors = (result.output || []).filter(o => o.type === 4);
  if (errors.length > 0 && result.statusCode !== 2 && result.statusCode !== 11) {
    throw new Error(`PSU command error: ${errors.map(e => e.message).join('; ')}`);
  }
  if (!result.pipelineOutput || result.pipelineOutput.length === 0) {
    return null;
  }
  const raw = result.pipelineOutput[result.pipelineOutput.length - 1].value;
  try { return JSON.parse(raw); } catch { return raw; }
}

/**
 * Execute a non-query PowerShell command (INSERT/UPDATE/DELETE) inside PSU.
 * Does not parse output — just ensures the command completed.
 */
async function runPSUNonQuery(command, timeoutMs = 30000) {
  const result = await runPSUCommand(command, timeoutMs);
  if (result.statusCode === -1) {
    throw new Error(`PSU non-query failed: ${result.status} — ${result.error || 'unknown'}`);
  }
}

function assertPublishPointDatabaseAccess() {
  if (!testConfig.environment.usesPublishPointDatabase) {
    throw new Error(`Environment '${testConfig.environment.name}' does not expose the publish-point database over SSH.`);
  }
}

function getPipelineValue(result) {
  if (result.statusCode === -1) {
    throw new Error(`PSU SQL command failed: ${result.status}`);
  }
  if (result.statusCode !== PSU_STATUS.Completed && result.statusCode !== PSU_STATUS.WarningOutput && result.statusCode !== PSU_STATUS.Warning) {
    throw new Error(`PSU SQL command returned status ${result.status} for job ${result.jobId}.`);
  }

  const pipelineItems = result.pipelineOutput || [];
  if (pipelineItems.length === 0) return null;
  return pipelineItems[pipelineItems.length - 1].value;
}

function psuSqlCommand(sql, returnRows) {
  const encodedSql = Buffer.from(sql, 'utf8').toString('base64');
  return `
$ErrorActionPreference = 'Stop'
$query = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${encodedSql}'))
$rows = Invoke-CIEMQuery -Query $query
if ($null -eq $rows) {
    '[]'
}
else {
    ConvertTo-Json -InputObject @($rows) -Depth 30 -Compress
}
`;
}

function splitSqlStatements(sql) {
  return sql
    .split(';')
    .map(statement => statement.trim())
    .filter(statement => statement.length > 0);
}

function psuSqlNonQueryCommand(sql) {
  const statements = splitSqlStatements(sql);
  const encodedStatements = Buffer.from(JSON.stringify(statements), 'utf8').toString('base64');
  return `
$ErrorActionPreference = 'Stop'
$statementsJson = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${encodedStatements}'))
$statements = @($statementsJson | ConvertFrom-Json)
$databasePath = Get-CIEMDatabasePath
$connection = Open-PSUSQLiteConnection -Database $databasePath
try {
    foreach ($statement in $statements) {
        try {
            Invoke-PSUSQLiteQuery -Connection $connection -Query $statement -AsNonQuery | Out-Null
        }
        catch {
            throw ('SQL non-query failed for statement: {0}{1}{2}' -f $statement, [Environment]::NewLine, $_.Exception.Message)
        }
    }
}
finally {
    $connection.Dispose()
}
'[]'
`;
}

/**
 * Execute a SQL query against the selected CIEM test target.
 * Local uses SSH + sqlite3 against the publish point DB; Azure uses the PSU
 * executor so Playwright can target the Azure web app without filesystem access.
 *
 * Returns: for SELECT — parsed JSON array of rows; for scalar — the raw string value.
 */
function sshQuery(sql) {
  if (!testConfig.environment.usesPublishPointDatabase) {
    const value = getPipelineValue(runPSUCommandSync(psuSqlCommand(sql, true), 120000));
    if (value === null) return [];
    return JSON.parse(value);
  }

  const sshHost = testConfig.environment.publishPointSsh;
  const databasePath = testConfig.environment.databasePath;
  const result = execSync(
    `ssh ${sshHost} "sqlite3 -json '${databasePath}' \\"${sql.replace(/"/g, '\\\\\\"')}\\""`,
    { encoding: 'utf8', timeout: 30000, maxBuffer: 256 * 1024 * 1024 }
  ).trim();
  if (!result) return [];
  try { return JSON.parse(result); } catch { return result; }
}

/**
 * Execute a non-query SQL statement against the selected CIEM test target.
 * Local appends a WAL checkpoint so writes are immediately visible to PSU page reads.
 */
function sshNonQuery(sql) {
  if (!testConfig.environment.usesPublishPointDatabase) {
    getPipelineValue(runPSUCommandSync(psuSqlNonQueryCommand(sql), 120000));
    return;
  }

  const sshHost = testConfig.environment.publishPointSsh;
  const databasePath = testConfig.environment.databasePath;
  // Pipe SQL via stdin so large statement batches don't hit ARG_MAX (E2BIG).
  // sqlite3 reads SQL commands from stdin when no command argument is supplied.
  const fullSql = `${sql};\nPRAGMA wal_checkpoint(TRUNCATE);\n`;
  execSync(
    `ssh ${sshHost} "sqlite3 '${databasePath}'"`,
    { encoding: 'utf8', timeout: 60000, maxBuffer: 256 * 1024 * 1024, input: fullSql }
  );
}

module.exports = {
  LONG_RUNNING_ATTACK_PATH_RULE_ID,
  LONG_RUNNING_ATTACK_PATH_SCRIPT_NAME,
  LONG_RUNNING_ATTACK_PATH_REMEDIATION_SCRIPT_PATH,
  isPSUReady, startPSU, waitForPSU,
  runPSUCommand, runPSUQuery, runPSUNonQuery,
  sshQuery, sshNonQuery,
  registerLongRunningAttackPathRemediationScript,
  removeLongRunningAttackPathRemediationScript,
  cancelRunningPSUJobs, PSU_STATUS, PSU_STATUS_NAMES,
  deactivateAzureAuthProfile, activateAzureAuthProfile,
  getActiveAzureAuthProfileCount
};
