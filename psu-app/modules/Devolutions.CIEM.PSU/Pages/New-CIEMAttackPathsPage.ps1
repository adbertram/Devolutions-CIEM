function New-CIEMAttackPathsPage {
    <#
    .SYNOPSIS
        Creates the Attack Paths page with a data grid of discovered attack path findings.
    .PARAMETER Navigation
        Array of UDListItem components for sidebar navigation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Navigation
    )

    $ErrorActionPreference = 'Stop'

    New-UDPage -Name 'Attack Paths' -Url '/ciem/attack-paths' -Content {
        New-UDTypography -Text 'Attack Paths' -Variant 'h4' -Style @{ marginBottom = '10px'; marginTop = '10px' }
        New-UDTypography -Text 'Discovered attack paths evaluated against the security graph' -Variant 'subtitle1' -Style @{ marginBottom = '20px'; opacity = 0.7 }

        New-UDButton -Id 'refreshAttackPathsBtn' -Text 'Refresh Attack Paths' -Variant 'outlined' -Color 'secondary' -ShowLoading -OnClick {
            $attackPathCount = @(Devolutions.CIEM\Update-CIEMAttackPath -PassThru).Count
            Sync-UDElement -Id 'attackPathsPanel'
            Show-UDToast -Message "Attack paths refreshed: $attackPathCount findings" -Duration 5000 -BackgroundColor '#4caf50'
        } -Style @{ marginBottom = '16px' }

        $focusedAttackPathId = [string]$Query['attackPathId']
        if ($focusedAttackPathId) {
            $focusedAttackPaths = @(Devolutions.CIEM\Get-CIEMAttackPath | Where-Object { [string]$_.Id -eq $focusedAttackPathId })
            if ($focusedAttackPaths.Count -eq 0) {
                New-UDElement -Tag 'section' -Id 'attackPathDeepLinkDetail' -Attributes @{
                    style = @{
                        marginBottom = '16px'
                    }
                } -Content {
                    New-UDAlert -Severity 'warning' -Title 'Attack path not found' -Text "No attack path with ID '$focusedAttackPathId' is available in the current graph."
                }
            }
            elseif ($focusedAttackPaths.Count -eq 1) {
                $focusedAttackPath = $focusedAttackPaths[0]
                $focusedSeverityColor = Devolutions.CIEM\Get-SeverityColor -Severity $focusedAttackPath.Severity
                $focusedPathChain = [string]$focusedAttackPath.PathChain
                if ([string]::IsNullOrWhiteSpace($focusedPathChain)) {
                    throw "Expected attack path '$focusedAttackPathId' to have PathChain."
                }

                New-UDElement -Tag 'section' -Id 'attackPathDeepLinkDetail' -Attributes @{
                    style = @{
                        display = 'grid'
                        gap = '10px'
                        padding = '14px'
                        marginBottom = '16px'
                        border = '1px solid #8c959f'
                        borderRadius = '6px'
                        backgroundColor = '#f6f8fa'
                    }
                } -Content {
                    New-UDStack -Direction 'row' -Spacing 1 -AlignItems 'center' -Content {
                        New-UDChip -Label 'Focused' -Size 'small' -Variant 'outlined'
                        New-UDChip -Label $focusedAttackPath.Severity -Size 'small' -Style @{ backgroundColor = $focusedSeverityColor; color = 'white' }
                        New-UDTypography -Text $focusedAttackPath.PatternName -Variant 'h6' -Style @{ fontWeight = '600' }
                    }
                    New-UDTypography -Text $focusedPathChain -Variant 'body2' -Style @{ fontFamily = 'monospace'; color = '#57606a'; overflowWrap = 'anywhere' }
                    New-UDTypography -Text $focusedAttackPath.Remediation -Variant 'body2' -Style @{ color = '#24292f'; whiteSpace = 'pre-wrap'; overflowWrap = 'anywhere' }
                }
            }
            else {
                throw "Expected one attack path for '$focusedAttackPathId', got $($focusedAttackPaths.Count)."
            }
        }

        New-UDCard -Content {
            New-UDDynamic -Id 'attackPathsPanel' -Content {

                try {
                    $hasData = (Devolutions.CIEM\Invoke-CIEMQuery -Query 'SELECT COUNT(*) as c FROM graph_nodes').c -gt 0

                    if ($hasData) {
                        New-UDDataGrid -LoadRows {

                            $findings = @(Devolutions.CIEM\Get-CIEMAttackPath)
                            $idx = 0
                            $gridData = $findings | ForEach-Object {
                                $idx++
                                $chainLabels = @($_.Path | ForEach-Object {
                                    $label = if ($_.display_name) { $_.display_name } else { $_.kind }
                                    "$label ($($_.kind))"
                                })
                                $chainText = $chainLabels -join ' → '

                                @{
                                    id            = "$($_.PatternId)-$idx"
                                    attackPathId  = $_.Id
                                    patternName   = $_.PatternName
                                    severity      = $_.Severity
                                    category      = $_.Category
                                    pathChain     = $chainText
                                    steps         = @($_.Path).Count
                                    remediation   = $_.Remediation
                                    psuScriptName = $_.PsuScriptName
                                }
                            }
                            @($gridData) | Out-UDDataGridData -Context $EventData -TotalRows @($gridData).Count
                        } -Columns @(
                            New-UDDataGridColumn -Field 'patternName' -HeaderName 'Pattern Name' -Flex 1
                            New-UDDataGridColumn -Field 'severity' -HeaderName 'Severity' -Width 130 -Render {
                                $color = Devolutions.CIEM\Get-SeverityColor -Severity $EventData.severity
                                New-UDChip -Label $EventData.severity -Size 'small' -Style @{ backgroundColor = $color; color = 'white' }
                            }
                            New-UDDataGridColumn -Field 'category' -HeaderName 'Category' -Width 200
                            New-UDDataGridColumn -Field 'pathChain' -HeaderName 'Path Chain' -Flex 2 -Render {
                                New-UDTypography -Text $EventData.pathChain -Variant 'body2' -Style @{ fontFamily = 'monospace'; opacity = 0.8 }
                            }
                            New-UDDataGridColumn -Field 'steps' -HeaderName 'Steps' -Width 90 -Type 'number'
                        ) -AutoHeight $true -Pagination -PageSize 25 -ShowQuickFilter -LoadDetailContent {
                            $remediation = [string]$EventData.row.remediation
                            $attackPathId = [string]$EventData.row.attackPathId
                            $remediationScript = Devolutions.CIEM\Get-CIEMAttackPathRemediationScript -Id $attackPathId
                            $executionKey = [guid]::NewGuid().ToString('N')
                            $executionStreamsId = "ciemAttackPathExecutionStreams_$executionKey"
                            $executionWarningId = "ciemAttackPathExecutionWarning_$executionKey"
                            $scriptActionButtonStyle = @{
                                width           = '112px'
                                minWidth        = '112px'
                                height          = '32px'
                                display         = 'inline-flex'
                                alignItems      = 'center'
                                justifyContent  = 'center'
                                padding         = '0'
                                backgroundColor = '#ffffff'
                                border          = '1px solid #d0d7de'
                                borderRadius    = '6px'
                                color           = '#57606a'
                                cursor          = 'pointer'
                                textDecoration  = 'none'
                                fontSize        = '12px'
                                fontWeight      = '600'
                                fontFamily      = 'inherit'
                                lineHeight      = '1'
                                textTransform   = 'none'
                            }
                            New-UDElement -Tag 'div' -Attributes @{ style = @{ padding = '14px 18px'; display = 'grid'; gap = '14px' } } -Content {
                                New-UDElement -Tag 'section' -Content {
                                    New-UDTypography -Text 'Remediation' -Variant 'subtitle2' -Style @{ fontWeight = '600'; marginBottom = '6px' }
                                    New-UDElement -Tag 'pre' -Attributes @{
                                        'data-ciem-attack-path-remediation' = 'true'
                                        style = @{
                                            margin = '0'
                                            padding = '12px'
                                            border = '1px solid #d0d7de'
                                            borderRadius = '6px'
                                            backgroundColor = '#ffffff'
                                            whiteSpace = 'pre-wrap'
                                            overflowWrap = 'anywhere'
                                            fontFamily = 'inherit'
                                            fontSize = '14px'
                                            lineHeight = '1.45'
                                            maxHeight = '220px'
                                            overflow = 'auto'
                                        }
                                    } -Content {
                                        $remediation
                                    }
                                }
                                New-UDElement -Tag 'section' -Content {
                                    New-UDTypography -Text 'Remediation Script' -Variant 'subtitle2' -Style @{ fontWeight = '600'; marginBottom = '6px' }
                                    New-UDElement -Tag 'div' -Attributes @{ style = @{ position = 'relative' } } -Content {
                                        New-UDElement -Tag 'div' -Attributes @{
                                            'data-ciem-attack-path-remediation-script-actions' = 'true'
                                            style = @{
                                                position   = 'absolute'
                                                top        = '8px'
                                                right      = '8px'
                                                zIndex     = 2
                                                display    = 'flex'
                                                alignItems = 'center'
                                                gap        = '8px'
                                            }
                                        } -Content {
                                            New-UDElement -Tag 'div' -Attributes @{
                                                'data-ciem-attack-path-remediation-script-copy' = 'true'
                                            } -Content {
                                                New-UDElement -Tag 'a' -Attributes @{
                                                    href = @'
javascript:(()=>{const control=document.activeElement;const panel=control.closest(".MuiDataGrid-detailPanel");const scriptBlock=panel.querySelector("[data-ciem-attack-path-remediation-script='true']");const textArea=document.createElement("textarea");textArea.value=scriptBlock.textContent.trim();textArea.setAttribute("readonly","");textArea.style.position="fixed";textArea.style.top="-1000px";textArea.style.left="-1000px";document.body.appendChild(textArea);textArea.focus();textArea.select();document.execCommand("copy");document.body.removeChild(textArea);const idle=control.querySelector("[data-ciem-copy-idle='true']");const success=control.querySelector("[data-ciem-copy-success='true']");idle.style.display="none";success.style.display="inline-flex";control.style.borderColor="#2da44e";control.style.color="#1a7f37";control.title="Copied";control.setAttribute("aria-label","Copied remediation script");window.clearTimeout(control.__ciemCopyTimer);control.__ciemCopyTimer=window.setTimeout(()=>{idle.style.display="inline-flex";success.style.display="none";control.style.borderColor="#d0d7de";control.style.color="#57606a";control.title="Copy script";control.setAttribute("aria-label","Copy remediation script");},1800);})()
'@
                                                    role = 'button'
                                                    title = 'Copy script'
                                                    'aria-label' = 'Copy remediation script'
                                                    style = $scriptActionButtonStyle
                                                } -Content {
                                                    New-UDElement -Tag 'span' -Attributes @{
                                                        'data-ciem-copy-idle' = 'true'
                                                        style = @{ display = 'inline-flex'; alignItems = 'center'; gap = '6px' }
                                                    } -Content {
                                                        New-UDIcon -Icon 'Copy' -Size 'sm'
                                                        New-UDElement -Tag 'span' -Content { 'Copy' }
                                                    }
                                                    New-UDElement -Tag 'span' -Attributes @{
                                                        'data-ciem-copy-success' = 'true'
                                                        style = @{ display = 'none'; alignItems = 'center'; gap = '6px' }
                                                    } -Content {
                                                        New-UDIcon -Icon 'CheckCircle' -Size 'sm'
                                                        New-UDElement -Tag 'span' -Content { 'Copied' }
                                                    }
                                                }
                                            }
                                            New-UDElement -Tag 'div' -Attributes @{
                                                'data-ciem-attack-path-remediation-script-execute' = 'true'
                                            } -Content {
                                                New-UDButton -Text 'Execute' -Variant 'outlined' -Color 'secondary' -Size 'small' -Icon (New-UDIcon -Icon 'Play' -Size 'sm') -Style $scriptActionButtonStyle -OnClick {
                                                $job = Invoke-PSUScript -Name 'Devolutions.CIEM\Invoke-CIEMAttackPathRemediation' -Integrated -Parameters @{ AttackPathId = $attackPathId }
                                                $Page:CIEMAttackPathExecution = @{
                                                    JobId        = [int64]$job.Id
                                                    Script       = $remediationScript
                                                    Status       = [string]$job.Status
                                                    IsRunning    = $true
                                                    CloseWarning = $false
                                                }

                                                Show-UDModal -Persistent -FullWidth -MaxWidth 'lg' -Header {
                                                    New-UDTypography -Text 'Execute Remediation Script' -Variant 'h6'
                                                } -Content {
                                                    New-UDElement -Tag 'div' -Attributes @{
                                                        'data-ciem-attack-path-execution-dialog' = 'true'
                                                        style = @{ display = 'grid'; gap = '14px' }
                                                    } -Content {
                                                        New-UDTypography -Text 'Script' -Variant 'subtitle2' -Style @{ fontWeight = '600' }
                                                        New-UDElement -Tag 'pre' -Attributes @{
                                                            'data-ciem-attack-path-execution-script' = 'true'
                                                            style = @{
                                                                margin = '0'
                                                                padding = '12px'
                                                                border = '1px solid #d0d7de'
                                                                borderRadius = '6px'
                                                                backgroundColor = '#ffffff'
                                                                whiteSpace = 'pre-wrap'
                                                                overflowWrap = 'anywhere'
                                                                fontFamily = 'monospace'
                                                                fontSize = '13px'
                                                                lineHeight = '1.45'
                                                                maxHeight = '220px'
                                                                overflow = 'auto'
                                                            }
                                                        } -Content {
                                                            $Page:CIEMAttackPathExecution['Script']
                                                        }
                                                        New-UDTypography -Text 'Streams' -Variant 'subtitle2' -Style @{ fontWeight = '600' }
                                                        New-UDDynamic -Id $executionStreamsId -AutoRefresh -AutoRefreshInterval 1 -Content {
                                                            $executionState = $Page:CIEMAttackPathExecution
                                                            if ($null -eq $executionState) {
                                                                throw 'Cannot render attack path remediation execution because execution state is missing.'
                                                            }

                                                            $jobId = [int64]$executionState['JobId']
                                                            $job = Get-PSUJob -Id $jobId -Integrated
                                                            $streamLines = [System.Collections.Generic.List[string]]::new()
                                                            $streamLines.Add("Execution started. Job $jobId.")

                                                            foreach ($message in @(Devolutions.CIEM\Get-CIEMPSUJobOutput -Job $job -Integrated)) {
                                                                $streamLines.Add("[stream] $message")
                                                            }

                                                            $isRunning = @('Queued', 'Running') -contains [string]$job.Status
                                                            if (-not $isRunning) {
                                                                $streamLines.Add("Execution $($job.Status).")
                                                            }

                                                            $streamText = $streamLines -join [Environment]::NewLine
                                                            $executionState['Status'] = [string]$job.Status
                                                            $executionState['IsRunning'] = $isRunning
                                                            $executionState['Streams'] = $streamText
                                                            $Page:CIEMAttackPathExecution = $executionState

                                                            New-UDElement -Tag 'div' -Attributes @{
                                                                'data-ciem-attack-path-execution-streams' = 'true'
                                                            } -Content {
                                                                New-UDTextbox -Multiline -Rows 14 -FullWidth -Disabled -Value $streamText
                                                            }
                                                        }
                                                        New-UDDynamic -Id $executionWarningId -Content {
                                                            $executionState = $Page:CIEMAttackPathExecution
                                                            if ($null -eq $executionState) {
                                                                throw 'Cannot render attack path remediation close warning because execution state is missing.'
                                                            }

                                                            if ([bool]$executionState['CloseWarning']) {
                                                                New-UDElement -Tag 'div' -Attributes @{
                                                                    'data-ciem-attack-path-execution-close-warning' = 'true'
                                                                    style = @{ display = 'grid'; gap = '10px' }
                                                                } -Content {
                                                                    New-UDAlert -Severity 'warning' -Title 'Script still running' -Text 'Terminate it now or leave it running in the background.'
                                                                    New-UDElement -Tag 'div' -Attributes @{ style = @{ display = 'flex'; gap = '8px' } } -Content {
                                                                        New-UDElement -Tag 'div' -Attributes @{
                                                                            'data-ciem-attack-path-execution-terminate' = 'true'
                                                                            'data-ciem-attack-path-execution-warning-terminate' = 'true'
                                                                        } -Content {
                                                                            New-UDButton -Text 'Terminate' -Variant 'contained' -Color 'error' -OnClick {
                                                                                $executionState = $Page:CIEMAttackPathExecution
                                                                                if ($null -eq $executionState) {
                                                                                    throw 'Cannot terminate attack path remediation because execution state is missing.'
                                                                                }

                                                                                $jobId = [int64]$executionState['JobId']
                                                                                $job = Get-PSUJob -Id $jobId -Integrated
                                                                                if (@('Queued', 'Running') -contains [string]$job.Status) {
                                                                                    Stop-PSUJob -Id $jobId -Integrated | Out-Null
                                                                                }
                                                                                Hide-UDModal
                                                                            }
                                                                        }
                                                                        New-UDElement -Tag 'div' -Attributes @{
                                                                            'data-ciem-attack-path-execution-leave-running' = 'true'
                                                                        } -Content {
                                                                            New-UDButton -Text 'Leave Running' -Variant 'outlined' -Color 'secondary' -OnClick {
                                                                                $executionState = $Page:CIEMAttackPathExecution
                                                                                if ($null -eq $executionState) {
                                                                                    throw 'Cannot leave attack path remediation running because execution state is missing.'
                                                                                }

                                                                                $executionState['CloseWarning'] = $false
                                                                                $Page:CIEMAttackPathExecution = $executionState
                                                                                Hide-UDModal
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                } -Footer {
                                                    New-UDElement -Tag 'div' -Attributes @{
                                                        style = @{ display = 'flex'; gap = '8px'; justifyContent = 'flex-end'; width = '100%' }
                                                    } -Content {
                                                        New-UDElement -Tag 'div' -Attributes @{
                                                            'data-ciem-attack-path-execution-terminate' = 'true'
                                                        } -Content {
                                                            New-UDButton -Text 'Terminate' -Variant 'outlined' -Color 'error' -OnClick {
                                                                $executionState = $Page:CIEMAttackPathExecution
                                                                if ($null -eq $executionState) {
                                                                    throw 'Cannot terminate attack path remediation because execution state is missing.'
                                                                }

                                                                $jobId = [int64]$executionState['JobId']
                                                                $job = Get-PSUJob -Id $jobId -Integrated
                                                                if (@('Queued', 'Running') -contains [string]$job.Status) {
                                                                    Stop-PSUJob -Id $jobId -Integrated | Out-Null
                                                                }
                                                                Hide-UDModal
                                                            }
                                                        }
                                                        New-UDElement -Tag 'div' -Attributes @{
                                                            'data-ciem-attack-path-execution-close' = 'true'
                                                        } -Content {
                                                            New-UDButton -Text 'Close' -Variant 'contained' -Color 'primary' -OnClick {
                                                                $executionState = $Page:CIEMAttackPathExecution
                                                                if ($null -eq $executionState) {
                                                                    throw 'Cannot close attack path remediation execution because execution state is missing.'
                                                                }

                                                                $executionState['CloseWarning'] = $true
                                                                $Page:CIEMAttackPathExecution = $executionState
                                                                Sync-UDElement -Id $executionWarningId
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        }
                                        New-UDElement -Tag 'pre' -Attributes @{
                                            'data-ciem-attack-path-remediation-script' = 'true'
                                            style = @{
                                                margin = '0'
                                                padding = '12px 260px 12px 12px'
                                                border = '1px solid #d0d7de'
                                                borderRadius = '6px'
                                                backgroundColor = '#ffffff'
                                                whiteSpace = 'pre-wrap'
                                                overflowWrap = 'anywhere'
                                                fontFamily = 'monospace'
                                                fontSize = '13px'
                                                lineHeight = '1.45'
                                                maxHeight = '320px'
                                                overflow = 'auto'
                                            }
                                        } -Content {
                                            $remediationScript
                                        }
                                    }
                                }
                                New-UDTypography -Text 'Path Chain' -Variant 'h6' -Style @{ marginTop = '12px'; marginBottom = '4px' }
                                New-UDTypography -Text $EventData.row.pathChain -Variant 'body2' -Style @{ fontFamily = 'monospace'; opacity = 0.8 }
                            }
                        }
                    }
                    else {
                        New-UDTypography -Text 'No attack path data available. Run Azure Discovery from the Environment page to build the security graph.' -Variant 'body2' -Style @{ opacity = 0.5; fontStyle = 'italic'; padding = '16px' }
                    }
                }
                catch {
                    New-UDTypography -Text 'Unable to load attack path data.' -Variant 'body2' -Style @{ opacity = 0.5; fontStyle = 'italic'; padding = '16px' }
                }
            }
        }
    } -Navigation $Navigation -NavigationLayout permanent
}
