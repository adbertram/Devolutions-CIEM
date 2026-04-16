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
                                    id          = "$($_.PatternId)-$idx"
                                    patternName = $_.PatternName
                                    severity    = $_.Severity
                                    category    = $_.Category
                                    pathChain   = $chainText
                                    steps       = @($_.Path).Count
                                    remediation = $_.Remediation
                                    remediationScript = $_.RemediationScript
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
                            $remediationScript = [string]$EventData.row.remediationScript
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
                                            'data-ciem-attack-path-remediation-script-copy' = 'true'
                                            style = @{ position = 'absolute'; top = '8px'; right = '8px'; zIndex = 2 }
                                        } -Content {
                                            New-UDElement -Tag 'a' -Attributes @{
                                                href = @'
javascript:(()=>{const control=document.activeElement;const panel=control.closest(".MuiDataGrid-detailPanel");const scriptBlock=panel.querySelector("[data-ciem-attack-path-remediation-script='true']");const textArea=document.createElement("textarea");textArea.value=scriptBlock.textContent.trim();textArea.setAttribute("readonly","");textArea.style.position="fixed";textArea.style.top="-1000px";textArea.style.left="-1000px";document.body.appendChild(textArea);textArea.focus();textArea.select();document.execCommand("copy");document.body.removeChild(textArea);const idle=control.querySelector("[data-ciem-copy-idle='true']");const success=control.querySelector("[data-ciem-copy-success='true']");idle.style.display="none";success.style.display="inline-flex";control.style.borderColor="#2da44e";control.style.color="#1a7f37";control.title="Copied";control.setAttribute("aria-label","Copied remediation script");window.clearTimeout(control.__ciemCopyTimer);control.__ciemCopyTimer=window.setTimeout(()=>{idle.style.display="inline-flex";success.style.display="none";control.style.borderColor="#d0d7de";control.style.color="#57606a";control.title="Copy script";control.setAttribute("aria-label","Copy remediation script");},1800);})()
'@
                                                role = 'button'
                                                title = 'Copy script'
                                                'aria-label' = 'Copy remediation script'
                                                style = @{
                                                    width = '82px'
                                                    height = '32px'
                                                    display = 'inline-flex'
                                                    alignItems = 'center'
                                                    justifyContent = 'center'
                                                    padding = '0'
                                                    backgroundColor = '#ffffff'
                                                    border = '1px solid #d0d7de'
                                                    borderRadius = '6px'
                                                    color = '#57606a'
                                                    cursor = 'pointer'
                                                    textDecoration = 'none'
                                                    fontSize = '12px'
                                                    fontWeight = '600'
                                                    fontFamily = 'inherit'
                                                    lineHeight = '1'
                                                }
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
                                        New-UDElement -Tag 'pre' -Attributes @{
                                            'data-ciem-attack-path-remediation-script' = 'true'
                                            style = @{
                                                margin = '0'
                                                padding = '12px 100px 12px 12px'
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
