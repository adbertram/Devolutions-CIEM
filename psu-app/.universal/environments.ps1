# PowerShell Universal Environments Configuration
# Defines the PowerShell environments available for apps, scripts, and APIs

# Default PowerShell 7 environment
New-PSUEnvironment -Name "PowerShell 7" -Path "pwsh" -Description "PowerShell 7.x Core" -Version "7.4.0"

# Integrated environment (uses PSU's built-in PowerShell)
New-PSUEnvironment -Name "Integrated" -Path "." -Description "PowerShell Universal integrated environment"
