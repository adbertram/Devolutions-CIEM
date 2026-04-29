function GetCIEMPSUPageRegistry {
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    $ErrorActionPreference = 'Stop'

    $registryPath = Join-Path -Path $script:PSURoot -ChildPath 'Data/pages.json'
    if (-not (Test-Path -Path $registryPath -PathType Leaf)) {
        throw "CIEM PSU page registry not found: $registryPath"
    }

    $pages = @(Get-Content -Path $registryPath -Raw | ConvertFrom-Json -Depth 10)
    if ($pages.Count -eq 0) {
        throw "CIEM PSU page registry contains no pages: $registryPath"
    }

    $pageFields = @('name', 'route', 'title', 'subtitle', 'icon', 'factory', 'order', 'test')
    $testFields = @('expectedColumns', 'smokeSelector')
    $names = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $routes = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $factories = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $orders = [System.Collections.Generic.HashSet[int]]::new()

    foreach ($page in $pages) {
        foreach ($property in $page.PSObject.Properties.Name) {
            if ($property -notin $pageFields) {
                throw "CIEM PSU page registry entry contains unknown field '$property'."
            }
        }

        foreach ($requiredField in $pageFields) {
            if (-not $page.PSObject.Properties[$requiredField]) {
                throw "CIEM PSU page registry entry is missing required field '$requiredField'."
            }
        }

        foreach ($stringField in @('name', 'route', 'title', 'subtitle', 'icon', 'factory')) {
            if ([string]::IsNullOrWhiteSpace([string]$page.$stringField)) {
                throw "CIEM PSU page registry entry has an empty '$stringField' field."
            }
        }

        if ([string]$page.route -notmatch '^/($|[^/].*)') {
            throw "CIEM PSU page registry route must start with one slash and no double slash: $($page.route)"
        }

        $order = [int]$page.order
        if ($order -le 0) {
            throw "CIEM PSU page registry order must be positive for page '$($page.name)'."
        }

        if (-not $names.Add([string]$page.name)) {
            throw "CIEM PSU page registry contains duplicate page name '$($page.name)'."
        }
        if (-not $routes.Add([string]$page.route)) {
            throw "CIEM PSU page registry contains duplicate page route '$($page.route)'."
        }
        if (-not $factories.Add([string]$page.factory)) {
            throw "CIEM PSU page registry contains duplicate page factory '$($page.factory)'."
        }
        if (-not $orders.Add($order)) {
            throw "CIEM PSU page registry contains duplicate page order '$order'."
        }

        if (-not (Get-Command -Name ([string]$page.factory) -ErrorAction SilentlyContinue)) {
            throw "CIEM PSU page registry factory '$($page.factory)' is not loaded."
        }

        if ($null -eq $page.test) {
            throw "CIEM PSU page registry entry '$($page.name)' is missing test metadata."
        }
        foreach ($property in $page.test.PSObject.Properties.Name) {
            if ($property -notin $testFields) {
                throw "CIEM PSU page registry test metadata for '$($page.name)' contains unknown field '$property'."
            }
        }
        foreach ($requiredField in $testFields) {
            if (-not $page.test.PSObject.Properties[$requiredField]) {
                throw "CIEM PSU page registry test metadata for '$($page.name)' is missing required field '$requiredField'."
            }
        }
    }

    $pages | Sort-Object order
}

function GetCIEMPSUPageHref {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object]$Page
    )

    $ErrorActionPreference = 'Stop'

    $route = [string]$Page.route
    if ($route -eq '/') {
        '/ciem'
    } else {
        "/ciem$route"
    }
}
