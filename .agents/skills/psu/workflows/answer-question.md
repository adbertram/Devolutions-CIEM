<required_reading>
- [references/agent-knowledge.md](../references/agent-knowledge.md)
</required_reading>

<process>
<step_1>
Open `docs/psu-docs/SUMMARY.md` and identify the relevant documentation area.
</step_1>

<step_2>
Search `docs/psu-docs` for exact names from the question. Use cmdlet names, API route fragments, configuration keys, component names, and quoted error text.
</step_2>

<step_3>
Read the smallest set of local docs needed to answer. For cmdlets, read `docs/psu-docs/cmdlets/<CmdletName>.txt` when present.
</step_3>

<step_4>
Answer from the local docs and extracted PSU expert knowledge. Cite the local file paths used.
</step_4>
</process>

<success_criteria>
- [ ] The answer is grounded in `docs/psu-docs` or extracted agent knowledge
- [ ] Local source files are cited
- [ ] Web search is not used unless explicitly requested
</success_criteria>

