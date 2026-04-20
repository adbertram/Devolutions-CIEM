# Send Weekly Status Report

<objective>
Generate and send a weekly CIEM project status report to the Devolutions team group DM. Creates a timestamped report folder with the text, shows for approval, then sends via the dedicated script. Reports describe user-facing features (NO git/branch references).

Screenshots are OPTIONAL. Do NOT capture screenshots unless the user explicitly asks for them (e.g., "include screenshots", "with screenshots", "add screenshots"). Text-only reports are the default.

Supports `dryrun` mode: invoke with "dryrun" in the arguments to send the report as a DM to Adam (adbertram) for personal review instead of the team channel. After reviewing, re-invoke without "dryrun" to send to the team.
</objective>

<process>

**Step 1 — Gather Recent Work (Internal Only)**

Run BOTH git log AND git status to understand what changed. Pending uncommitted work is in-progress but still real progress — include it in the report. This is for YOUR reference only — NEVER include branch names, commit hashes, merge references, file paths, or any git terminology in the report.

```bash
## Committed work from the past week
git log --since="1 week ago" --oneline --no-merges

## Pending uncommitted work (staged + unstaged + untracked)
git status --short

## Dig into pending changes to understand what they represent
git diff --stat
git diff --stat --cached
```

For any pending changes that look meaningful (new files, new pages, new features), read the files briefly to understand what they add. Example: a new `attack_paths/*.json` file is a new attack path pattern being added to the catalog — that's user-facing progress worth mentioning.

Group ALL changes (committed + pending) into user-facing themes (e.g., "new Identity Risk page", "attack path visualization", "environment management"). Think about what a product stakeholder cares about, not what a developer committed. Pending work can be framed as "in progress" or "adding X this week".

**Step 2 — Create Report Folder**

```bash
mkdir -p {baseDir}/reports/$(date +%Y-%m-%d)
```

All report artifacts (text + screenshots) go in this folder.

**Step 3 — Capture Screenshots (OPTIONAL — skip by default)**

Screenshots are OPTIONAL. **Skip this step entirely unless the user explicitly asks for screenshots** (e.g., "include screenshots", "with screenshots", "add screenshots"). Default is text-only reports — faster to produce, reliable, and what the user wants most of the time.

If — and only if — the user asked for screenshots, load the `playwright-cli` skill, then navigate the CIEM app and capture screenshots of new or updated features. Save them directly into the report folder.

<details>
<summary>Screenshot capture instructions (only when user asks)</summary>

The CIEM app runs at `http://192.168.86.30:5001/ciem/ciem/` (LOCAL_PSU_URL from .env). If PSU is not running, start it via `ssh adam-server 'sudo launchctl kickstart -k system/com.psu.server'`.

**Capture pattern (per page):**

```bash
playwright-cli open http://localhost:5001/ciem/ciem/<page>
sleep 5                                                          ## wait for UDDynamic render
playwright-cli snapshot                                          ## verify content loaded
playwright-cli screenshot --filename "<report-dir>/<page-name>.png" --full-page

playwright-cli goto http://localhost:5001/ciem/ciem/<next-page>
sleep 5
playwright-cli snapshot
playwright-cli screenshot --filename "<report-dir>/<next-page>.png" --full-page

playwright-cli close
```

**Why the wait:** PSU pages use `New-UDDynamic` which loads content asynchronously. Without waiting, screenshots capture loading skeletons or empty containers. 5s minimum; pages with graphs or large tables may need longer.

Common pages:
- `/ciem/ciem/` — Dashboard/home
- `/ciem/ciem/identities` — Identities
- `/ciem/ciem/identity-risk` — Identity Risk
- `/ciem/ciem/attack-paths` — Attack Paths
- `/ciem/ciem/environment` — Environment
- `/ciem/ciem/scan` — Scan
- `/ciem/ciem/scan-history` — Scan History
- `/ciem/ciem/configuration` — Configuration

Only screenshot pages relevant to this week's work.

**Review every screenshot before keeping it.** Read each image file to inspect it.

| Problem | Action |
|---------|--------|
| "Page Not Found" | Page not deployed — delete screenshot, skip page |
| Loading skeletons (gray bars) | Page didn't finish rendering — `sleep 5`, retake |
| Spinners still visible | Async still loading — `sleep 5`, retake |
| Blank/empty content | May need data (run discovery) or longer wait — try `sleep 10`, retake |
| Content cut off | Use `--full-page` (already default) |

Retry up to 2 times with increasing wait (5s then 10s). If still bad, delete the screenshot — never include bad screenshots.

</details>

**Step 4 — Write report.md**

Write `report.md` in the report folder. Use Adam's Slack voice:
- Casual, direct, no corporate speak
- Lead with brief greeting ("Hey guys, here's what I've been working on this week:")
- Bullet points for accomplishments — describe FEATURES and VALUE, not implementation
- Slack formatting: `*bold*` (NOT `**bold**`)
- NO git branches, commit hashes, merge references, or technical build details
- Mention what's coming next if relevant
- 5-10 bullets max
- Do NOT append a generic direction or priority feedback question.

**Step 5 — Show for Approval**

Display the full report to Adam:
1. Show the text of `report.md`
2. Show each screenshot (Read the image files)
3. Ask: "Send this? Any changes?"

Do NOT proceed to Step 6 without explicit approval.

**Step 6 — Send via Script**

If invoked with "dryrun" argument, use `--dryrun` to DM Adam (adbertram) instead of the team channel.

```bash
## Dryrun — sends to Adam's DM for review
{baseDir}/scripts/send-report.sh --dryrun {baseDir}/reports/YYYY-MM-DD

## Normal — sends to team channel
{baseDir}/scripts/send-report.sh {baseDir}/reports/YYYY-MM-DD
```

The script uploads all `*.png` files first (screenshots appear above the message), then sends `report.md` text. After a dryrun, Adam can re-invoke the skill without "dryrun" to send to the team.

Channel `C0AFCLP7SUF` members: Marc-Andre Moreau (mamoreau), Simon Chalifoux (schalifoux), Adam Listek (alistek), Adam Bertram (adbertram).

</process>

<rules>
- **NEVER include git terminology** in the report: no branch names, commits, merges, PR numbers
- **NEVER describe implementation details**: no "refactored X", "extracted helper", "added tests", "fixed FK constraints"
- **NEVER capture screenshots** unless the user explicitly asks for them — text-only is the default
- **ALWAYS frame work as features/capabilities**
- **NEVER append a generic direction or priority feedback question**
- **ALWAYS get Adam's approval** before sending
- **ALWAYS use the send script** — never send screenshots or text manually
</rules>

<success_criteria>
- [ ] Git log from past week gathered (internal only)
- [ ] Report folder created at `{baseDir}/reports/YYYY-MM-DD/`
- [ ] Screenshots captured ONLY if user explicitly asked (otherwise skip entirely)
- [ ] `report.md` written with user-facing language
- [ ] Report does not include a generic direction or priority feedback question
- [ ] Full report shown to Adam and approved
- [ ] `scripts/send-report.sh` executed and delivery confirmed
</success_criteria>
