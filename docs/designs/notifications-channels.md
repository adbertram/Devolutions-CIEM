# Notifications Channels Feature

## Problem

CIEM can detect exposure changes, but it has no built-in way to notify users outside the dashboard. Security teams need exposure-change alerts delivered through a configurable channel. The first useful version should support email without coupling email authentication details to channel routing. The feature must remain read-only with respect to cloud and PAM systems.

## Technical Plan

The feature adds a `Devolutions.CIEM.Notifications` module area with notification-specific classes, database-backed CRUD commands, SMTP rendering/sending logic, and Configuration page controls. The Email channel uses the generic authentication profile assignment model, so SMTP server/auth settings live in an `Email` authentication profile and recipient routing lives in the channel. `Send-CIEMNotification` reads the single enabled Exposure Change notification, filters exposure changes, renders text and HTML bodies, sends through the enabled Email channel, and records simple rows in `notification_history`.

```mermaid
flowchart LR
    Discovery["Azure Discovery"] --> Changes["Exposure Changes"]
    Changes --> Send["Send-CIEMNotification"]
    Config["Configuration Page"] --> Notification["Notification Template"]
    Config --> Channel["Email Channel"]
    Config --> AuthProfile["Email Auth Profile"]
    Notification --> Send
    Channel --> Send
    AuthProfile --> Send
    Send --> SMTP["SMTP Server"]
    Send --> History["notification_history"]
```

## Alternatives Considered

Provider-specific authentication profile models were replaced by a single generic profile and assignment model for Azure, AWS, and Email. This is a cutover design for new deployments; legacy notification authentication storage is not migrated.

A delivery-attempt class was considered for history. The chosen design stores history as simple rows and returns PSCustomObjects because delivery history is audit data, not a domain object requiring class behavior.

Seeding a default notification was considered. The chosen design creates tables only; users create the single notification and email channel from Configuration.

## Detailed Implementation

**`docs/designs/notifications-channels.md`** - created  
Rationale: Durable design record for the notification subsystem and its explicit scope boundaries.

**`psu-app/Data/module_roots.psdata`** - modified  
Rationale: Register `Devolutions.CIEM.Notifications` so classes and public/private commands are loaded.

**`psu-app/data/schema.sql`** - modified  
Rationale: Add idempotent generic authentication profile, assignment, notification channel, notification, and history tables.

**`psu-app/modules/Devolutions.CIEM.Notifications/**`** - created  
Rationale: New module root for notification classes, public CRUD commands, send command, and private helpers.

**`psu-app/modules/Devolutions.CIEM.PSU/Pages/New-CIEMConfigPage.ps1`** - modified  
Rationale: Keep notification routing, filters, templates, test email, and delivery history on Configuration while moving authentication profile management to the Authentication Profiles page.

**`psu-app/modules/Devolutions.CIEM.PSU/Tests/Unit/PageCommandQualification.Tests.ps1`** - modified  
Rationale: Permit new notification commands used from PSU page endpoints, while still enforcing module qualification.

**`psu-app/modules/Devolutions.CIEM.Notifications/Tests/Unit/*.Tests.ps1`** - created  
Rationale: Pester coverage for schema, class structure, CRUD behavior, send behavior, history rows, and source-level discovery wiring.

**`psu-app/ui/e2e/pages/Configuration/ConfigurationPageHelpers.js`** - modified  
Rationale: Add selectors and helper methods for the Notifications section.

**`psu-app/ui/e2e/pages/Configuration/Configuration.test.js`** - modified  
Rationale: Cover notification routing fields, test email action, and history table visibility.

Ordering: tests are written and run before implementation; implementation then updates schema, module root, notification commands, Configuration UI, and discovery wiring. If an implementation discovery requires additional files, update this design before adding them.
