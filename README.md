# Nexthink — Scripts & Reference Material

A personal collection of Nexthink Remote Action scripts and reference documentation, shared publicly in case it saves someone else time.

Everything here comes from real work on real endpoints, but it is published **as is** — as a starting point for your own work, not as a finished product you can drop into production.

---

## ⚠ Read this before you use anything here

**No warranty. Use at your own risk. Proceed with extreme caution.**

- All content is provided **as is**, with **no warranty of any kind**, express or implied. See [LICENSE](LICENSE).
- I am not responsible for any damage, downtime, data loss, security exposure, or support burden that results from using this material.
- Several scripts here perform **destructive or security-affecting actions** — stopping endpoint security services, uninstalling agents, deleting registry keys and program directories. Run against the wrong device, or at the wrong time, they will cause real harm.
- Remote Actions execute **across your fleet, with system privileges, without a confirmation prompt**. A mistake does not affect one machine — it affects every machine you targeted, at once.

### Minimum safe practice

1. **Read every line before you run anything.** If you don't understand what a line does, don't run it.
2. **Test on a device you can afford to break** — a lab VM or a spare machine — before anything else.
3. **Pilot on a small group** (a handful of devices you control) before any broad targeting.
4. **Verify against your own environment.** Service names, install paths, registry keys, and OS versions differ between organizations and change between vendor releases. What matched my environment may not match yours.
5. **Know your rollback** before you execute, especially for anything that stops security tooling or removes software.
6. **Follow your own change management.** Your organization's review and approval process exists for exactly this kind of change.

---

## What's in here

| Folder | Contents |
|---|---|
| **[Markdowns/](Markdowns/)** | Reference documentation for writing Nexthink Remote Action scripts — a complete component reference for Windows/PowerShell and macOS/Bash. Start here if you're converting an existing script into a Remote Action. |
| **[Scripts/](Scripts/)** | PowerShell scripts, one folder per target product. Each folder has its own README describing what the script does and what it affects. |

### Scripts at a glance

| Script | Purpose | Risk |
|---|---|---|
| [Scripts/Crowdstrike/](Scripts/Crowdstrike/) | Stops the CrowdStrike Falcon services (`csagent`, `csfalconservice`). | 🔴 **High** — disables endpoint security protection. |
| [Scripts/Tanium/](Scripts/Tanium/) | Fully removes the Tanium Client — stops processes/services, runs the uninstaller, deletes the install directory and registry keys. | 🔴 **High** — irreversible removal of a management agent. |
| [Scripts/Windows/](Scripts/Windows/) | Reports the last successful logon (Security event ID 4624) and days elapsed. | 🟢 **Low** — read-only. |

> **Note on Remote Action compliance:** not every script here is a fully compliant Remote Action yet. Some are standalone PowerShell that still needs input/output plumbing (`param()` block, `nxtremoteactions.dll`, `[Nxt]::WriteOutput*` calls) before Nexthink can pass it parameters or store its results. Each script's README states where it stands. The references in [Markdowns/](Markdowns/) explain exactly what a compliant script requires.

---

## About this repository

This is a personal project, maintained on personal time, and shared because the Nexthink community is small and good examples are hard to find. It is **not** an official Nexthink resource and is not affiliated with, endorsed by, or supported by Nexthink S.A. Product names and trademarks belong to their respective owners.

**There is no support.** I may not respond to issues, and I may change or remove content without notice. Nothing here is guaranteed to work with your Collector version, your platform version, or your OS build.

If you find a genuine bug or an outdated fact, an issue or pull request is welcome — but treat this as a snapshot of what worked for me, not a maintained product.

---

## License

[MIT](LICENSE). The license text includes the formal "as is, without warranty of any kind" clause — the plain-English version is the warning at the top of this file.
