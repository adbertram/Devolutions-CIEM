function Write-CIEMLog {
    <#
    .SYNOPSIS
        Writes a log entry to the CIEM log file.

    .DESCRIPTION
        Internal logging function that writes timestamped entries to a log file
        in the module directory. Supports severity levels: DEBUG, INFO, WARNING, ERROR.

    .PARAMETER Message
        The log message to write.

    .PARAMETER Severity
        Log severity level. Defaults to INFO.

    .PARAMETER Component
        Optional component name for categorizing log entries.

    .EXAMPLE
        Write-CIEMLog -Message "Starting authentication" -Severity INFO -Component "Connect-CIEM"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR')]
        [string]$Severity = 'INFO',

        [Parameter()]
        [string]$Component = 'CIEM'
    )

    # Log file path - find the PSU LogFiles directory
    # Azure: /home/LogFiles
    # Local PSU: walk up from module root to find LogFiles sibling of Repository
    # Fallback: module directory
    $logDir = if ($IsLinux -and (Test-Path '/home/LogFiles')) {
        '/home/LogFiles'
    } else {
        # When imported into PSU, module lives under Repository/Modules/Name/Version/
        # Walk up to find a parent that has a LogFiles directory
        $dir = $script:ModuleRoot
        $found = $null
        for ($i = 0; $i -lt 5; $i++) {
            $candidate = Join-Path (Split-Path $dir -Parent) 'LogFiles'
            if (Test-Path $candidate) {
                $found = $candidate
                break
            }
            $dir = Split-Path $dir -Parent
        }
        if ($found) { $found } else { $script:ModuleRoot }
    }
    $logPath = Join-Path -Path $logDir -ChildPath 'ciem.log'

    # Format timestamp
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'

    # Build log entry
    $logEntry = "[$timestamp] [$Severity] [$Component] $Message"

    # Append to log file (thread-safe with mutex for PSU concurrent access)
    $mutex = New-Object System.Threading.Mutex($false, 'CIEMLogMutex')
    try {
        $mutex.WaitOne() | Out-Null
        Add-Content -Path $logPath -Value $logEntry -Encoding UTF8
    }
    finally {
        $mutex.ReleaseMutex()
    }

    # Also write to verbose stream for debugging
    Write-Verbose $logEntry
}
