function GetBumpedVersion {
    param([version]$Base, [string]$Component)

    $ErrorActionPreference = 'Stop'

    switch ($Component) {
        'Major' { [version]::new($Base.Major + 1, 0, 0) }
        'Minor' { [version]::new($Base.Major, $Base.Minor + 1, 0) }
        'Patch' { [version]::new($Base.Major, $Base.Minor, $Base.Build + 1) }
    }
}
