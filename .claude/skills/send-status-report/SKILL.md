---
name: send-status-report
description: >-
  MANDATORY: Invoke this skill IMMEDIATELY when the user wants to send a weekly status report, weekly update, or progress update to the Devolutions CIEM team via Slack. DO NOT draft or send Slack status updates without loading this skill first. DO NOT use git log or slack CLI directly for status reports. Triggers: "send status report", "weekly update", "status report", "update the team", "send my weekly update", "dryrun status report", "preview status report".
invocation: user
argument-hint: "[dryrun]"
---

<objective>
Generate and send a weekly CIEM project status report to the Devolutions team group DM. Creates a timestamped report folder with text and screenshots, shows for approval, then sends via a dedicated script. Reports describe user-facing features (NO git/branch references) and ask for directional feedback.

Supports a `dryrun` mode: when the skill is invoked with "dryrun" in the arguments, the report is sent as a Slack DM to Adam (adbertram) for personal review instead of the team channel. After reviewing the dryrun, Adam can approve sending to the team by re-invoking without dryrun.
</objective>

<quick_start>
1. Gather git log from the past week (internal reference only — never exposed in report)
2. Create timestamped report folder: `reports/YYYY-MM-DD/`
3. Capture screenshots of new/updated CIEM app pages via Playwright
4. Write `report.md` in the report folder
5. Show the full report (text + screenshots) to Adam for approval
6. Run `scripts/send-report.sh` to send — use `--dryrun` to DM Adam first, or omit for team channel
</quick_start>

<workflow>
**Step 1 — Gather Recent Work (Internal Only)**

Run git log to understand what changed. This is for YOUR reference to write the summary — NEVER include branch names, commit hashes, merge references, or any git terminology in the report.

```bash
git log --since="1 week ago" --oneline --no-merges
```

Group changes into user-facing themes (e.g., "new Identity Risk page", "attack path visualization", "environment management"). Think about what a product stakeholder cares about, not what a developer committed.

**Step 2 — Create Report Folder**

Create a timestamped folder under the skill's `reports/` directory:

```bash
mkdir -p .claude/skills/send-status-report/reports/$(date +%Y-%m-%d)
```

All report artifacts (text + screenshots) go in this folder.

**Step 3 — Capture Screenshots**

Load the `playwright-cli` skill, then navigate the CIEM app and capture screenshots of new or updated features. Save them directly into the report folder.

The CIEM app runs at `http://localhost:5001/ciem/ciem/`. If local PSU is not running, start it first via `./scripts/setup-local-psu.sh start`.

**Screenshot capture pattern (per page):**

```bash
playwright-cli open http://localhost:5001/ciem/ciem/<page>       ## open browser
sleep 5                                                          ## wait for UDDynamic render
playwright-cli snapshot                                          ## verify content loaded
playwright-cli screenshot --filename "<report-dir>/<page-name>.png" --full-page

playwright-cli goto http://localhost:5001/ciem/ciem/<next-page>  ## next page
sleep 5
playwright-cli snapshot
playwright-cli screenshot --filename "<report-dir>/<next-page>.png" --full-page

playwright-cli close                                             ## done
```

**Why the wait:** PSU pages use `New-UDDynamic` which loads content asynchronously. Without waiting, screenshots capture loading skeletons (gray bars) or empty containers instead of actual content. 5 seconds is the minimum — pages with graphs (Environment, Attack Paths) or tables with many rows may need longer.

Common pages:
- `/ciem/ciem/` — Dashboard/home
- `/ciem/ciem/identities` — Identities page
- `/ciem/ciem/identity-risk` — Identity Risk page
- `/ciem/ciem/attack-paths` — Attack Paths page
- `/ciem/ciem/environment` — Environment page
- `/ciem/ciem/scan` — Scan page
- `/ciem/ciem/scan-history` — Scan History page
- `/ciem/ciem/configuration` — Configuration page

Only screenshot pages relevant to this week's work.

