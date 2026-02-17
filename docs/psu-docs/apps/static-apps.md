---
description: Build static web apps with PowerShell Universal.
---

# Static Apps

Static PowerShell Universal apps do not require the PowerShell Universal server to run. They can be hosted on simple web servers like Azure Blobs or in IIS directly from the file system. They consist of the PowerShell Universal App JavaScript framework and a series of JSON files created during the publish process. Static apps do not support PowerShell Universal's interactive features. They do support running JavaScript.&#x20;

## Building a Static App&#x20;

The `Publish-PSUStaticApp` cmdlet is responsible for building an app. You can use standard App cmdlets in the definition. For example, the below would create an app in the output folder with a single UDRating component.&#x20;

```powershell
Publish-PSUStaticApp -Definition { 
    New-UDApp -Content { 
       New-UDRating -Max 10 
    } 
} -DestinationPath .\output -Force 
```

You can also introduce JavaScript call into your app anywhere that an endpoint can be used. For example, in the `-OnChange` parameter of `New-UDRating`. The data variable will contain the data from the event.&#x20;

```powershell
Publish-PSUStaticApp -Definition {
   New-UDApp -Content {
      New-UDRating -Max 10 -OnChange (New-UDEndpoint -JavaScript 'alert(data)') 
   } 
} -DestinationPath .\output -Force 
```

## Publishing a Static App

Static apps can be published to any webserver that can server HTML, JavaScript and CSS files. You will need to publish the entire output folder's contents for the app to work.&#x20;

## Limitations

### No App Interaction&#x20;

You cannot use interactive features of PowerShell Universal Apps, besides JavaScript. This includes but not limited to:&#x20;

* Modals and toasts&#x20;
* -UDElement Cmdlets&#x20;
* Data Providers like $Cache and $Session&#x20;

### No PowerShell Host Interaction

During the building of the app, all the script blocks within the app will run, rather than run on demand, like when hosted in PowerShell Universal. This means that commands such as `Write-Host` and `Write-Error` will happen during the building and not when the app is running in the browser. The following will also run immediately:&#x20;

* `Read-Host`
* `PromptForChoice`
* `Get-Credential`&#x20;

### Limited Control Support&#x20;

Although it is possible to use any control and specify the JavaScript for it's interaction, it is not recommended due to the complexity. Controls that should be avoided include:&#x20;

* Data Grid
* Dynamic Region
* Protect Section
