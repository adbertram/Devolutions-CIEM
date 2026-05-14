function New-CIEMConfigPage {
    <#
    .SYNOPSIS
        Creates the CIEM Configuration page.
    .PARAMETER Navigation
        Array of UDListItem components for sidebar navigation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Navigation
    )

    $ErrorActionPreference = 'Stop'

    New-UDPage -Name 'Configuration' -Url '/ciem/config' -Content {
        New-UDTypography -Text 'Configuration' -Variant 'h4' -Style @{ marginBottom = '20px'; marginTop = '10px' }
        New-UDTypography -Text 'Configure scheduled discovery and outbound notifications' -Variant 'subtitle1' -Style @{ marginBottom = '30px'; color = '#666' }

        New-UDElement -Tag 'div' -Id 'scheduledDiscoveryWrapper' -Content {
            New-UDCard -Title 'Scheduled Discovery' -Content {
                $scheduleRows = @(Devolutions.CIEM\Get-CIEMAzureDiscoverySchedule)
                $schedule = $scheduleRows | Select-Object -First 1
                $selectedScope = if ($schedule) { [string]$schedule.Scope } else { 'All' }
                $selectedCadence = if (-not $schedule -or $schedule.Cron -eq '0 2 * * *') {
                    'daily'
                }
                elseif ($schedule.Cron -eq '0 2 * * 1') {
                    'weekly'
                }
                else {
                    throw "Unsupported scheduled discovery cron '$($schedule.Cron)'."
                }
                $scheduleEnabled = if ($schedule) { [bool]$schedule.Enabled } else { $false }

                New-UDGrid -Container -Spacing 2 -Content {
                    New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 4 -Content {
                        New-UDSelect -Id 'azureDiscoveryScheduleCadence' -Label 'Cadence' -DefaultValue $selectedCadence -FullWidth -Option {
                            New-UDSelectOption -Name 'Daily' -Value 'daily'
                            New-UDSelectOption -Name 'Weekly' -Value 'weekly'
                        }
                    }
                    New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 4 -Content {
                        New-UDSelect -Id 'azureDiscoveryScheduleScope' -Label 'Scope' -DefaultValue $selectedScope -FullWidth -Option {
                            New-UDSelectOption -Name 'All' -Value 'All'
                            New-UDSelectOption -Name 'ARM' -Value 'ARM'
                            New-UDSelectOption -Name 'Entra' -Value 'Entra'
                        }
                    }
                    New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 2 -Content {
                        New-UDSwitch -Id 'azureDiscoveryScheduleEnabled' -Label 'Enabled' -Checked $scheduleEnabled
                    }
                    New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 2 -Content {
                        New-UDButton -Id 'saveAzureDiscoveryScheduleBtn' -Text 'Save' -Variant 'contained' -Color 'primary' -ShowLoading -OnClick {
                            try {
                                $cadence = [string](Get-UDElement -Id 'azureDiscoveryScheduleCadence').value
                                $scope = [string](Get-UDElement -Id 'azureDiscoveryScheduleScope').value
                                $enabled = [bool](Get-UDElement -Id 'azureDiscoveryScheduleEnabled').checked

                                $cron = switch ($cadence) {
                                    'daily' { '0 2 * * *' }
                                    'weekly' { '0 2 * * 1' }
                                    default { throw "Unsupported scheduled discovery cadence '$cadence'." }
                                }

                                Devolutions.CIEM\Set-CIEMAzureDiscoverySchedule -Scope $scope -Cron $cron -Enabled $enabled | Out-Null
                                Sync-UDElement -Id 'azureDiscoveryScheduleStatus'
                                Show-UDToast -Message 'Scheduled discovery saved.' -Duration 5000 -BackgroundColor '#4caf50'
                            }
                            catch {
                                Devolutions.CIEM\Write-CIEMLog -Message "Save scheduled discovery failed: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-ConfigPage'
                                Show-UDToast -Message "Scheduled discovery save failed: $($_.Exception.Message)" -Duration 10000 -BackgroundColor '#f44336'
                            }
                        }
                    }
                }

                New-UDDynamic -Id 'azureDiscoveryScheduleStatus' -Content {
                    $currentSchedule = @(Devolutions.CIEM\Get-CIEMAzureDiscoverySchedule) | Select-Object -First 1
                    if ($currentSchedule) {
                        $state = if ($currentSchedule.Enabled) { 'Enabled' } else { 'Disabled' }
                        $lastStatus = if ($currentSchedule.LastStatus) { $currentSchedule.LastStatus } else { 'No scheduled run recorded' }
                        New-UDTypography -Text "$state - $($currentSchedule.Scope) - $($currentSchedule.Cron) - $lastStatus" -Variant 'caption' -Style @{ color = '#666' }
                    }
                    else {
                        New-UDTypography -Text 'Disabled - no schedule configured' -Variant 'caption' -Style @{ color = '#666' }
                    }
                }
            }
        }

        New-UDCard -Title 'Notification Channels' -Content {
            $notificationChannel = @(Devolutions.CIEM\Get-CIEMNotificationChannel -Id 'email-default') | Select-Object -First 1
            $notification = @(Devolutions.CIEM\Get-CIEMNotification -Id 'exposure-change-default') | Select-Object -First 1
            $selectedAutoSendScope = if ($notification) { [string]$notification.AutoSendScope } else { 'AnyDiscovery' }
            $selectedMinimumSeverity = if ($notification) { [string]$notification.MinimumSeverity } else { 'High' }
            $selectedChangeTypes = if ($notification) { @($notification.ChangeTypes) } else { @('NewRisk', 'RiskIncrease') }

            New-UDGrid -Container -Spacing 2 -Content {
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 3 -Content {
                    $channelEnabled = if ($notificationChannel) { [bool]$notificationChannel.Enabled } else { $false }
                    New-UDSwitch -Id 'notificationChannelEnabled' -Label 'Email Channel Enabled' -Checked $channelEnabled
                }
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 9 -Content {
                    New-UDTextbox -Id 'notificationFromAddress' -Label 'From Address' -Value $notificationChannel.FromAddress -FullWidth -Placeholder 'ciem@example.com'
                }
                New-UDGrid -Item -ExtraSmallSize 12 -Content {
                    New-UDTextbox -Id 'notificationToRecipients' -Label 'To Recipients' -Value (@($notificationChannel.ToRecipients) -join ', ') -FullWidth -Placeholder 'security@example.com, it@example.com'
                }
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                    New-UDTextbox -Id 'notificationCcRecipients' -Label 'Cc Recipients' -Value (@($notificationChannel.CcRecipients) -join ', ') -FullWidth
                }
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                    New-UDTextbox -Id 'notificationBccRecipients' -Label 'Bcc Recipients' -Value (@($notificationChannel.BccRecipients) -join ', ') -FullWidth
                }
            }

            New-UDElement -Tag 'div' -Attributes @{ style = @{ marginTop = '16px'; marginBottom = '16px' } } -Content {
                New-UDDivider
            }

            New-UDGrid -Container -Spacing 2 -Content {
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 3 -Content {
                    $notificationEnabled = if ($notification) { [bool]$notification.Enabled } else { $false }
                    New-UDSwitch -Id 'notificationEnabled' -Label 'Exposure Change Notification Enabled' -Checked $notificationEnabled
                }
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 3 -Content {
                    New-UDSelect -Id 'notificationAutoSendScope' -Label 'Auto-send Scope' -DefaultValue $selectedAutoSendScope -FullWidth -Option {
                        New-UDSelectOption -Name 'Any Discovery' -Value 'AnyDiscovery'
                        New-UDSelectOption -Name 'Scheduled Discovery' -Value 'ScheduledDiscovery'
                        New-UDSelectOption -Name 'Manual Only' -Value 'ManualOnly'
                    }
                }
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 3 -Content {
                    New-UDSelect -Id 'notificationMinimumSeverity' -Label 'Minimum Severity' -DefaultValue $selectedMinimumSeverity -FullWidth -Option {
                        New-UDSelectOption -Name 'Critical' -Value 'Critical'
                        New-UDSelectOption -Name 'High' -Value 'High'
                        New-UDSelectOption -Name 'Medium' -Value 'Medium'
                        New-UDSelectOption -Name 'Low' -Value 'Low'
                        New-UDSelectOption -Name 'Info' -Value 'Info'
                    }
                }
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 3 -Content {
                    New-UDStack -Direction 'row' -Spacing 1 -Content {
                        New-UDSwitch -Id 'notificationChangeTypeNewRisk' -Label 'New' -Checked ($selectedChangeTypes -contains 'NewRisk')
                        New-UDSwitch -Id 'notificationChangeTypeRiskIncrease' -Label 'Increased' -Checked ($selectedChangeTypes -contains 'RiskIncrease')
                        New-UDSwitch -Id 'notificationChangeTypeRemovedRisk' -Label 'Removed' -Checked ($selectedChangeTypes -contains 'RemovedRisk')
                    }
                }
                New-UDGrid -Item -ExtraSmallSize 12 -Content {
                    $subjectTemplate = if ($notification) { $notification.SubjectTemplate } else { '[CIEM] {{Severity}} exposure: {{Title}}' }
                    New-UDTextbox -Id 'notificationSubjectTemplate' -Label 'Subject Template' -Value $subjectTemplate -FullWidth
                }
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                    $textTemplate = if ($notification) { $notification.TextBodyTemplate } else { "Exposure change: {{Title}}`nSeverity: {{Severity}}`nEvidence: {{Evidence}}" }
                    New-UDTextbox -Id 'notificationTextBodyTemplate' -Label 'Plain Text Body Template' -Value $textTemplate -Multiline -Rows 5 -FullWidth
                }
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                    $htmlTemplate = if ($notification) { $notification.HtmlBodyTemplate } else { '<p><strong>{{Severity}}</strong>: {{Title}}</p><p>{{Evidence}}</p>' }
                    New-UDTextbox -Id 'notificationHtmlBodyTemplate' -Label 'HTML Body Template' -Value $htmlTemplate -Multiline -Rows 5 -FullWidth
                }
                New-UDGrid -Item -ExtraSmallSize 12 -Content {
                    New-UDStack -Direction 'row' -Spacing 2 -Content {
                        New-UDButton -Id 'saveNotificationsBtn' -Text 'Save Notifications' -Variant 'contained' -Color 'primary' -ShowLoading -OnClick {
                            try {
                                $parseRecipients = {
                                    param([string]$RecipientText)
                                    if ([string]::IsNullOrWhiteSpace($RecipientText)) { return }
                                    foreach ($recipient in ($RecipientText -split ',')) {
                                        $trimmedRecipient = $recipient.Trim()
                                        if (-not [string]::IsNullOrWhiteSpace($trimmedRecipient)) { $trimmedRecipient }
                                    }
                                }

                                $toRecipients = [string[]]@(& $parseRecipients ([string](Get-UDElement -Id 'notificationToRecipients').value))
                                $ccRecipients = [string[]]@(& $parseRecipients ([string](Get-UDElement -Id 'notificationCcRecipients').value))
                                $bccRecipients = [string[]]@(& $parseRecipients ([string](Get-UDElement -Id 'notificationBccRecipients').value))

                                Devolutions.CIEM\Set-CIEMNotificationChannel `
                                    -Enabled ([bool](Get-UDElement -Id 'notificationChannelEnabled').checked) `
                                    -FromAddress ([string](Get-UDElement -Id 'notificationFromAddress').value) `
                                    -ToRecipients $toRecipients `
                                    -CcRecipients $ccRecipients `
                                    -BccRecipients $bccRecipients | Out-Null

                                $changeTypes = @()
                                if ([bool](Get-UDElement -Id 'notificationChangeTypeNewRisk').checked) { $changeTypes += 'NewRisk' }
                                if ([bool](Get-UDElement -Id 'notificationChangeTypeRiskIncrease').checked) { $changeTypes += 'RiskIncrease' }
                                if ([bool](Get-UDElement -Id 'notificationChangeTypeRemovedRisk').checked) { $changeTypes += 'RemovedRisk' }

                                Devolutions.CIEM\Set-CIEMNotification `
                                    -Enabled ([bool](Get-UDElement -Id 'notificationEnabled').checked) `
                                    -AutoSendScope ([string](Get-UDElement -Id 'notificationAutoSendScope').value) `
                                    -ChangeTypes $changeTypes `
                                    -MinimumSeverity ([string](Get-UDElement -Id 'notificationMinimumSeverity').value) `
                                    -SubjectTemplate ([string](Get-UDElement -Id 'notificationSubjectTemplate').value) `
                                    -TextBodyTemplate ([string](Get-UDElement -Id 'notificationTextBodyTemplate').value) `
                                    -HtmlBodyTemplate ([string](Get-UDElement -Id 'notificationHtmlBodyTemplate').value) | Out-Null

                                Sync-UDElement -Id 'notificationHistoryTable'
                                Show-UDToast -Message 'Notifications saved.' -Duration 5000 -BackgroundColor '#4caf50'
                            }
                            catch {
                                Devolutions.CIEM\Write-CIEMLog -Message "Save notifications failed: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-ConfigPage'
                                Show-UDToast -Message "Notification save failed: $($_.Exception.Message)" -Duration 10000 -BackgroundColor '#f44336'
                            }
                        }
                        New-UDButton -Id 'testNotificationEmailBtn' -Text 'Test Email' -Variant 'outlined' -Color 'secondary' -ShowLoading -OnClick {
                            try {
                                $sendResult = Devolutions.CIEM\Send-CIEMNotification -InvocationSource 'Manual' -Test
                                Sync-UDElement -Id 'notificationHistoryTable'
                                Show-UDToast -Message "Test email completed: $($sendResult.SentCount) sent." -Duration 5000 -BackgroundColor '#4caf50'
                            }
                            catch {
                                Devolutions.CIEM\Write-CIEMLog -Message "Test notification failed: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-ConfigPage'
                                Sync-UDElement -Id 'notificationHistoryTable'
                                Show-UDToast -Message "Test email failed: $($_.Exception.Message)" -Duration 10000 -BackgroundColor '#f44336'
                            }
                        }
                    }
                }
            }

            New-UDDynamic -Id 'notificationHistoryTable' -Content {
                $historyRows = @(Devolutions.CIEM\Get-CIEMNotificationHistory -Last 10)
                if ($historyRows.Count -eq 0) {
                    New-UDTypography -Text 'No notification history.' -Variant 'caption' -Style @{ color = '#666'; marginTop = '16px' }
                }
                else {
                    New-UDTable -Data $historyRows -Columns @(
                        New-UDTableColumn -Property 'AttemptedAt' -Title 'Attempted'
                        New-UDTableColumn -Property 'Status' -Title 'Status'
                        New-UDTableColumn -Property 'SourceSignalId' -Title 'Source'
                        New-UDTableColumn -Property 'RecipientSummary' -Title 'Recipients'
                        New-UDTableColumn -Property 'ErrorMessage' -Title 'Error'
                    ) -Dense
                }
            }
        } -Style @{ marginTop = '24px' }
    } -Navigation $Navigation -NavigationLayout permanent
}
