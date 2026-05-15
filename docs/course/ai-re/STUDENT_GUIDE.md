# Student guide: macOS Reversing Station

This guide replaces reliance on the course PDF. Session letters are suggestions; your instructor may merge or split them. Total time end-to-end is **~3–3.5 hours in class** if the lab environment is already built (Session 0 complete). Budget **another 1–2 hours** the first time you build a VM and run `setup-keep.sh` (downloads ~400 MB to the lab host).

> **Pre-class — finish Session 0 (Steps 1–9) before class.** Class starts at **Step 9 (orientation)** or Session A. First `setup-keep.sh` run takes ~15 minutes. Arrive with smoke green, project clone ready, and `LAB_SAFETY.md` / `machines.md` filled in by you.

**Minimal note-taking:** keep **[`STUDENT_QUICK_REFERENCE.md`](STUDENT_QUICK_REFERENCE.md)** open during the lab — **agent prompts by session** (primary), Plan-B shell fallback, and the triage cheatsheet. Paste prompts into your agent; read prose here for *why*.

**No Drive downloads.** The planted daemon and `PluginHost.app` are already built in the station repo (`templates/`). You only compile small PoC clients under `pocs/` in your project clone (Sessions F, H, H+).

| Session (this guide) | Primary code / doc |
|----------------------|--------------------|
| 0 — Lab setup (Steps 1–8 human, Step 9 agent) | [Session 0](#session-0--lab-setup-do-these-steps-in-order) |
| Step 9 — Orientation | [QUICK_REFERENCE § 0.7](STUDENT_QUICK_REFERENCE.md#07--orientation-first-agent-prompt) |
| A — Why a station | *Concept only* — diagrams [`diagrams.md`](diagrams.md) figures 1–2 |
| B — The pass loop | [`labs/ai-re/README.md`](../../../labs/ai-re/README.md) + [`diagrams.md`](diagrams.md) figure 3 |
| C — Intake on the planted daemon | Station repo: `templates/tutorial-target/bin/tutorial_daemon` |
| D — Static sweep via `ghidra-mcp` | Station scan scripts: `ghidra-scripts/scan_wrong_door.py`, `dump_xpc_listeners.py`, `scan_xpc_client_validation.py` |
| E — Triage and the red herring | `scripts/triage.py` (state machine) |
| F — lldb confirmation | `macre-vm-mcp` tool `lldb_run_anchors` |
| G — Closure, METRICS, HANDOFF | `INDEX.md`, `SCRIPTORIUM.md`, `HANDOFF.md` |
| H — Unprivileged PoC (reachability) | `pocs/client/` (gitignored) — agent runs `/tmp/client` without `sudo` |
| H+ — Chain to root primitive | `pocs/chain-delete/` — `resetCacheAtPath:` deletes a root-owned sentinel |
| I — Wrap and what to try next | Station: `Skills/offensive-macos-chain-discovery/SKILL.md`, `TARGET_QUEUE.md` |
| **Case study worksheet** | [`case-studies/tutorial-daemon-planted.md`](case-studies/tutorial-daemon-planted.md) — fill as you go (Sessions C–H+) |
| Lab II (separate; not part of the 3-hour spine) | [`LAB_II.md`](LAB_II.md) — multi-binary bundle pass against `PluginHost.app` |

---

## How this unit relates to Chapter 8

Chapter 8 taught **what XPC is** and how privileged helpers fail trust checks (`shouldAcceptNewConnection:`, audit token, entitlements). This unit teaches **how to run a repeatable investigation** when the target is unfamiliar and the toolchain is heavy.

| Chapter 8 idea | This unit's equivalent |
|----------------|------------------------|
| Mach service + listener + client | Same — planted daemon has **two** Mach names, one delegate |
| Session D attack checklist | Session D scans + Session E triage; wrong-door is the trust failure |
| Case-study arc: reachability → primitive → impact | Sessions F–H+: confirm → unprivileged PoC → root file delete |
| Copy-paste builds in quick reference | **Agent prompts** primary; Plan-B shell in quick reference |

You should already know: **Mach service name**, **`NSXPCConnectionPrivileged`**, **`listener:shouldAcceptNewConnection:`**, and why **PID alone is a weak gate**. If not, read [Chapter 8 Session A–D](../ch08-xpc/STUDENT_GUIDE.md) before class.

**Deliverable for this lab:** not a slide deck — a **project clone** with dossier, scan TSVs, candidate JSON, hash-pinned transcripts, PoCs under `pocs/`, and a `HANDOFF.md` your agent can resume from cold. Use the **[case study worksheet](case-studies/tutorial-daemon-planted.md)** the same way Chapter 8 uses the WiFiSpoof / Shove / Zoom worksheets — fill blanks as you complete each session.

### Project clone — what each file is for

`init-project.sh` copies these from the station template. Know them before class ends:

| File | Purpose |
|------|---------|
| `LAB_SAFETY.md` | Agent reads before dynamic work — lab role, disposability, allowed tests |
| `machines.md` | Workstation vs lab host aliases, SSH users |
| `CORPUS.md` | Target inventory, path mappings, facts that survive the whole pass |
| `findings/analysis/` | Dossiers and scan TSVs (tier A/B/C evidence) |
| `findings/candidates/` | One JSON per triage candidate (C-001, …) |
| `artifacts/` | lldb transcripts, PoC stdout — **hash-pin in `SCRIPTORIUM.md`** |
| `SCRIPTORIUM.md` | Anchors: claim → artifact path → SHA-256 |
| `INDEX.md` | Rendered roll-up of candidates (`triage.py render`) |
| `METRICS.md` | Pass-level counts (confirmed, closed-with-rationale, …) |
| `HANDOFF.md` | Resume document for the next agent session |
| `VM_ACTIONS.md` | Append-only log of install / PoC / tear-down on the lab host |
| `CHRONICLE.md` | Short narrative notes (optional but useful in class) |
| `pocs/` | Gitignored PoC sources and binaries — **per pass, per target** |

---

## Sessions C–H+ — Planted daemon case study (primary lab)

This unit's **hands-on spine** is one controlled target — the planted `tutorial_daemon` — walked with the same **case-study arc** as Chapter 8 Sessions F–H. The difference is tooling: you drive an **agent** and the station scripts instead of only Hopper notes and a one-off PoC.

**Worksheet (fill during class):** [case-studies/tutorial-daemon-planted.md](case-studies/tutorial-daemon-planted.md)

**Typical arc** (map every pass to these five questions):

1. **Reachability:** Who can open which Mach surface? (Sessions C, H — plist names, unprivileged client.)
2. **Trust failure:** Which Session D checklist item failed? (Wrong door: listener does not branch; InternalOps ungated.)
3. **Primitive:** What can an attacker ask the daemon to do? (`writeAuditLog:`, `resetCacheAtPath:` — Session D decomp.)
4. **Impact:** What changed on disk as **root** that UID 501 could not do alone? (Session H+ sentinel delete.)
5. **Fix:** What would you change in `shouldAcceptNewConnection:` and handler auth? (Session I — design bullets.)

**Runnable code:** station `templates/tutorial-target/` · **Agent prompts:** [STUDENT_QUICK_REFERENCE.md](STUDENT_QUICK_REFERENCE.md) · **Plan-B shell:** same file, bottom section.

**Exploitation stance (course policy):** PoCs run **only** on the disposable lab host with the planted daemon. The chain demo uses a sentinel under `/tmp/` — not system paths that could brick a shared VM.

---

## Session 0 — Lab setup (do these steps in order)

**Two machines:** your Mac runs the agent; a **VM** (the lab host) runs Ghidra and lldb over SSH. See [`diagrams.md`](diagrams.md) figure 1.

**Two clones of the same GitHub repo:**

| Clone | Path | Use for |
|-------|------|---------|
| Station home | `~/tools/mac-reversing-station/` | `setup-keep.sh`, skills, install scripts |
| Project | `~/re/tutorial-daemon-class/` | Agent work, findings, `LAB_SAFETY.md` |

Do **Steps 1–8** in the terminal. **Step 9** is the first time you open the agent.

---

### Step 1 — VM

1. New macOS VM (UTM, Fusion, Parallels). Apple Silicon guest if your Mac is Apple Silicon.  
2. Install macOS. One **admin** lab user (example: `student`). Remember the password.  
3. **System Settings → General → Sharing → Remote Login → On**.  
4. Note the VM IP. Snapshot the VM (powered off).

---

### Step 2 — SSH config (workstation)

Edit `~/.ssh/config` on your Mac (not inside the VM):

```
Host lab-mac
  HostName 192.168.64.2
  User student
  ServerAliveInterval 30
```

Change `HostName` to your VM IP and `User` to your lab username.

```bash
ssh lab-mac 'uname -m; sw_vers -productVersion'
test -f ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
```

Password prompt is OK once. You want `arm64`.

---

### Step 3 — Station home

```bash
git clone https://github.com/UnsaltedHash42/mac-reversing-station ~/tools/mac-reversing-station
cd ~/tools/mac-reversing-station
```

---

### Step 4 — `setup-keep.sh`

```bash
scripts/setup-keep.sh \
  --host lab-mac \
  --remote-home /Users/student \
  --vm-password 'YOUR_VM_PASSWORD' \
  --lab-disposable \
  --live-smoke
```

Match `--remote-home` to `/Users/<your-lab-username>`. First run takes ~15 minutes (downloads Ghidra to the VM).

**What you should see** (approximate order):

1. Skills linked for Cursor / Claude Code (or run Step 6 `skill-link` scripts if setup skipped that).
2. Message that **SSH key login** to `lab-mac` works without a password.
3. **Long download** phase on the VM (JDK / Ghidra / MCP).
4. **NOPASSWD sudo** confirmation for your lab user (because of `--lab-disposable`).
5. **Smoke passes**, ending with **`[OK]`** lines from **`smoke-wave3.sh --live`** (especially `program_open`-style checks).

If you ran setup **without** `--live-smoke`, run:

```bash
bash scripts/skill-link-claude-code.sh
# or: bash cursor/skill-link.sh
bash scripts/smoke-wave3.sh
MACRE_MACHINE=lab-mac bash scripts/smoke-wave3.sh --live
```

One-file copy-paste version of Steps 2–8: [**SETUP.md**](SETUP.md).

---

### Step 5 — Exports and IDE restart

```bash
# add to ~/.zshrc
export MACRE_MACHINE=lab-mac
export MACRE_REMOTE_TARGETS=/Users/student/Targets
```

Quit and reopen Cursor or Claude Code.

---

### Step 6 — Verify

```bash
ssh -o BatchMode=yes lab-mac 'echo ssh-ok'
ssh -o BatchMode=yes lab-mac 'sudo -n true && echo sudo-ok'
cd ~/tools/mac-reversing-station
MACRE_MACHINE=lab-mac bash scripts/smoke-wave3.sh --live
```

If `sudo-ok` fails, re-run Step 4 with `--lab-disposable` and the correct password.

---

### Step 7 — Project clone

```bash
mkdir -p ~/re && cd ~/re
git clone https://github.com/UnsaltedHash42/mac-reversing-station tutorial-daemon-class
cd tutorial-daemon-class
scripts/init-project.sh --name tutorial-daemon-class
```

Open this folder in your agent from here on.

---

### Step 8 — Safety files (you write these)

Edit `machines.md` and `LAB_SAFETY.md` in the project clone. Say the VM is disposable and what tests are allowed. The agent **reads** these; do not ask it to invent policy.

---

### Step 9 — Agent orientation (first prompt)

Workspace: `~/re/tutorial-daemon-class/`.  
Prompt: [STUDENT_QUICK_REFERENCE.md](STUDENT_QUICK_REFERENCE.md) § **0.7 — Orientation**.

**Done when:** **`READY FOR PASS`**. No intake, no daemon install.

---

### Session 0 checklist

| Step | Done when |
|------|-----------|
| 1 | VM up, Remote Login on, snapshot saved |
| 2 | `ssh lab-mac` works; `arm64` |
| 3–4 | `setup-keep.sh` finished |
| 5–6 | IDE restarted; smoke `--live` OK; `sudo -n` OK |
| 7–8 | Project clone; you filled LAB_SAFETY + machines |
| 9 | Orientation → **READY FOR PASS** |

---

## Session A — Why a station

### What is the reversing station? (concept)

A **bug-hunting pass** on macOS today touches four expensive things: **static analysis** (Ghidra projects, decompilation), **dynamic analysis** (lldb attach, breakpoints), **environment truth** (codesign, entitlements, launchd state), and **evidence** (you must prove what you claimed six months later). The **Reversing Station** packages those into a repeatable loop with an agent in the middle.

**Why it matters for security:** the planted target is an XPC daemon — the same **privileged-helper** shape as Chapter 8. The station does not replace XPC knowledge; it replaces ad-hoc notes and one-off shell history with **files the agent and your future self can read**.

**Vocabulary:**

- **MCP** (Model Context Protocol) — the wire between your agent and a tool server. Each MCP server exposes named **tools** (`program_open`, `decomp_function`, `lldb_run_anchors`, `entitlement_dump`, …) that the agent calls.
- **Pass** — one investigation against one target. Pass IDs look like `PASS-001` or `PASS-CLASS-001`.
- **Closure rationale** — the deliverable of a pass. "This looked exploitable but isn't, here's why" is research output and counts in `METRICS.md`.

**Lab:** *Concept only — no commands this session.*

**Do (paper exercise):**

1. Sketch [`diagrams.md`](diagrams.md) figure 1 from memory: two boxes (workstation, lab host), name one MCP per arrow.
2. List three things that go on each box. (Workstation: agent client, `triage.py`, project clone. Lab host: Ghidra, lldb, target binary.)

**Discuss:** Why is `task_for_pid` a workstation-vs-lab-host argument by itself? Why would you refuse to run Ghidra headless on the same Mac where you read email?

**Reading:** [`diagrams.md`](diagrams.md) figures 1–2; station repo `README.md` § How it works.

---

## Session B — The pass loop

### What is a pass? (concept)

A **pass** is one investigation of **one target** under one **pass ID** (`PASS-CLASS-001`). Everything you produce — dossier, scans, candidates, transcripts, PoCs — hangs off that ID. Starting a second target means a **second project clone**, not a second folder under the same pass.

The loop is deliberately **narrow**: one recipe, one stop condition, one dynamic confirmation at a time. On real apps the agent will suggest six scans at once; your job is to push back until you have tier-A evidence for the claim you are making.

**Goals:** Walk the eight-step pass loop and name the file each step writes.

**The loop** (read along; don't run yet):

```
intake -> sync -> watch -> recipe -> scan -> triage -> confirm -> record
            ^                                                       |
            +-------------------------------------------------------+
```

| Step | Tool | Output |
|------|------|--------|
| Intake | `python3 scripts/start-target.py <path> --pass-id PASS-NNN` | Dossier under `findings/analysis/`, CORPUS row |
| Sync | `MACRE_MACHINE=<host> scripts/rsync-to-vm.sh --record <target-slug> ./targets/` | Path-mapping row in `CORPUS.md` |
| Watch | Agent prompt (no script) | Recommendation: one recipe + one stop condition |
| Recipe | Agent runs `ghidra-mcp` script via MCP | TSVs under `findings/analysis/` |
| Scan | Same as recipe (just emphasizing the *output* artifacts) | Three-tier anchor TSVs |
| Triage | `scripts/triage.py create --id C-NNN ...` | Candidate JSON under `findings/candidates/` |
| Confirm | `macre-vm-mcp` tool `lldb_run_anchors` (agent-driven) | Transcript under `artifacts/`, hash-pinned |
| Record | `triage.py transition` + manual edits | `INDEX.md`, `SCRIPTORIUM.md`, `CHRONICLE.md`, `HANDOFF.md` |

**Rules of thumb:**

- One recipe, one stop condition. If the agent recommends six scans at once, push back.
- Tier A first. False-positive density goes up as evidence quality goes down: A = decompiled callsite with literal arg, B = Mach-O / ObjC metadata, C = string heuristic.
- Closures with rationale count. There is **no `interesting` state** — you either promote a candidate or close it with a reason.

**Lab:** [`labs/ai-re/README.md`](../../../labs/ai-re/README.md) — two-clone convention (station home vs project clone).

**Debug habit:** When the agent reports a script failure, ask it to paste **stderr** and the **working directory** — half of pass bugs are "ran from station home instead of project clone."

**Exercise (conceptual):** Map each loop step to whether it touches the lab host. (Intake: workstation only. Sync: both. Watch: workstation only. Recipe / scan / confirm: lab host. Triage / record: workstation.)

**Discuss:** Which steps must never run on a production Mac? Which steps could run on the workstation but are pushed to the lab host by design?

**Reading:** [`diagrams.md`](diagrams.md) figure 3 (pass loop); [`labs/ai-re/README.md`](../../../labs/ai-re/README.md) path table.

---

## Session C — Intake on the planted daemon

**Worksheet:** [case-studies/tutorial-daemon-planted.md](case-studies/tutorial-daemon-planted.md) §§ 1–2 (surface map, intake gap).

### What is intake? (concept)

**Intake** is automated first contact with a binary or bundle: Mach-O layout, linked frameworks, rough **family labels** (privileged helper, OS component, Electron app, …), and a **dossier** JSON under `findings/analysis/`. Intake is not a verdict — it is routing input for the **watch** layer (which recipe to run next).

**Why bare-binary intake is incomplete here:** launchd **MachServices** and embedded **entitlements** often live outside the Mach-O you pointed at — in a plist on disk or in the codesign blob. Real passes routinely pair intake with `plutil` / `codesign` (your agent can do this via the cli-static skill). Treat empty `mach_services` in the dossier as a **signal to look elsewhere**, not as "no XPC."

**Goals:** Run intake against a real binary, read the dossier, and identify the **family labels** that drive recipe selection.

**The target:** `templates/tutorial-target/bin/tutorial_daemon` — a 183-line Objective-C daemon that ships in the station repo. **Three deliberate vulnerabilities + one red herring** in 75 KB of binary. Comments in the source label them `BUG 1`, `BUG 2`, `BUG 3`. *Don't read the source yet.*

**Vocabulary:**

- **Family label** — the routing axis the watch layer uses. Playbooks exist for: privileged helpers and updaters, developer tools, OS components, TCC-heavy consumer apps, enterprise agents.
- **Surface** — a category of attacker-reachable interface (XPC service, IOKit user client, MIG subsystem, URL scheme, Endpoint Security client, …).
- **Dossier** — the JSON the intake step writes. Family labels, surfaces, components, plus (when the input is an `.app` bundle) MachServices and helper bundles.
- **One launchd job, multiple MachServices.** Chapter 8 mostly showed one Mach name per launchd plist. The planted daemon's plist registers **two** names (`com.tutorial.daemon.privileged` and `com.tutorial.daemon.internal`) under the same `Label` and `Program`. This is legal launchd, common in real privileged helpers, and the exact shape that enables the wrong-door bug — one process answers two doorbells.

**NSXPC on this target (Chapter 8 recap):** the daemon is Objective-C **NSXPC** — `NSXPCListener` per Mach name, `NSXPCListenerDelegate`, remote **`@protocol`** methods with reply blocks. Session F's client uses `initWithMachServiceName:options:` and `remoteObjectInterface` exactly like `02_nsxpcclient` in Chapter 8, but the server exports the **wrong** interface on the **wrong** listener.

**Lab:** Project clone (Session 0 Steps 7–9 done) · station `templates/tutorial-target/`.

**Prerequisite:** Orientation returned **READY FOR PASS**. You already filled `LAB_SAFETY.md` and `machines.md` — the agent only reads them.

**Do (drive your agent — do not run scripts at the shell):**

1. Confirm orientation stuck — agent workspace is `~/re/tutorial-daemon-class/`, not station home.

2. Start the pass:

   > **Agent prompt:**
   > ```
   > Start a pass on templates/tutorial-target/bin/tutorial_daemon as PASS-CLASS-001. Use the bundle-intake skill. Show me the dossier path when intake completes.
   > ```

   The agent invokes `start-target.py` for you. It will report the dossier file (`findings/analysis/PASS-CLASS-001-tutorial-daemon-dossier.json`) and the target slug (`tutorial-daemon`).

3. Read the dossier through the agent — it knows what to look for:

   > **Agent prompt:**
   > ```
   > Read the PASS-CLASS-001 dossier and summarize family_labels, surfaces, os_component.mach_services, and the bundle block. Tell me what intake could and could not see from a bare LaunchDaemon Mach-O.
   > ```

   **Heads-up — bare-binary intake has limits.** Expect the agent to report: `bundle: {}`, `os_component.mach_services: []`, no entitlements, `family_labels: ["apple-os-components"]`. Intake's heuristics fire on `Info.plist` metadata that a bare LaunchDaemon Mach-O does not have. **That is the lesson** — intake gives you the surface map; you reach for `plutil` / `codesign` to fill gaps. Ask the agent to fill them:

   > **Agent prompt:**
   > ```
   > Use the cli-static skill to read MachServices from templates/tutorial-target/plists/com.tutorial.daemon.privileged.plist and entitlements from templates/tutorial-target/bin/tutorial_daemon. Note them in CORPUS.md under the tutorial-daemon target row.
   > ```

   The agent will report two MachServices (`com.tutorial.daemon.privileged`, `com.tutorial.daemon.internal`) and one suspicious entitlement (`com.apple.private.tcc.allow → kTCCServiceSystemPolicyAllFiles`). Those facts drive Session D and the red-herring closure in Session E.

4. Sync the binary to the lab host:

   > **Agent prompt:**
   > ```
   > Sync the tutorial-daemon target to the lab host using rsync-to-vm.sh. Record the path mapping in CORPUS.md.
   > ```

   The agent reads `MACRE_MACHINE` and `MACRE_REMOTE_TARGETS` from your env (set in Session 0) and runs the script. It will confirm the `Lab Host Path Mapping` row landed in `CORPUS.md`.

5. Ask the watch layer what to do next:

   > **Agent prompt:**
   > ```
   > What recipes and Ghidra scripts did intake recommend for PASS-CLASS-001 against tutorial-daemon? If the recommended list is short or empty, tell me why and what we should run instead given what we know about the launchd plist and the entitlement we just read.
   > ```

   For this bare-binary intake `recommended_ghidra_scripts` is **empty** and `recommended_recipes` is `bundle-dossier, inventory-first-manual-routing`. The empty recommendation is itself information — and a good agent will hand-pick `scan_wrong_door.py` and `scan_xpc_client_validation.py` based on the two MachServices fact you just read in step 4.

**Plan-B (when the agent stalls):** raw shell commands for every step above are in [`STUDENT_QUICK_REFERENCE.md`](STUDENT_QUICK_REFERENCE.md) under *Plan-B: raw commands*. Use them only if the agent is confused — the goal of this lesson is to learn the agent-driven workflow, not the CLI.

**Troubleshooting:**

- **Agent doesn't know what bundle-intake / cli-static is.** The skills aren't linked into your agent's skills directory. Run `bash scripts/skill-link-claude-code.sh` (Claude Code) or `bash cursor/skill-link.sh` (Cursor) from the **station home**, then restart the agent.
- **Agent ran intake but the dossier is missing.** Check that the agent CD'd into your project clone, not the station. Tell it explicitly: "your working directory is `~/re/tutorial-daemon-class`."
- **`rsync-to-vm.sh` complains `./targets/ does not exist`** — intake should have populated it. Re-run the intake step in Session C.

**What success looks like:** `findings/analysis/PASS-CLASS-001-tutorial-daemon-dossier.json` exists; `CORPUS.md` lists two MachServices and the TCC entitlement; `targets/tutorial-daemon` synced; agent recommended wrong-door + client-validation scans.

**Discuss:** Why does intake label a LaunchDaemon helper as `apple-os-components`? When would that label be *correct* vs misleading?

**Reading:** Station `docs/tutorial/first-pass-planted.md` (overview only — no spoilers if you have not triaged yet).

---

## Session D — Static sweep via `ghidra-mcp`

**Worksheet:** §§ 3–5 (listener/delegate, authorization, primitives table).

### What are we looking for? (concept)

Chapter 8 Session D asked: *who can reach the surface, and which trust check failed?* The planted daemon fails in two places:

1. **Wrong door (C-001):** one `shouldAcceptNewConnection:` serves two Mach names with the same exported interface — connecting to `.privileged` still gets `InternalOps`.
2. **Missing gate on InternalOps (C-003):** `writeAuditLog:` and `resetCacheAtPath:` do not validate the caller — combined with (1), any peer that opens either Mach name gets **root-context file primitives**.

Static work ends when you have **tier-A anchors** (decompiled callsite + literal) for those claims — not when you have 200 string hits.

**Checklist (map to Chapter 8 Session D):**

| Check | Planted daemon signal |
|-------|------------------------|
| Listener branches on identity? | **No** — `scan_wrong_door.py` + `dump_xpc_listeners.py` |
| `SecTask*` / entitlement on sensitive path? | **Yes** on `PrivilegedHandler`; **no** on `InternalHandler` |
| Sensitive RPC reachable without that gate? | **Yes** — `resetCacheAtPath:` is `removeItemAtPath:` |
| Scary entitlement in blob? | **Red herring** until signature is Apple-platform (Session E) |

**Goals:** Open the binary in Ghidra (over MCP, not by SSH'ing in), run three scan scripts, and read the **three-tier evidence model**.

**Vocabulary:**

- **Anchor** — a function address with attached evidence. Tier A anchors carry a decompiled callsite + literal argument; tier B carry metadata only; tier C carry a string match.
- **Wrong door** — an XPC daemon that registers multiple listeners but does not branch on listener identity in `shouldAcceptNewConnection:`. The classic shape.

**Lab:** Drive the agent — you do not shell into the lab host. The agent calls `ghidra-mcp` tools (`program_open`, `function_list`, `decomp_function`, `ghidra_script`) on your behalf.

**Do (agent prompts):**

1. > **Agent prompt:**
   > ```
   > Open the tutorial-daemon target in Ghidra via program_open against the lab host path recorded in CORPUS.md. Report the session id, image base, max addr, and language id when analysis finishes.
   > ```

   The agent reports `AARCH64:LE:64:AppleSilicon`. First-time analysis on a 75 KB binary takes seconds; the persistent project on the lab host means the second run is free.

2. > **Agent prompt:**
   > ```
   > Run scan_wrong_door.py against the open tutorial-daemon session. Save the TSV under findings/analysis/. Summarize the tier-A rows for me — I want the function name, the address, and the listener identity arguments.
   > ```

   Expect one tier-A row pointing at `-[DaemonDelegate listener:shouldAcceptNewConnection:]` with two listeners declared and one delegate method.

3. > **Agent prompt:**
   > ```
   > Run dump_xpc_listeners.py. List every verified listener and the single delegate method that serves them. Tell me whether any listener identity check exists in the delegate.
   > ```

   Two MachServices, **one** `shouldAcceptNewConnection:` implementation, no branching. That's the wrong-door signature.

4. > **Agent prompt:**
   > ```
   > Run scan_xpc_client_validation.py. Find every callsite of SecTaskCreateWithAuditToken and SecTaskCopyValueForEntitlement. Decompile authorizeMethodID:connection: and tell me what gates each call to it.
   > ```

   One call to `SecTaskCreateWithAuditToken` in `authorizeMethodID:connection:`, gated by an early `if (methodID == 0) return YES;` — that's the methodID-0 bypass shape.

5. Now ask for the InternalHandler decomp explicitly — this is where the actually-exploitable primitives live:

   > **Agent prompt:**
   > ```
   > Decompile -[InternalHandler writeAuditLog:withReply:] and -[InternalHandler resetCacheAtPath:withReply:]. Tell me whether either has any caller validation, and what file-system operations they perform with the arguments. Use the gatehouse-ghidra-lldb skill to record the addresses for later breakpoint use.
   > ```

   Expect: neither has caller validation. `writeAuditLog:` appends attacker content to a hardcoded path. `resetCacheAtPath:` is `removeItemAtPath:` on an attacker-supplied path — **that's arbitrary file delete as root once you reach it through the wrong door.** Note both addresses; you'll use `resetCacheAtPath:` for exploitation in Session H+.

**Rules of thumb (tier reading):**

- **Triage tier A first.** Tier A anchors point at a decompiled callsite with the right argument shape — ready for an lldb breakpoint without further analysis.
- **Tier B is inventory.** Useful for "what *might* be reachable", sometimes wrong about reachability.
- **Tier C is grep.** Only triage if A and B miss the bug. On a real Electron app: tier A produced 14 anchors, tier C produced 240 hits at 100% noise.

**Troubleshooting:**

- **Agent reports `program_open` failure** — the binary may not have synced. Check `CORPUS.md`'s `Lab Host Path Mapping` table; rerun `rsync-to-vm.sh --record <target-slug>` if the row is missing.
- **Ghidra session is locked** — a stale headless sidecar is owning the project. Run `bash scripts/lab-health.sh --remove-stale` from the station home.

**What success looks like:** Three TSVs under `findings/analysis/`; you can explain in one sentence each for C-001, C-002, C-003; you have decomp addresses for `InternalHandler` methods.

**Discuss:** Why is C-002 worth escalating even though today's chain uses C-001 + C-003? When would methodID-0 bypass become the *primary* primitive?

---

## Session E — Triage and the red herring

**Worksheet:** §§ 5–7 (primitives table, red herring, C-004 state).

### What is triage for? (concept)

Scans emit **signals**; triage turns signals into **candidates** with state, severity, and a mandatory link to a **primary artifact**. The state machine exists so you cannot leave a scary string in a spreadsheet forever — you either **escalate** (worth dynamic work), **confirm** (reproduced), or **close with rationale** (explained away).

**Goals:** Drive the candidate state machine. Promote three real bugs, close the red herring with rationale.

**The triage state machine:**

States: `hypothesis`, `scan-hit`, `hold`, `blocked`, `escalated`, `reproducing`, `confirmed`, `report-ready`, `reported`, `closed`. `scan-hit → escalated` is legal directly (you do not have to go through `hold`); `escalated → reproducing → confirmed` is the dynamic-confirmation path; any state can transition to `closed` with a reason. `scripts/triage.py` enforces transitions. Illegal moves are rejected. `closed` requires `--reason`. There is **no `interesting` state** — closures with rationale count toward `METRICS.md`. Diagram in [`diagrams.md`](diagrams.md) figure 5.

**Two states people get backwards:** `escalated` means *real on the static read* (the candidate is worth chasing — typically because tier-A evidence is in hand). `confirmed` means *reproduced dynamically* (you ran it, you saw it, the transcript is in `artifacts/` and hash-pinned in `SCRIPTORIUM.md`). C-001 ends today as `confirmed`; C-002 and C-003 end at `escalated`.

**Severity values you will type wrong the first time:** `info`, `low`, `medium`, `high`, `critical`. The natural-English `informational` is rejected — it's the literal string `info` only.

**Lab:** Drive the agent — it knows the `triage.py` flag traps so you don't have to.

**Candidate C-001 — Shared delegate, no listener-identity branching.** One `shouldAcceptNewConnection:` serves both listeners with the same exported interface. A client connecting to `.privileged` gets `InternalOps` anyway. The service-name split is cosmetic.

> **Agent prompt:**
> ```
> Create candidate C-001 against PASS-CLASS-001 / target tutorial-daemon: title "Shared delegate, no listener-identity branching", vuln-class wrong-door, severity high, primary artifact the wrong-door TSV from Session D. Then transition it to escalated.
> ```

**Candidate C-002 — methodID 0 bypass.** `authorizeMethodID:connection:` returns `YES` unconditionally when `methodID == 0`, **before** the audit-token check. Authorization bypass on its face — though both `installConfigAtPath:` and `restartServiceWithID:` invoke `authorizeMethodID:` with hardcoded non-zero values, so this primitive is reachable only if a future routing path passes attacker-controlled `methodID` through. Worth escalating to track; not the chain we'll exploit today.

> **Agent prompt:**
> ```
> Create candidate C-002: title "authorizeMethodID:connection: returns YES for methodID 0", vuln-class authorization-bypass, severity high, primary artifact the xpc-client-validation TSV. Transition to escalated.
> ```

**Candidate C-003 — Ungated `InternalOps` (writeAuditLog + resetCacheAtPath).** This is the chain candidate. `InternalHandler` exposes two un-gated methods:
- `writeAuditLog:` — append attacker-controlled string to hardcoded `/var/log/tutorial-daemon-audit.log`.
- `resetCacheAtPath:` — **`removeItemAtPath:` on an attacker-supplied path**. Arbitrary file delete as root, once we reach this handler through C-001's wrong-door.

> **Agent prompt:**
> ```
> Create candidate C-003: title "InternalHandler ungated — writeAuditLog appends to root-owned path; resetCacheAtPath deletes arbitrary path as root", vuln-class un-gated-write, severity critical, primary artifact the xpc-client-validation TSV. Transition to escalated. The chain to exploitation is C-001 + C-003 — flag it that way in the candidate body.
> ```

**The red herring — `com.apple.private.tcc.allow`.** The codesign blob shows `com.apple.private.tcc.allow → kTCCServiceSystemPolicyAllFiles`. Looks like Full Disk Access. It is **not** — `com.apple.private.tcc.allow` is honored by `tccd` only for binaries signed by Apple's platform identity, and our daemon is ad-hoc signed.

> **Agent prompt:**
> ```
> Verify the daemon's signature is ad-hoc using cli-static. Then create candidate C-004: title "com.apple.private.tcc.allow entitlement (red herring — ignored on ad-hoc signed binaries)", vuln-class authorization-bypass, severity info, primary artifact the dossier. Close C-004 with rationale: "Apple-private TCC entitlements are honored only for Apple-platform-signed binaries; this binary is ad-hoc, so tccd silently ignores the claim. Verified via codesign -dvv showing Signature=adhoc."
> ```

**Rules of thumb (closure discipline):**

- Closing with rationale is the **same skill** as escalating. If you cannot write the rationale, you do not understand the candidate yet.
- A closed candidate is not a failure — it is research output.

**Troubleshooting:**

- **`triage.py create` rejects your `--severity` value** — valid choices are `info, low, medium, high, critical`. Not `informational`.
- **`triage.py create` complains about missing `--primary-artifact`** — it is required. Point at the TSV the scan emitted.

**What success looks like:** Four files under `findings/candidates/`; C-004 `closed` with a sentence you would send to a teammate; C-003 notes the C-001 + `resetCacheAtPath:` chain path.

**Discuss:** Why is closing C-004 as important as escalating C-003? What would go wrong if you reported the TCC entitlement without checking the signature?

**Written exercise (Chapter 8 Session E parallel):** Write a one-sentence **`SecRequirement`-style** rule that would allow only a binary signed with **your team's** Developer ID and bundle ID `com.example.courseclient` to call `installConfigAtPath:`. Then write one sentence: why does the planted daemon's **`methodID == 0`** early return violate the *spirit* of that check even when no caller reaches it today?

**Reading:** Apple documentation for `SecCodeCheckValidity`, `SecRequirementCreateWithString` (Chapter 8 Session E); station `scripts/triage.py --help` for transition rules.

---

## Session F — lldb confirmation

**Worksheet:** §§ 6–7 (lldb observations, state table).

### Why confirm dynamically?

**Goals:** Attach lldb (read-only) to a running daemon, set a breakpoint at the wrong-door anchor, fire it with a test client, capture the transcript.

Static reads can be wrong about **reachability**. Feature flags, environment variables, runtime branches you didn't see — any of those can flip a static finding from real to inert. For the planted daemon the dynamic question is simple: does the shared delegate **actually** accept connections on either MachService with the InternalOps interface?

**Vocabulary:**

- **`lldb_run_anchors`** — a `macre-vm-mcp` tool that takes a binary path and a list of breakpoint anchors, attaches, breaks, captures the transcript, detaches. **Read-only attach** — does not modify process state.

**Lab:** Running `tutorial_daemon` on the lab host + `pocs/client/` trigger. Install/teardown: [STUDENT_QUICK_REFERENCE.md](STUDENT_QUICK_REFERENCE.md).

**Do:**

1. Install the daemon on the lab host (instructor pre-class step or driven by the agent now). The agent can do it for you:

   > **Agent prompt:**
   > ```
   > Install the planted daemon onto the lab host as root. Steps: scp templates/tutorial-target/bin/tutorial_daemon and templates/tutorial-target/plists/com.tutorial.daemon.privileged.plist to the host, sudo install to /Library/PrivilegedHelperTools/ and /Library/LaunchDaemons/ with the right ownership, sudo launchctl bootstrap. After install, verify with launchctl print system/com.tutorial.daemon.privileged that state is running. Append the rollback steps to VM_ACTIONS.md.
   > ```

   If `sudo` over SSH prompts for a password, the lab host is missing the disposable-sudoers fragment — re-run `setup-keep.sh ... --vm-password '<lab-pw>' --lab-disposable` from the **station home** and retry.

2. Build the test client that triggers the breakpoint:

   > **Agent prompt:**
   > ```
   > Use the poc-authoring skill to scaffold a minimal Objective-C client at pocs/client/client.m. The client should NSXPCConnection initWithMachServiceName:@"com.tutorial.daemon.privileged" with NSXPCConnectionPrivileged, set remoteObjectInterface to @protocol(InternalOps) (declare it inline with writeAuditLog:withReply:), and call writeAuditLog:@"PASS-CLASS-001 reachability probe" withReply:^(BOOL ok){ NSLog(@"reply: ok=%d", ok); exit(0); }. Compile arm64, codesign --force --sign -, scp to the lab host as /tmp/client. Stop after the build — do not run yet.
   > ```

3. Set the breakpoint and arm capture:

   > **Agent prompt:**
   > ```
   > Use lldb_run_anchors against the running tutorial_daemon on the lab host. Set a breakpoint on -[DaemonDelegate listener:shouldAcceptNewConnection:]. Capture register state and the listener name argument when the breakpoint hits. Save the transcript to artifacts/PASS-CLASS-001-tutorial-daemon-shouldAccept.log. Tell me when lldb is attached and waiting.
   > ```

4. Trigger:

   > **Agent prompt:**
   > ```
   > Run /tmp/client on the lab host with sudo (the privileged port requires root for connection establishment in launchd's accept policy). Show me the client's stdout and the lldb transcript snippet for the breakpoint hit.
   > ```

   Watch the transcript: it should show register state and the listener's `name` argument the delegate was invoked with — that is the **C-001 confirmation** (the delegate accepts the privileged Mach name with the InternalOps interface). The client's reply should be `reply: ok=1` — `writeAuditLog:` succeeded despite the client connecting to the **privileged** port name. That second observation **transitively confirms C-003** (the un-gated handler actually executes when reached via the wrong door). One breakpoint, one client run, two confirmations.

5. Hash and pin:

   > **Agent prompt:**
   > ```
   > Hash the transcript with shasum -a 256. Add two anchors to SCRIPTORIUM.md: A-001 (C-001 wrong-door confirmed — listener delegate accepts privileged Mach name with InternalOps interface) and A-002 (C-003 ungated-write reached via the wrong door — writeAuditLog returned ok=1 from a non-admin caller). Both anchors point at the same transcript path, with the same hash, but different rationale.
   > ```

**Rules of thumb (evidence discipline):**

- The hash pin is the discipline. Six months from now when someone re-reads this finding, they re-hash the artifact and verify the conclusion was drawn from the file in front of them. **No hash, no reproducibility.**
- One transcript can pin multiple anchors when one observation confirms multiple candidates. Be honest in the SCRIPTORIUM rationale about which observation supports which claim.
- C-002 stays `escalated` — we did not confirm the methodID-0 bypass dynamically in this pass. Confirming it is its own breakpoint and its own client message; an exercise for after class.

**Troubleshooting:**

- **Breakpoint never fires** — daemon may have crashed at startup. Check `ssh <lab-host> 'log show --predicate "process == \"tutorial_daemon\"" --last 5m | tail -20'`. If the daemon is dead, the lldb attach fails before the breakpoint can fire.
- **Client compiles but `connection invalid` at run time** — the launchd plist did not load. Re-run `sudo launchctl bootout system /Library/LaunchDaemons/com.tutorial.daemon.privileged.plist` then `sudo launchctl bootstrap system /Library/LaunchDaemons/com.tutorial.daemon.privileged.plist`.

**What success looks like:** Breakpoint hits on `shouldAcceptNewConnection:`; client prints `reply: ok=1`; `artifacts/PASS-CLASS-001-tutorial-daemon-shouldAccept.log` exists; SCRIPTORIUM has A-001 and A-002 with matching SHA-256.

**Discuss:** One transcript pinned two anchors — when is that honest vs sloppy? What would you need to split them into separate runs on a real target?

**Reading:** Gatehouse skill in station `Skills/offensive-macos-gatehouse-ghidra-lldb/`; Chapter 8 NSXPC session for `NSXPCConnectionPrivileged` vs `options:0`.

---

## Session G — Closure, METRICS, HANDOFF

**Worksheet:** § 7 (state table) — should match `INDEX.md` after `triage.py render`.

### Why HANDOFF exists (concept)

Passes stop mid-flight — class ends, VM snapshots, another target interrupts. **`HANDOFF.md`** is the contract with your future agent session: what was confirmed, what is still escalated, which artifacts to trust, what to run first tomorrow. **`METRICS.md`** counts **closures with rationale** so "we closed four red herrings" is as visible as "we confirmed one bug."

**Goals:** Render the candidate roll-up, count closures, write the resume document for the next session.

**Do (agent prompts):**

1. > **Agent prompt:**
   > ```
   > Transition C-001 and C-003 through the triage state machine in order: escalated → reproducing → confirmed for each (no direct jump). Then run triage render so INDEX.md is current. Tell me the final state and severity for C-001, C-002, C-003, and C-004.
   > ```

   Expect: C-001 and C-003 `confirmed` (C-003 severity `critical`). C-002 `escalated`. C-004 `closed` with rationale.

2. > **Agent prompt:**
   > ```
   > Read METRICS.md and summarize this pass: how many confirmed, escalated, and closed-with-rationale.
   > ```

3. > **Agent prompt:**
   > ```
   > Draft HANDOFF.md for PASS-CLASS-001: Last Known Good State, Active Findings table (C-001 confirmed wrong-door, C-003 confirmed ungated InternalOps with chain path via resetCacheAtPath:, C-002 still escalated), and Next Session Start pointing at Session H unprivileged PoC then H+ chain delete. Show me the draft before writing the file.
   > ```

   **The agent reads `HANDOFF.md` first** at the start of every new session — treat it as your future self's permission slip.

**Rules of thumb (handoff hygiene):**

- If you stop work today and resume in two weeks, `HANDOFF.md` is what the agent reconstructs context from. Do not skip it.
- METRICS counts closures **with rationale**. A candidate stuck at `scan-hit` is not a closure.

**Plan-B:** raw `triage.py transition` one-liners are in [`STUDENT_QUICK_REFERENCE.md`](STUDENT_QUICK_REFERENCE.md) under *Plan-B: triage and closure*.

**What success looks like:** `INDEX.md` shows C-001 and C-003 `confirmed`; C-002 `escalated`; C-004 `closed`; `HANDOFF.md` mentions Sessions H / H+ as next steps.

---

## Session H — Unprivileged PoC (reachability)

**Worksheet:** § 8 (reachability).

### PoC vs confirmation (concept)

**Session F** confirmed the bug class **under lldb** with a client that may have used `sudo` to open the privileged Mach name. **Session H** asks a stricter question: does **UID 501** reach the handler in normal conditions? That is the difference between "the code path exists" and "a local attacker can drive it."

Chapter 8 case studies separate **who can open the Mach surface** from **what the helper does afterward**. Here, use `com.tutorial.daemon.internal` and `options:0` unless your instructor directs otherwise.

**Goals:** Prove C-001 + C-003 are reachable from **UID 501 without `sudo`** — not only under lldb with a root-spawned Session F client.

Session F used `sudo /tmp/client` against `com.tutorial.daemon.privileged` to force the breakpoint. For exploitation, use the **internal** Mach name with **no** `NSXPCConnectionPrivileged` flag. The delegate still exports `InternalOps` on both listeners (wrong door); the internal name is what unprivileged callers can open reliably.

**Vocabulary:**

- **Reachability PoC** — proves an unprivileged caller can invoke the vulnerable handler. Not yet root-impact.
- **Launchd accept policy vs daemon gate** — launchd may block unprivileged connect to the **privileged** port even when `shouldAcceptNewConnection:` accepts everyone. If so, that is launchd policy, not a fix for the daemon bug.

**Do (agent prompts):**

1. > **Agent prompt:**
   > ```
   > Use the poc-authoring skill. Build pocs/unprivileged-write/client.m: NSXPCConnection initWithMachServiceName:@"com.tutorial.daemon.internal" options:0 (NOT NSXPCConnectionPrivileged), InternalOps with writeAuditLog:withReply:, message "PASS-CLASS-001 unprivileged reachability". Compile arm64, ad-hoc sign, scp to /tmp/unprivileged-write. Do not run yet.
   > ```

2. > **Agent prompt:**
   > ```
   > On the lab host run /tmp/unprivileged-write as the normal lab user (no sudo). Show stdout/stderr. Then tail -1 /var/log/tutorial-daemon-audit.log. I need reply ok=1 and my string in the log from UID 501.
   > ```

3. > **Agent prompt:**
   > ```
   > Save client output to artifacts/PASS-CLASS-001-unprivileged-write.log. Hash it and add SCRIPTORIUM anchor A-003: C-003 reachable without sudo via com.tutorial.daemon.internal — writeAuditLog ok=1 from unprivileged caller.
   > ```

4. **Optional sanity check:** ask the agent to run the same client against `com.tutorial.daemon.privileged` without sudo. If connect fails, record one sentence in `CORPUS.md` — wrong-door still real, privileged port may be root-only at launchd.

**Rules of thumb:**

- **PoC code lives in `pocs/`.** Gitignored in the station template; project clone only.
- Session H proves **reach**. Session H+ proves **impact** (`resetCacheAtPath:`).

**What success looks like:** `/tmp/unprivileged-write` exits 0; log file contains your probe string; SCRIPTORIUM anchor A-003 hash-pinned.

**Discuss:** If the privileged port works only with `sudo` but the internal port works without, is the daemon still "vulnerable"? Who is the attacker model?

---

## Session H+ — Chain: arbitrary root file delete

**Worksheet:** § 9 (impact) · § 10–11 in Session I.

### From primitive to impact (concept)

**Reachability** (append to a log) shows the handler runs. **Impact** shows the daemon's **root identity** changes attacker-visible state on disk. `resetCacheAtPath:` is deliberately blunt: `removeItemAtPath:` on whatever path you pass — classic **arbitrary file delete as root** once C-001 exposes `InternalOps`.

We use `/tmp/tutorial-chain-sentinel` so the demo is harmless and survives typical lab VMs. On a real helper, the same primitive might target a plist, a sudoers fragment, or a tool under `/Library/PrivilegedHelperTools/` — subject to SIP and path policies.

**Goals:** Chain **C-001 (wrong door)** + **C-003 (`resetCacheAtPath:`)** into a reproducible **root primitive on disk**: delete a file you could not delete as the lab user.

**The chain (no magic):**

1. Connect to `com.tutorial.daemon.internal` with `options:0` (same wrong-door delegate as Session F — **internal** name for unprivileged reachability).
2. Call `resetCacheAtPath:` with a path you supply — the daemon runs `removeItemAtPath:` as root.
3. Prove impact: a root-owned sentinel file exists, you cannot remove it, then the XPC call removes it.

**Do (agent prompts):**

1. > **Agent prompt:**
   > ```
   > On the lab host, create /tmp/tutorial-chain-sentinel owned root:wheel mode 644 with content "owned-by-root". As the lab SSH user without sudo, verify rm /tmp/tutorial-chain-sentinel fails with Permission denied. Record commands and outputs in VM_ACTIONS.md.
   > ```

2. > **Agent prompt:**
   > ```
   > Use the poc-authoring skill. Build pocs/chain-delete/client.m: connect to com.tutorial.daemon.internal options 0, InternalOps with resetCacheAtPath:withReply:, call resetCacheAtPath:@"/tmp/tutorial-chain-sentinel". Compile, sign, scp to /tmp/chain-delete. Do not run yet.
   > ```

3. > **Agent prompt:**
   > ```
   > Run /tmp/chain-delete on the lab host without sudo. Verify test ! -f /tmp/tutorial-chain-sentinel. Save output to artifacts/PASS-CLASS-001-chain-delete.log.
   > ```

4. > **Agent prompt:**
   > ```
   > Hash the chain-delete log. Add SCRIPTORIUM anchor A-004: C-001+C-003 chain — unprivileged caller deleted root-owned sentinel via resetCacheAtPath through internal MachService. Update HANDOFF.md Active Findings.
   > ```

**Rules of thumb (PoC vs exploit):**

- **Today's bar:** chained primitive with observable root impact on disk. We are **not** claiming reliable code execution, persistence, or bypass of SIP on production paths — only that the daemon's logic lets a caller reach root file delete through the wrong door.
- **`writeAuditLog:`** appends to a fixed path — useful for reachability, weaker for impact. **`resetCacheAtPath:`** is the chain primitive for this class.
- **`installConfigAtPath:`** remains gated (`authorizeMethodID:1`); **C-002** (methodID-0 bypass) is tracked but not the path we weaponize today.

**Tear-down:**

> **Agent prompt:**
> ```
> Tear down the planted daemon on the lab host: launchctl bootout, remove plist and binary under /Library, remove /tmp/client /tmp/unprivileged-write /tmp/chain-delete, append rollback completion to VM_ACTIONS.md.
> ```

Plan-B install/teardown shell blocks: [`STUDENT_QUICK_REFERENCE.md`](STUDENT_QUICK_REFERENCE.md).

**What success looks like:** Sentinel existed and was not deletable by the lab user; after `/tmp/chain-delete` it is gone; A-004 in SCRIPTORIUM; tear-down recorded in `VM_ACTIONS.md`.

**Discuss:** Why is arbitrary file delete "enough" for class without proving code execution? What downstream consumer would you need for log injection to become execution?

**What's in the next lab:** multi-binary bundle pass against `PluginHost.app` — same loop, different target shape. Walkthrough: [`LAB_II.md`](LAB_II.md). Optional homework; not part of today's spine.

---

## Session I — Wrap and what to try next

**Worksheet:** §§ 10–11 (fix bullets, Chapter 8 comparison table) — due before you leave class or as homework.

**Goals:** Recap the loop. Pick a real target.

**Written exercise:** Complete the worksheet **§ 10 fix bullets** and **§ 11 comparison table**. Be prepared to explain one case-study step aloud (reachability, trust failure, primitive, impact, or fix) in under 30 seconds.

**What you did today:**

1. Stood up workstation + lab host (Session 0).
2. Drove intake, dossier gaps, and sync through the agent (Session C).
3. Ran Ghidra scans and decomps via the agent; identified wrong-door, methodID-0 shape, and ungated `InternalHandler` primitives (Session D).
4. Triaged four candidates via the agent: three escalated, one closed-with-rationale (Session E).
5. Confirmed C-001 and C-003 with lldb; hash-pinned anchors A-001 and A-002 (Session F).
6. Closed the pass roll-up: confirmed states, METRICS, HANDOFF (Session G).
7. Ran unprivileged reachability PoC; hash-pinned A-003 (Session H).
8. Chained to root file delete on a sentinel path; hash-pinned A-004 (Session H+).

Total time: ~3–3.5 hours. Total persistent artifacts: ~15 files in your project clone, hash-pinned where it matters. **That is a full pass through discovery and exploitation** on a planted target. Repeat the loop on real binaries and the agent-driven steps become muscle memory.

**Three directions from here:**

1. **Repeat the loop on a real target.** The station's `TARGET_QUEUE.md` ranks candidates. **Privileged helpers and updaters** pay best first (same shape as the planted daemon).
2. **Harder chains on the same target.** You confirmed C-001 + C-003 and demonstrated delete. **`offensive-macos-chain-discovery`** is the skill for combining unrelated primitives across surfaces — use it when you have more than one confirmed bug class and need a story, not a single method call.
3. **Read closures with rationale.** `findings/candidates/*.json` in completed passes — especially C-004 — is how you learn what *isn't* a bug.

**Prepare for the next class:** bring `HANDOFF.md` from this pass. Chapter 9 continues chain thinking on real targets; we cold-start from your handoff to practice session continuity.

**Compare to Chapter 8 (instructor whiteboard):**

| Stage | Chapter 8 (XPC) | This unit (station) |
|-------|-----------------|---------------------|
| Surface map | Manual `codesign` / plist | Intake dossier + agent-filled gaps |
| Trust failure | Session D checklist | Wrong-door scan + triage C-001 |
| Dynamic proof | Case-specific PoCs | lldb + hash-pinned transcript |
| Local attacker | Case-specific | Session H unprivileged client |
| Impact | CVE-specific (Shove, Zoom, …) | Session H+ root delete sentinel |

---

## Quick reference: useful commands

```bash
# Smoke the install (no lab-host needed)
bash scripts/smoke-wave3.sh

# Live smoke against /bin/ls on the lab host
MACRE_MACHINE=<lab-host> bash scripts/smoke-wave3.sh --live

# What does watch see in the dossier? (workstation only)
cat findings/analysis/PASS-CLASS-001-tutorial-daemon-dossier.json | python3 -m json.tool | head -60

# Daemon up?
ssh <lab-host> 'launchctl print system/com.tutorial.daemon.privileged | head -20'

# Find a stale Ghidra session
bash scripts/lab-health.sh
```

---

## Figures

See [diagrams.md](diagrams.md).
