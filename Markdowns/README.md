# Nexthink Remote Action Reference Documentation

Complete component references for writing Nexthink Remote Action scripts, one per platform. They exist to answer the question *"what does this script actually need before Nexthink will run it, pass it inputs, and store its outputs?"* — in one place, without hunting through documentation pages.

| Reference | Platform | Language |
|---|---|---|
| [nexthink-remote-actions-windows-reference.md](nexthink-remote-actions-windows-reference.md) | Windows | PowerShell |
| [nexthink_mac_remote_actions_reference.md](nexthink_mac_remote_actions_reference.md) | macOS | Bash / Zsh |

---

## What these cover

Both references are organized the same way, and each ends with a **Quick-Reference Checklist** you can work through before uploading a script:

- **Environment requirements** — file encoding and line endings, supported shells and language modes, script size and input/output limits.
- **Inputs** — how to declare parameters so Nexthink detects them, and how values actually arrive at your script (always as strings).
- **Outputs** — every write method, its data type, and its exact constraints, plus the rules for a valid output schema (predefined names, fixed count, no dynamic fields, no loops).
- **Campaigns** — every function for displaying a campaign and reading the employee's response, including all status values.
- **Execution context and timeout** — local system vs. interactive user vs. service, and what happens when a script runs long.
- **Error handling** — exit codes, how to guarantee a correct one, and where your error text surfaces in the Nexthink web interface.
- **Signing and packaging** — certificates, trust stores, execution policies, and the platform-specific packaging rules.

Each reference cites its sources and carries a "last verified" date. They also flag two places where the official documentation itself is wrong or misleading, with the corrected form noted inline.

## How to use them

If you're converting an existing script into a Remote Action, the practical order is:

1. Read the **environment requirements** first — encoding and line endings silently break scripts, and they're the easiest thing to get wrong.
2. Wire up **inputs**, remembering every value arrives as a string and needs validating and converting.
3. Design a **static output schema** — decide your field names and count up front, then write every field on every run.
4. Add **error handling** that guarantees a non-zero exit on failure and writes something useful to stderr.
5. Work the **checklist** at the end of the reference before you upload.

---

## ⚠ If you used AI to write or convert your script — verify it yourself

These references work well as context for an AI assistant converting a script into a Remote Action. That is a genuinely useful workflow. It is also one that fails quietly, and the failure lands on your endpoints.

**Assume the AI got something wrong until you have checked it yourself.**

Common failure modes worth checking for specifically:

- **Plausible but invented API.** An AI will confidently produce method names, parameters, or output types that do not exist. Check every Nexthink call against the reference tables — not against what looks right.
- **Wrong values that still run.** Passing the wrong format to a date/time output, exceeding a numeric range, or truncating a string produces bad data rather than an error. You will not notice until you're reporting on it.
- **Broken output schema.** Outputs generated in a loop, or written only on the success path, produce missing or inconsistent fields — the platform expects a fixed, predictable schema.
- **Silent success.** A script that exits `0` after doing nothing looks identical to one that worked. Confirm the change actually happened on the device, not just that the action reported success.
- **Scope creep on destructive actions.** A deletion, service stop, or registry change that the AI "helpfully" broadened is the single most dangerous outcome. Re-read every line that removes, stops, disables, or overwrites something, and confirm it targets exactly what you intended — and nothing else.
- **Environment assumptions.** Install paths, service names, and registry keys are frequently guessed from training data rather than from your environment. Verify each one against a real device.

**Then test it properly:** run it on a disposable lab machine first, then a small pilot group you control, and only then broadly. Read the script end to end yourself before any of that. An AI's explanation of what a script does is not evidence of what it does — the code is.

The references themselves were compiled with AI assistance against the official Nexthink documentation, and carry the same caveat: verify anything load-bearing against the current official docs, which change over time.

---

## No warranty

Provided **as is**, with no warranty of any kind, and no guarantee of accuracy or completeness. The official Nexthink documentation is the authority — these are a convenience layer over it, accurate as of the verification date each file states. See the [repository README](../README.md) and [LICENSE](../LICENSE).

Not affiliated with, endorsed by, or supported by Nexthink S.A.