**MANDATORY: Review every screenshot before keeping it.** After capturing each screenshot, Read the image file to visually inspect it. Check for:

| Problem | Action |
|---------|--------|
| "Page Not Found" | Page not deployed to local PSU — delete screenshot, skip this page |
| Loading skeletons (gray bars) | Page didn't finish rendering — `sleep 5`, retake |
| Spinners still visible | Async content still loading — `sleep 5`, retake |
| Blank/empty content area | May need data (run a discovery first) or longer wait — try `sleep 10`, retake |
| Content renders but is cut off | Use `--full-page` flag (already default in pattern above) |

**Retry up to 2 times** with increasing wait (5s, then 10s). If still bad after 2 retakes, delete the screenshot — do not include bad screenshots in the report.

**Step 4 — Write report.md**

Write `report.md` in the report folder. Use Adam's Slack voice:
- Casual, direct, no corporate speak
- Lead with a brief greeting ("Hey guys, here's what I've been working on this week:")
- Use bullet points for each major accomplishment — describe FEATURES and VALUE, not implementation details
- Use Slack formatting: `*bold*` for feature names (NOT `**bold**`)
- NO git branches, commit hashes, merge references, or technical build details
- Mention what's coming next if relevant
- Keep it concise — 5-10 bullet points max
- **End by asking for feedback**: "Does this direction look good to you guys? Any feedback or priorities you'd like me to shift toward?" or similar casual ask

**Step 5 — Show for Approval**

Display the full report to Adam:
1. Show the text of `report.md`
2. Show each screenshot (Read the image files)
3. Ask: "Send this? Any changes?"

Do NOT proceed to Step 6 without explicit approval.

**Step 6 — Send via Script**

Check if the skill was invoked with "dryrun" in the arguments. If so, use `--dryrun` to send the report as a DM to Adam (adbertram) for review instead of the team channel.

```bash
# Dryrun mode — sends to Adam's DM for review
.claude/skills/send-status-report/scripts/send-report.sh --dryrun .claude/skills/send-status-report/reports/YYYY-MM-DD

# Normal mode — sends to the team channel
.claude/skills/send-status-report/scripts/send-report.sh .claude/skills/send-status-report/reports/YYYY-MM-DD
```

The script:
1. Uploads all `*.png` files (screenshots appear first)
2. Sends the `report.md` text as the message
3. In `--dryrun` mode, screenshots and text go to Adam's DM (adbertram) instead of the team channel

After a dryrun, Adam can request sending to the team by re-invoking the skill without "dryrun".

Channel C0AFCLP7SUF members: Marc-Andre Moreau (mamoreau), Simon Chalifoux (schalifoux), Adam Listek (alistek), Adam Bertram (adbertram).
</workflow>

<rules>
- **NEVER include git terminology** in the report: no branch names, commit hashes, merge references, PR numbers, or "merged to main"
- **NEVER describe implementation details** the team doesn't care about: no "refactored X", "extracted helper", "added E2E tests", "fixed FK constraints"
- **ALWAYS frame work as features/capabilities**: "Added an Identity Risk page that shows risk signals per identity" NOT "Merged identity-risk branch with risk signals, summary functions, and Pester tests"
- **ALWAYS include screenshots** of new/updated UI features — discard bad ones (404s, loading states)
- **ALWAYS ask for directional feedback** at the end of the report
- **ALWAYS get Adam's approval** before sending
- **ALWAYS use the send script** (`scripts/send-report.sh`) — never send screenshots or text manually
</rules>

<success_criteria>
- [ ] Git log from past week has been gathered (internal reference only)
- [ ] Report folder created at `reports/YYYY-MM-DD/`
- [ ] Screenshots captured and reviewed (bad ones removed)
- [ ] `report.md` written with user-facing feature descriptions
- [ ] Report ends with a feedback ask
- [ ] Full report (text + screenshots) shown to Adam and approved
- [ ] `scripts/send-report.sh` executed and delivery confirmed
</success_criteria>
