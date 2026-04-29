BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    function Initialize-InfrastructureTestDatabase {
        New-CIEMDatabase -Path "$TestDrive/ciem.db"

        InModuleScope Devolutions.CIEM {
            $script:DatabasePath = "$TestDrive/ciem.db"
        }

        $schemaPath = Join-Path $PSScriptRoot '..' '..' 'Data' 'azure_schema.sql'
        foreach ($statement in ((Get-Content $schemaPath -Raw) -split ';\s*\n' | Where-Object { $_.Trim() })) {
            Invoke-CIEMQuery -Query $statement.Trim() -AsNonQuery | Out-Null
        }
    }
}

Describe 'Invoke-AzureApi pagination handling' {
    BeforeEach {
        Remove-Item "$TestDrive/ciem.db" -Force -ErrorAction SilentlyContinue
        Initialize-InfrastructureTestDatabase
    }

    It 'Does not emit progress for a single page response' {
        InModuleScope Devolutions.CIEM {
            $script:AzureAuthContext = [CIEMAzureAuthContext]::new()
            $script:AzureAuthContext.IsConnected = $true
            $script:AzureAuthContext.GraphToken = 'graph-token'
            $script:progressCalls = [System.Collections.Generic.List[object]]::new()

            function Write-Progress {
                param($Activity, $Status, $CurrentOperation, [switch]$Completed)
                $script:progressCalls.Add([pscustomobject]@{
                    Completed = [bool]$Completed
                    Status = $Status
                    CurrentOperation = $CurrentOperation
                })
            }

            function Invoke-RestMethod {
                param($Uri, $Method, $Headers, $ResponseHeadersVariable, $ErrorAction)
                [pscustomobject]@{
                    value = @(
                        [pscustomobject]@{ id = 'one' }
                        [pscustomobject]@{ id = 'two' }
                    )
                }
            }

            $result = @(Invoke-AzureApi -Api Graph -Path '/users?$select=id' -ResourceName 'Users' -ErrorAction Stop)

            $result | Should -HaveCount 2
            @($script:progressCalls) | Should -HaveCount 0
        }
    }

    It 'Emits progress for every page and completes the progress bar' {
        InModuleScope Devolutions.CIEM {
            $script:AzureAuthContext = [CIEMAzureAuthContext]::new()
            $script:AzureAuthContext.IsConnected = $true
            $script:AzureAuthContext.GraphToken = 'graph-token'
            $script:progressCalls = [System.Collections.Generic.List[object]]::new()
            $script:responses = @{
                'https://graph.microsoft.com/v1.0/users?$select=id' = [pscustomobject]@{
                    value = @([pscustomobject]@{ id = 'page-1' })
                    '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/users?page=2'
                }
                'https://graph.microsoft.com/v1.0/users?page=2' = [pscustomobject]@{
                    value = @([pscustomobject]@{ id = 'page-2' })
                    '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/users?page=3'
                }
                'https://graph.microsoft.com/v1.0/users?page=3' = [pscustomobject]@{
                    value = @([pscustomobject]@{ id = 'page-3' })
                    '@odata.nextLink' = $null
                }
            }

            function Write-Progress {
                param($Activity, $Status, $CurrentOperation, [switch]$Completed)
                $script:progressCalls.Add([pscustomobject]@{
                    Completed = [bool]$Completed
                    Status = $Status
                    CurrentOperation = $CurrentOperation
                })
            }

            function Invoke-RestMethod {
                param($Uri, $Method, $Headers, $ResponseHeadersVariable, $ErrorAction)
                $script:responses[$Uri]
            }

            $result = @(Invoke-AzureApi -Api Graph -Path '/users?$select=id' -ResourceName 'Users' -ErrorAction Stop)
            $activeCalls = @($script:progressCalls | Where-Object { -not $_.Completed })
            $completedCalls = @($script:progressCalls | Where-Object { $_.Completed })

            $result | Should -HaveCount 3
            $activeCalls | Should -HaveCount 3
            $completedCalls | Should -HaveCount 1
        }
    }

    It 'Throws when the same nextLink is returned twice in a row' {
        InModuleScope Devolutions.CIEM {
            $script:AzureAuthContext = [CIEMAzureAuthContext]::new()
            $script:AzureAuthContext.IsConnected = $true
            $script:AzureAuthContext.GraphToken = 'graph-token'
            $script:responses = @{
                'https://graph.microsoft.com/v1.0/users?$select=id' = [pscustomobject]@{
                    value = @([pscustomobject]@{ id = 'page-1' })
                    '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/users?page=2'
                }
                'https://graph.microsoft.com/v1.0/users?page=2' = [pscustomobject]@{
                    value = @([pscustomobject]@{ id = 'page-2' })
                    '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/users?page=2'
                }
            }

            function Write-Progress { param($Activity, $Status, $CurrentOperation, [switch]$Completed) }
            function Invoke-RestMethod {
                param($Uri, $Method, $Headers, $ResponseHeadersVariable, $ErrorAction)
                $script:responses[$Uri]
            }

            {
                Invoke-AzureApi -Api Graph -Path '/users?$select=id' -ResourceName 'Users' -ErrorAction Stop
            } | Should -Throw '*pagination cycle*'
        }
    }

    It 'Stops cleanly when a page is empty even if nextLink is still present' {
        InModuleScope Devolutions.CIEM {
            $script:AzureAuthContext = [CIEMAzureAuthContext]::new()
            $script:AzureAuthContext.IsConnected = $true
            $script:AzureAuthContext.GraphToken = 'graph-token'
            $script:callUris = [System.Collections.Generic.List[string]]::new()
            $script:responses = @{
                'https://graph.microsoft.com/v1.0/users?$select=id' = [pscustomobject]@{
                    value = @([pscustomobject]@{ id = 'page-1' })
                    '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/users?page=2'
                }
                'https://graph.microsoft.com/v1.0/users?page=2' = [pscustomobject]@{
                    value = @()
                    '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/users?page=3'
                }
            }

            function Write-Progress { param($Activity, $Status, $CurrentOperation, [switch]$Completed) }
            function Invoke-RestMethod {
                param($Uri, $Method, $Headers, $ResponseHeadersVariable, $ErrorAction)
                $script:callUris.Add($Uri)
                $script:responses[$Uri]
            }

            $result = @(Invoke-AzureApi -Api Graph -Path '/users?$select=id' -ResourceName 'Users' -ErrorAction Stop)

            $result | Should -HaveCount 1
            @($script:callUris) | Should -HaveCount 2
            @($script:callUris) | Should -Not -Contain 'https://graph.microsoft.com/v1.0/users?page=3'
        }
    }
}
