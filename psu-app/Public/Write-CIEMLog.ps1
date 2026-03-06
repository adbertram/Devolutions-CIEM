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

    # Log file path - always write to data/ciem.log under the module root.
    # This matches the bootstrap logger (_BootLog) path so all logs go to one file.
    $logPath = Join-Path -Path $script:ModuleRoot -ChildPath 'data/ciem.log'

    # Format timestamp
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'

    # Build log entry
    $logEntry = "[$timestamp] [$Severity] [$Component] $Message"

    # Append to log file (thread-safe with mutex for PSU concurrent access)
    if (-not $script:_LogMutex) {
        $script:_LogMutex = New-Object System.Threading.Mutex($false, 'CIEMLogMutex')
    }
    try {
        $script:_LogMutex.WaitOne() | Out-Null
        Add-Content -Path $logPath -Value $logEntry -Encoding UTF8
    }
    finally {
        $script:_LogMutex.ReleaseMutex()
    }

    # Also write to verbose stream for debugging
    Write-Verbose $logEntry
}
