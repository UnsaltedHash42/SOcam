# AI-assisted reversing — `labs/ai-re/` is not the class pack

**Student readings, setup steps, and agent prompts are in this repo under [`docs/course/ai-re/`](../../docs/course/ai-re/README.md)** (same GitHub repo; different path). Open that folder on GitHub or clone and go to `docs/course/ai-re/STUDENT_GUIDE.md`.

| What you want | Path |
|---------------|------|
| Copy-paste SSH + `setup-keep.sh` | [`docs/course/ai-re/SETUP.md`](../../docs/course/ai-re/SETUP.md) |
| Main walkthrough | [`docs/course/ai-re/STUDENT_GUIDE.md`](../../docs/course/ai-re/STUDENT_GUIDE.md) |
| Prompts + Plan-B shell | [`docs/course/ai-re/STUDENT_QUICK_REFERENCE.md`](../../docs/course/ai-re/STUDENT_QUICK_REFERENCE.md) |
| Worksheet | [`docs/course/ai-re/case-studies/tutorial-daemon-planted.md`](../../docs/course/ai-re/case-studies/tutorial-daemon-planted.md) |
| Optional Lab II | [`docs/course/ai-re/LAB_II.md`](../../docs/course/ai-re/LAB_II.md) |

---

Unlike Chapters 02 and 08, **runnable lab code** for this unit does not live under `labs/`. The executable target and scripts ship in **mac-reversing-station** (separate repo, below).

**Chapter 8 prerequisite:** you should already understand Mach-named XPC listeners, `shouldAcceptNewConnection:`, and why privileged helpers are high-value targets — see [`docs/course/ch08-xpc/STUDENT_GUIDE.md`](../../docs/course/ch08-xpc/STUDENT_GUIDE.md). This unit adds the **agent-driven pass loop** (intake → scan → triage → confirm → PoC → chain) on top of that surface.

**<https://github.com/UnsaltedHash42/mac-reversing-station>**

You will end up with **two clones** of that repo (this is intentional — see [`../../docs/course/ai-re/diagrams.md`](../../docs/course/ai-re/diagrams.md) figure 2):

| Clone | Location (suggested) | Purpose |
|-------|----------------------|---------|
| **Station home** | `~/tools/mac-reversing-station/` (or any name) | One per workstation. Runs `setup-keep.sh`, owns `Skills/`, `scripts/`, `ghidra-scripts/`, `templates/`. **Never** commit per-target findings here. |
| **Project clone** | `~/re/tutorial-daemon-class/` | One per investigation. Runs `init-project.sh`. Holds `LAB_SAFETY.md`, `CORPUS.md`, `findings/`, `artifacts/`, `pocs/`. |

## What's in the station repo

The teaching code referenced in [`STUDENT_GUIDE.md`](../../docs/course/ai-re/STUDENT_GUIDE.md), in the order the course uses it:

