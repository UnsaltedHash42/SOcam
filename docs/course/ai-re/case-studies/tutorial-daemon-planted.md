# Case study: planted `tutorial_daemon` — privileged XPC helper

**Prerequisite:** Chapter 8 Sessions A–D (Mach services, NSXPC, attack checklist). **Station** installed per [STUDENT_GUIDE.md](../STUDENT_GUIDE.md) Session 0.

**Target:** `templates/tutorial-target/bin/tutorial_daemon` · plist `templates/tutorial-target/plists/com.tutorial.daemon.privileged.plist`

**Pass ID:** `PASS-CLASS-001` · **Target slug:** `tutorial-daemon`

## Learning goals

- Run a full **agent-driven pass**: intake → static scans → triage → lldb confirm → unprivileged PoC → chained impact.
- Map findings to the Chapter 8 arc: **reachability**, **trust failure**, **primitive**, **impact**, **fix**.
- Close a **red herring** entitlement with signature-aware rationale (same discipline as dismissing a scary string match).

## Lab setup

1. **Session 0 Steps 1–8 (human):** VM → SSH config → `setup-keep.sh` → verify → project clone → fill `LAB_SAFETY.md` / `machines.md`.
2. **Session 0.4 (human):** Project clone `~/re/tutorial-daemon-class/` — `init-project.sh`; **you** fill `LAB_SAFETY.md` and `machines.md` (not the agent).
3. **Session 0 Step 9 (agent):** Orientation prompt in [STUDENT_QUICK_REFERENCE.md](../STUDENT_QUICK_REFERENCE.md) — **READY FOR PASS** before intake.
4. **Session F:** daemon installed on lab host; torn down after Session H+ (quick reference tear-down).

## Session map

| Worksheet § | STUDENT_GUIDE session | Primary artifact |
|-------------|----------------------|------------------|
| 1–2 | C — Intake | Dossier + CORPUS MachServices row |
| 3–5 | D — Static | Wrong-door + client-validation TSVs |
| 6–7 | E — Triage | `findings/candidates/C-00*.json` |
| 8–9 | F — lldb | `artifacts/...-shouldAccept.log` + SCRIPTORIUM A-001/A-002 |
| 10 | G — Closure | `INDEX.md`, `HANDOFF.md` |
| 11–12 | H / H+ | PoC logs + SCRIPTORIUM A-003/A-004 |

---

## Static analysis worksheet

Fill as you go. If the agent already wrote the answer in CORPUS or a candidate file, **copy it in your own words** — the exercise is comprehension, not transcription.

### 1. Surface map (Session C)

**Mach names:** List both service names from the launchd plist:

```
Privileged: ________________________________
Internal:   ________________________________
```

**Intake gap:** What did the bare-binary dossier *fail* to show that `plutil` / `codesign` supplied?

```
________________________________________________________________
```

### 2. Listener / delegate (Session D)

**Wrong door:** How many `shouldAcceptNewConnection:` implementations serve the two Mach names? ______

**Exported interface on accept:** Which `@protocol` does the delegate set on `exportedInterface`? __________________

**One-sentence trust failure (Session D checklist):** Which checklist item failed?

```
________________________________________________________________
```

### 3. Authorization shape (Session D)

**SecTask path:** Where is `SecTaskCreateWithAuditToken` used (class/method)? ________________________________

**methodID 0:** What does `authorizeMethodID:connection:` do when `methodID == 0`? ________________________

**Gated vs ungated:** Which handler methods perform file operations **without** going through `authorizeMethodID:`?

```
________________________________________________________________
```

### 4. Primitives (Session D → E)

| Method | File operation | Attacker-controlled input? |
|--------|----------------|----------------------------|
| `writeAuditLog:` | | |
| `resetCacheAtPath:` | | |
| `installConfigAtPath:` | | |

**Chain candidate:** Which two candidates (IDs) compose today's exploitation chain? ______ + ______

### 5. Red herring (Session E)

**Entitlement string:** What private TCC entitlement appears in the codesign blob? __________________________

**Why inert:** In one sentence, why does it **not** grant Full Disk Access on this binary?

```
________________________________________________________________
```

**Closure state for C-004:** ________

---

## Dynamic analysis worksheet

### 6. lldb confirmation (Session F)

**Breakpoint:** Function where the breakpoint hit: ________________________________________________

**C-001 observation:** What Mach / listener identity did you connect with from the Session F client? ________

**C-003 observation:** Did `writeAuditLog:` return success (`ok=1`)? ______

**SCRIPTORIUM:** SHA-256 of transcript (first 16 hex chars enough): ________________________________

### 7. State machine (Session G)

| ID | Final state | Severity |
|----|-------------|----------|
| C-001 | | |
| C-002 | | |
| C-003 | | |
| C-004 | | |

---

## Exploitation worksheet

### 8. Reachability (Session H)

**Mach name used (unprivileged):** ________________________________  **Options flag:** ______________

**Evidence line** (log path or client stdout proving UID 501 reachability):

```
________________________________________________________________
```

### 9. Impact (Session H+)

**Sentinel path:** ________________________________________________

**Before chain:** Could the lab user `rm` the sentinel without sudo? ______

**After chain:** Sentinel present? ______

**Primitive in one line:** What root operation did the daemon perform on your behalf?

```
________________________________________________________________
```

---

## Wrap-up (Session I)

### 10. Fix (design, not exploit)

Write **three bullets** — if you shipped this daemon tomorrow, what would you change to block today's chain?

1. 
2. 
3. 

### 11. Compare to Chapter 8

| Case-study step | Your planted-daemon answer (one phrase each) |
|-----------------|-----------------------------------------------|
| Reachability | |
| Trust failure | |
| Primitive | |
| Impact | |
| Fix | |

---

## Further reading

- Station: `docs/tutorial/first-pass-planted.md` (after class — full walkthrough).
- Chapter 8: [STUDENT_GUIDE.md](../../ch08-xpc/STUDENT_GUIDE.md) Session D checklist; NSXPC Session C.
- Apple: `NSXPCListener`, `NSXPCConnection`, Security framework code signing requirements.
