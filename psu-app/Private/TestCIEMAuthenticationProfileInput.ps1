function TestCIEMAuthenticationProfileInput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$Method,

        [Parameter(Mandatory)]
        [hashtable]$Settings,

        [Parameter(Mandatory)]
        [hashtable]$SecretRefs
    )

    $ErrorActionPreference = 'Stop'

    $methodSchema = @(GetCIEMAuthenticationProfileFieldSchema -Provider $Provider -Method $Method)
    if ($methodSchema.Count -ne 1) {
        throw "Authentication method '$Method' is not valid for provider '$Provider'."
    }

    $fields = @($methodSchema[0].fields)
    $settingFields = @($fields | Where-Object { $_.kind -eq 'setting' })
    $secretFields = @($fields | Where-Object { $_.kind -eq 'secret' })

    $settingFieldNames = @($settingFields | ForEach-Object { [string]$_.name })
    $secretFieldNames = @($secretFields | ForEach-Object { [string]$_.name })

    foreach ($settingName in @($Settings.Keys)) {
        if ($settingFieldNames -notcontains [string]$settingName) {
            throw "Authentication profile setting '$settingName' is not valid for provider '$Provider' method '$Method'."
        }
    }

    foreach ($secretName in @($SecretRefs.Keys)) {
        if ($secretFieldNames -notcontains [string]$secretName) {
            throw "Authentication profile secret '$secretName' is not valid for provider '$Provider' method '$Method'."
        }
    }

    foreach ($field in @($methodSchema[0].fields | Where-Object { [bool]$_.required })) {
        $source = if ($field.kind -eq 'setting') { $Settings } elseif ($field.kind -eq 'secret') { $SecretRefs } else { throw "Unsupported authentication profile field kind '$($field.kind)'." }
        if (-not $source.ContainsKey([string]$field.name)) {
            throw "Authentication profile field '$($field.name)' is required for provider '$Provider' method '$Method'."
        }
        if ([string]::IsNullOrWhiteSpace([string]$source[[string]$field.name])) {
            throw "Authentication profile field '$($field.name)' is required for provider '$Provider' method '$Method'."
        }
    }

    foreach ($field in $settingFields) {
        $fieldName = [string]$field.name
        if (-not $Settings.ContainsKey($fieldName)) {
            continue
        }

        $fieldValue = [string]$Settings[$fieldName]
        switch ([string]$field.inputType) {
            'text' {}
            'number' {
                $parsedNumber = 0
                if (-not [int]::TryParse($fieldValue, [ref]$parsedNumber)) {
                    throw "Authentication profile field '$fieldName' must be a number for provider '$Provider' method '$Method'."
                }
            }
            'select' {
                $options = @($field.options | ForEach-Object { [string]$_ })
                if ($options -notcontains $fieldValue) {
                    throw "Authentication profile field '$fieldName' must be one of: $($options -join ', ')."
                }
            }
            default {
                throw "Unsupported authentication profile input type '$($field.inputType)' for field '$fieldName'."
            }
        }
    }

    foreach ($field in $secretFields) {
        $fieldName = [string]$field.name
        switch ([string]$field.inputType) {
            'password' {}
            'upload' {}
            default {
                throw "Unsupported authentication profile input type '$($field.inputType)' for field '$fieldName'."
            }
        }
    }
}
