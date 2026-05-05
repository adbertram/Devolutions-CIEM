$ErrorActionPreference = 'Stop'

Import-Module Devolutions.CIEM -ErrorAction Stop
Initialize-CIEMPSUInstance -Integrated | Out-Null
