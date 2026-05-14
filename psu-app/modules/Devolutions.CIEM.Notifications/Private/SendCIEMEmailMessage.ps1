function SendCIEMEmailMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$AuthenticationProfile,

        [Parameter(Mandatory)]
        [pscustomobject]$Channel,

        [Parameter(Mandatory)]
        [string]$Subject,

        [Parameter(Mandatory)]
        [string]$TextBody,

        [Parameter(Mandatory)]
        [string]$HtmlBody
    )

    $ErrorActionPreference = 'Stop'

    if ($AuthenticationProfile.Provider -ne 'Email') {
        throw "Authentication profile '$($AuthenticationProfile.Id)' must have provider Email."
    }
    if ($Channel.Type -ne 'Email') {
        throw "Notification channel '$($Channel.Id)' must be type Email."
    }

    $message = [System.Net.Mail.MailMessage]::new()
    $smtpClient = [System.Net.Mail.SmtpClient]::new($AuthenticationProfile.Settings.Host, [int]$AuthenticationProfile.Settings.Port)
    try {
        $message.From = [System.Net.Mail.MailAddress]::new($Channel.FromAddress)
        foreach ($recipient in @($Channel.ToRecipients)) {
            [void]$message.To.Add([string]$recipient)
        }
        foreach ($recipient in @($Channel.CcRecipients)) {
            [void]$message.CC.Add([string]$recipient)
        }
        foreach ($recipient in @($Channel.BccRecipients)) {
            [void]$message.Bcc.Add([string]$recipient)
        }

        $message.Subject = $Subject
        $message.Body = $TextBody
        $message.IsBodyHtml = $false
        [void]$message.AlternateViews.Add([System.Net.Mail.AlternateView]::CreateAlternateViewFromString($TextBody, $null, 'text/plain'))
        [void]$message.AlternateViews.Add([System.Net.Mail.AlternateView]::CreateAlternateViewFromString($HtmlBody, $null, 'text/html'))

        switch ($AuthenticationProfile.Settings.TlsMode) {
            'None' { $smtpClient.EnableSsl = $false }
            'StartTls' { $smtpClient.EnableSsl = $true }
            'Ssl' { $smtpClient.EnableSsl = $true }
            default { throw "Unsupported SMTP TLS mode '$($AuthenticationProfile.Settings.TlsMode)'." }
        }

        switch ($AuthenticationProfile.Method) {
            'SmtpAnonymous' {
                $smtpClient.UseDefaultCredentials = $false
                $smtpClient.Credentials = $null
            }
            'SmtpBasic' {
                $password = $AuthenticationProfile.Secrets.Password
                if ([string]::IsNullOrEmpty($password)) {
                    throw "Secret '$($AuthenticationProfile.SecretRefs.Password)' did not return a password."
                }
                $smtpClient.UseDefaultCredentials = $false
                $smtpClient.Credentials = [System.Net.NetworkCredential]::new([string]$AuthenticationProfile.Settings.Username, $password)
            }
            default {
                throw "Unsupported SMTP authentication method '$($AuthenticationProfile.Method)'."
            }
        }

        $smtpClient.Send($message)

        [PSCustomObject]@{
            MessageId = [guid]::NewGuid().ToString()
        }
    }
    finally {
        $message.Dispose()
        $smtpClient.Dispose()
    }
}
