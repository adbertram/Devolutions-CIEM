# Check Replies on Latest Status Report

<objective>
Fetch and summarize replies/reactions from the Devolutions CIEM team group DM (`C0AFCLP7SUF`) for the most recent status report. Reports the latest team feedback so Adam can act on it.
</objective>

<process>

**Step 1 — Identify the latest report**

```bash
ls -1 {baseDir}/reports/ | sort | tail -1
```

This is the most recent report folder name (date string `YYYY-MM-DD`). It establishes the cutoff: messages newer than this date are potential replies.

**Step 2 — Fetch recent messages from the team channel**

```bash
slack --profile devolutions dm read C0AFCLP7SUF --limit 30
```

Returns a JSON object with a `messages` array. Each message has:
- `from` — `"You"` (Adam) or the sender's display name (e.g., `"Simon C."`)
- `ts` — Unix timestamp (string, with fractional seconds)
- `text` — message body
- `files` — uploaded screenshots (status-report uploads)

**Step 3 — Filter for team replies after the report send**

Replies are messages where `from != "You"`. Use Python (jq is awkward with the nested structure) to extract them:

```bash
slack --profile devolutions dm read C0AFCLP7SUF --limit 30 \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
for m in d['messages']:
    sender = m.get('from')
    if sender == 'You': continue
    ts = m.get('ts', '')
    text = (m.get('text') or '').strip()
    print(f'--- {sender} (ts={ts}) ---')
    print(text)
    print()
"
```

**Step 4 — Get full text of a single reply (if truncated)**

If a reply is long and you want only one message's full text:

```bash
slack --profile devolutions dm read C0AFCLP7SUF --limit 30 \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['messages'][0].get('text'))"
```

(Index `[0]` is the most recent message; adjust as needed.)

**Step 5 — Report findings to Adam**

Present each team reply with:
- Sender name
- Approximate date (convert `ts` to readable date if helpful)
- Full message text
- Brief interpretation (endorsement / concern / question / new ask)

If there are no replies from anyone other than `"You"`, say so explicitly: "No replies from the team on the latest report."

</process>

<rules>
- **ALWAYS use `--profile devolutions`** — the slack CLI has multiple profiles
- **Channel ID is fixed:** `C0AFCLP7SUF` — never query other channels
- **Filter `from == "You"`** to exclude Adam's own report messages and screenshot uploads
- **NEVER use `slack channels history`** — that command doesn't exist; use `slack dm read` even for group DMs
- **Report findings verbatim** — don't paraphrase team feedback; quote it
</rules>

<success_criteria>
- [ ] Latest report folder identified
- [ ] `slack dm read C0AFCLP7SUF` executed with `--profile devolutions`
- [ ] Replies filtered to exclude `from == "You"`
- [ ] Each team reply presented with sender, timestamp, and full text
- [ ] If no replies, explicitly state "no replies"
</success_criteria>