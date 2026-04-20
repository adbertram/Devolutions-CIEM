---
name: "status-reports"
description: "MANDATORY: Use this skill for ALL Devolutions CIEM weekly status report operations \u2014 sending reports to the team AND checking for replies. DO NOT draft Slack status updates with `git log` + `slack` CLI directly. DO NOT read the team group DM directly to check replies. Triggers: \"send status report\", \"weekly update\", \"status report\", \"update the team\", \"dryrun status report\", \"preview status report\", \"check status report replies\", \"any replies on the status report\", \"did the team reply\", \"status report feedback\"."
argument-hint: "[send|replies] [dryrun]"
---

<objective>
Manage CIEM weekly status reports to the Devolutions team group DM `C0AFCLP7SUF`. Two workflows: generate and send a new report, or fetch replies to the most recent report.
</objective>

<quick_start>
1. Route the request to either the send workflow or the check-replies workflow.
2. Read the selected workflow file before running Slack, git, screenshot, or send-script commands.
3. Keep all report artifacts under `{baseDir}/reports/YYYY-MM-DD/`.
4. Use `--profile devolutions` for every Slack operation.
</quick_start>

<key_facts>
- **Team channel:** `C0AFCLP7SUF` (group DM with mamoreau, schalifoux, alistek, adbertram)
- **Slack profile:** `devolutions` — always pass `--profile devolutions`
- **Report archive:** `{baseDir}/reports/YYYY-MM-DD/` — each week is a folder containing `report.md` (and optionally `*.png` screenshots if the user requested them)
- **Screenshots are OPTIONAL:** Text-only is the default. Only capture screenshots when the user explicitly asks (e.g., "with screenshots", "include screenshots")
- **Send script:** `{baseDir}/scripts/send-report.sh` (supports `--dryrun`)
- **Dryrun target:** DM to `adbertram` (Adam) for personal preview before team send
</key_facts>

<intake>
Route based on user intent:

- "send", "weekly update", "send the status report", "dryrun" → **send workflow**
- "replies", "feedback", "did anyone respond", "check replies" → **check-replies workflow**

If ambiguous, ask once which one.
</intake>

<workflow_index>
| Intent | Workflow |
|--------|----------|
| Generate and send a new weekly report | [workflows/send.md](workflows/send.md) |
| Fetch replies to the most recent report | [workflows/check-replies.md](workflows/check-replies.md) |
</workflow_index>

<success_criteria>
- Correct workflow selected based on user intent
- All Slack operations use `--profile devolutions` and channel `C0AFCLP7SUF`
- Reports always read from / written to `{baseDir}/reports/`
</success_criteria>
