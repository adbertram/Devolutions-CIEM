# Base authentication context class — provider-agnostic.
# Provider-specific subclasses live in their respective modules
# (e.g., Devolutions.CIEM.Azure, Devolutions.CIEM.AWS).
#
# At runtime, auth contexts cross module boundaries as [PSCustomObject]
# (PSU runspace serialization strips class type info), so Base works
# entirely with PSCustomObjects via registered provider callbacks.

class CIEMAuthenticationContext {
    [string]$Provider
    [bool]$Enabled
    [string]$Method
}