| Path (in the station repo) | What it is | Used in |
|----------------------------|------------|---------|
| `scripts/setup-keep.sh` | One-shot install: links skills, installs Ghidra + `ghidra-mcp` + `macre-vm-mcp` on the lab host, writes MCP config for Cursor and Claude Code | Session 0 |
| `scripts/smoke-wave3.sh` | Structural and (`--live`) smoke checks | Session 0 |
| `scripts/init-project.sh` | Bootstraps a per-target project clone from `templates/findings-repo/` | Session C |
| `scripts/start-target.py` | Intake — produces a dossier under `findings/analysis/` | Session C |
| `scripts/rsync-to-vm.sh` | Sync `targets/` directory to lab host, record path mapping in `CORPUS.md` | Session C |
| `scripts/triage.py` | Candidate state machine. Subcommands: `create`, `transition`, `list`, `validate`, `render`, `show`, `import-tsv` | Sessions E, G |
| `scripts/lab-health.sh` | Find stale Ghidra sessions / orphan headless sidecars on the lab host | Troubleshooting |
| `ghidra-scripts/scan_wrong_door.py` | Wrong-door XPC scan — multiple listeners, no branching | Session D |
| `ghidra-scripts/dump_xpc_listeners.py` | Verified listener / delegate-method extraction | Session D |
| `ghidra-scripts/scan_xpc_client_validation.py` | `SecTask*` / `xpc_dictionary_get_value` / entitlement-check anchors | Session D |
| `templates/tutorial-target/bin/tutorial_daemon` | The planted daemon (Mach-O thin arm64, 75 KB) — **pre-built in git; no compile for class** | Sessions C–H+ |
| `templates/tutorial-target/build.sh` | Optional rebuild → `bin/tutorial_daemon` (`clang` + ad-hoc `codesign`) | Only if you changed source or need Intel |
| `templates/tutorial-target/src/tutorial_daemon.m` | Daemon source — three labeled bugs + one red herring entitlement | After class (read with the answer key) |
| `templates/tutorial-target/plists/com.tutorial.daemon.privileged.plist` | LaunchDaemon plist declaring two MachServices | Session F install |
| `templates/findings-repo/` | What `init-project.sh` rsyncs into your project clone — `LAB_SAFETY.md`, `CORPUS.md`, `INDEX.md`, `SCRIPTORIUM.md`, `CHRONICLE.md`, `METRICS.md`, `HANDOFF.md.template`, `VM_ACTIONS.md`, `machines.md.template` | Sessions C–H+ |
| `templates/tutorial-target-2/PluginHost.app` | Multi-binary bundle (Lab II) — **pre-built in git; no compile for class** | [`LAB_II.md`](../../docs/course/ai-re/LAB_II.md) |
| `templates/tutorial-target-2/build.sh` | Optional rebuild → `PluginHost.app/` | Only if you changed source or need Intel |
| `macre-vm-mcp/` (Python package) | The `macre-vm-mcp` MCP server. Tools: `lldb_run_anchors`, `lldb_run`, `lldb_break_and_inspect`, `dtrace_oneliner`, `dtrace_script`, `codesign_inspect`, `entitlement_dump`, `spctl_assess`, `log_stream`, `launchctl_list`, `launchctl_print`, `launchd_machservices`, `system_extension_list`, `framework_dependency_map`, `procinfo`, `hash_target`, `os_build_snapshot` | Sessions D, F |
| `Skills/offensive-macos-bundle-intake/SKILL.md` | Intake skill the agent fires on "start a pass on …" | Session C |
| `Skills/offensive-macos-watch-static-analysis/SKILL.md` | Watch / decision-layer skill | Session C |
| `Skills/offensive-macos-hunt-wrong-door/SKILL.md` | Wrong-door playbook | Session D |
| `Skills/offensive-macos-gatehouse-ghidra-lldb/SKILL.md` | Static-anchor → lldb-stop handoff | Session F |
| `Skills/offensive-macos-poc-authoring/SKILL.md` | PoC-authoring discipline | Sessions F, H, H+ |
| `Skills/offensive-macos-chain-discovery/SKILL.md` | Multi-primitive chain discovery (next-chapter preview) | Session I wrap |

Student guides and copy-paste setup: [`docs/course/ai-re/SETUP.md`](../../docs/course/ai-re/SETUP.md) · [STUDENT_GUIDE Session 0](../../docs/course/ai-re/STUDENT_GUIDE.md#session-0--lab-setup-do-these-steps-in-order).

---

## Quickstart

Full numbered steps: [`docs/course/ai-re/STUDENT_GUIDE.md`](../../docs/course/ai-re/STUDENT_GUIDE.md#session-0--lab-setup-do-these-steps-in-order).

1. VM + Remote Login + snapshot  
2. `~/.ssh/config` → `Host lab-mac` (see guide for the block)  
3. `git clone` → `setup-keep.sh --host lab-mac --remote-home /Users/student --vm-password '…' --lab-disposable --live-smoke`  
4. Project clone + you fill `LAB_SAFETY.md` / `machines.md`  
5. First agent prompt: [QUICK_REFERENCE § 0.7](../../docs/course/ai-re/STUDENT_QUICK_REFERENCE.md#07--orientation-first-agent-prompt)

---

## Why no code in this folder?

- **PoC code is gitignored** by station template. It belongs in your **project clone**'s `pocs/` directory, never the station and never this course repo.
- **The planted daemon binary belongs in the station repo.** Mirroring it under `labs/ai-re/` would mean two copies drifting independently.
- **Lab targets are pre-built** in the station repo (`bin/tutorial_daemon`, `PluginHost.app`). Students run `./build.sh` only to rebuild after editing source or on an Intel lab host — see [README.md — Pre-built vs compile](../../docs/course/ai-re/README.md#pre-built-vs-compile).
- **PoC clients** are compiled in the project clone (`pocs/`) during Sessions F / H / H+ — not mirrored under `labs/ai-re/`.

If you find yourself wanting to put code here, you probably want it in your **project clone** under `pocs/<target>/` instead.

---

## Troubleshooting (top of the list — full set in `STUDENT_GUIDE.md`)

- **MCP servers don't appear in the agent.** Restart Cursor / Claude Code after `setup-keep.sh`. New MCPs only show on a fresh launch.
- **`sudo` over SSH prompts for a password.** Re-run `setup-keep.sh ... --vm-password '<lab-pw>' --lab-disposable` from the **station home**.
- **`rsync-to-vm.sh` rejects your binary path.** Pass the `targets/` **directory**, not a single file.
- **Ghidra session is locked.** Run `bash scripts/lab-health.sh --remove-stale` from the station home.
- **Connection invalid when the client runs.** Re-bootstrap the daemon: `sudo launchctl bootout system /Library/LaunchDaemons/com.tutorial.daemon.privileged.plist` then `bootstrap` again.
