# Student guide: XPC and privileged helpers

This guide replaces reliance on the course PDF. Session numbers are suggestions; your instructor may merge or split them.

**Minimal note-taking:** keep **[`STUDENT_QUICK_REFERENCE.md`](STUDENT_QUICK_REFERENCE.md)** open during labs — build commands, Mach names, and repo paths are collected there so you can **run first**, then read prose here for *why*.

**Large installers (Zoom, WiFiSpoof, VM snapshots):** not in git — your instructor’s **Google Drive** link is in [`README.md`](README.md) (search *Lab artifacts*). Download before the case-study sessions.

| Session (this guide) | Primary repo code / doc |
|----------------------|-------------------------|
| A — Why XPC | *Observation only* — use any app’s `Contents/XPCServices` + `codesign` |
| B — C API | [`labs/ch08-xpc/`](../../../labs/ch08-xpc/) (`01_xpcclient.c`, `01_xpcserver.c`, `01_com.example.student.xpc.plist.template`) |
| C — NSXPC | [`labs/ch08-xpc/`](../../../labs/ch08-xpc/) (`02_nsxpcserver.m`, `02_nsxpcclient.m`, `02_com.offsec.nsxpc.plist.template`) |
| D–E — Attack model & APIs | [`case-studies/README.md`](case-studies/README.md) + Apple docs (names in guide) |
| F–H — Case studies | [`case-studies/*.md`](case-studies/) + PoC sources in [`labs/ch08-xpc/`](../../../labs/ch08-xpc/) |
| I — Wrap | Comparison table (below) + [`labs/ch08-xpc/`](../../../labs/ch08-xpc/) capstone |

---

## Session A — Why XPC exists

### What is XPC? (concept)

**XPC** (Cross-Process Communication) is Apple’s **structured** IPC in user space: processes exchange **typed messages**, almost always **XPC dictionaries** of strings, numbers, data blobs, and nested objects. It is built on **Mach** (kernel ports and messages), but you rarely touch raw Mach in application code — you use **`libxpc`** in C or **`NSXPCConnection`** in Objective-C/Swift.

**Why it matters for security:** a **privileged helper** (root daemon, often under `/Library/PrivilegedHelperTools/`) exposes an IPC **surface**. If the helper accepts connections from the wrong peer, or trusts **message fields** without hardening, attackers can get **root-level primitives** without a traditional memory-corruption bug.

**Vocabulary:** **Mach service name** (registered with launchd), **listener** (server), **connection** (client channel), **`shouldAcceptNewConnection:`** (common trust gate in NSXPC). See [diagrams.md](diagrams.md) for stack and reachability figures.

**Goals:** Explain **isolation** (crash containment) and **privilege separation** (different entitlements per process). Recognize an **XPC service bundle** (`*.xpc` under `Contents/XPCServices/`).

**Do:**

1. On a lab Mac, pick any third-party app with an XPC helper (or use the instructor’s pick). List one embedded XPC path:
   - `ls "…/MyApp.app/Contents/XPCServices"`
2. Compare **entitlements** of the main app vs one embedded XPC (instructor demo or your own):
   - `codesign -dv --entitlements :- "…/MyApp.app"`
   - `codesign -dv --entitlements :- "…/MyApp.app/Contents/XPCServices/Something.xpc"`

**Discuss:** Why might the main app hold `com.apple.security.cs.debugger` while the helper does not? What is the security **win** if the helper is compromised?

**Reading:** Apple overview of XPC / app extensions (high level).

---

## Session B — C API: dictionaries and connections

**Goals:** Build and send an **XPC dictionary**; open a **Mach-named** connection; handle **listener → peer connection → message** on the server.

**Vocabulary:**

- Top-level messages are **dictionaries** (`xpc_object_t` with type `XPC_TYPE_DICTIONARY`).
- `xpc_connection_create_mach_service` on the **client** (third arg `0`) vs **listener** (`XPC_CONNECTION_MACH_SERVICE_LISTENER`) on the server.

**Lab:** [labs/ch08-xpc/README.md](../../../labs/ch08-xpc/README.md)

**Debug habit:** Print unknown objects with **`xpc_copy_description`** (remember to balance retain/release rules your instructor sets for the course).

**Troubleshooting:**

- **Connection invalid:** Wrong Mach name, plist not loaded, or server not listening.
- **Permission denied / launchd:** Plist in `/Library/LaunchDaemons` requires root and correct ownership.

---

## Session C — NSXPC (Foundation)

**Goals:** Map Objective-C / Swift **protocols** to remote calls; locate **`NSXPCListenerDelegate`** and **`listener:shouldAcceptNewConnection:`**.

**Lab (same ideas as class, in Objective-C):** [`labs/ch08-xpc/README.md`](../../../labs/ch08-xpc/README.md) — build `02_nsxpcserver` / `02_nsxpcclient`, install `com.offsec.nsxpc.plist`, round-trip one RPC. **Commands:** also in [`STUDENT_QUICK_REFERENCE.md`](STUDENT_QUICK_REFERENCE.md).

**Rules of thumb (NSXPC):**

- Remote methods are **async**; return type is often `void` with a **reply block** for results.
- Argument types must be **XPC-safe** (primitives, `NSData`, a small set of Cocoa types per Apple’s rules).
- **`NSXPCConnectionPrivileged`** is required for typical **launchd**-managed helpers (literal `0x1000` often shows up in Hopper).

**Exercise (conceptual):** Sketch on paper the three layers from Session B, but label them `NSXPCListener`, `NSXPCConnection`, and “remote object proxy.”

---

## Session D — Attack surface

**Goals:** Name two ways to reach a privileged action:

1. **Impersonate** the client (connect to a global Mach service).
2. **Inject** the real client if signing / hardened runtime / library validation are weak, then speak **as** that process.

**Checklist (what a secure server should consider — memorize categories, not every API):**

1. Caller signed with a **valid Apple-trust** chain (not ad hoc junk pretending to be Apple).
2. Caller meets **your org** requirement (e.g. **team ID** / certificate subject).
3. Optional: narrow by **bundle identifier**.
4. Optional: reject **old, injectable** clients (version vs **code signing flags** such as hardened runtime / library validation).
5. Apple-only services: caller may need **entitlements** you do not have — expect **deny**.
6. Prefer decisions tied to **audit identity**, not naive **PID** checks (PID reuse).

**Hands-on later:** the **Swift** capstone (install helper + run exploit + uninstall) is in **Session I** — same checklist, code you can modify safely.

---

## Session E — Verification APIs (study, not exploit)

**Goals:** Read Apple / Security framework documentation for **`SecCodeCopyGuestWithAttributes`**, **`SecRequirementCreateWithString`**, **`SecCodeCheckValidity`**, and (where allowed in your course) audit-token–based APIs.

**Written exercise:** Write a one-sentence **code requirement** that would allow only *your* team’s signed app `com.example.courseclient` to talk to a helper. Then write one way a **lazy** developer might bypass the spirit of that check.

---

## Sessions F–H — Real-world case studies

Work from **`case-studies/`** for structured questions; your instructor supplies **exact builds** (Drive / VM). **Runnable PoC source** that matches the course narrative lives in **`labs/ch08-xpc/`** (same filenames the instructor walks through — build lines in that README and in [`STUDENT_QUICK_REFERENCE.md`](STUDENT_QUICK_REFERENCE.md)).

Typical arc per case:

1. **Reachability:** Who can open the Mach / XPC surface?
2. **Trust failure:** Which checklist item (Session D) failed?
3. **Primitive:** What could an attacker ask the helper to do?
4. **Impact:** User → root? sandbox escape? SIP-related effect? (Case-specific.)
5. **Fix:** What did the vendor or Apple change?

**Tracks:**

- [case-studies/cve-2021-44214-wifispoof.md](case-studies/cve-2021-44214-wifispoof.md) — helper: `03_wifispoofexp.m`
- [case-studies/cve-2022-26712-packagekit.md](case-studies/cve-2022-26712-packagekit.md) — PoC: `04_shovexpc.m` (**Monterey &lt; 12.4**)
- [case-studies/zoom-583-lpe.md](case-studies/zoom-583-lpe.md) — `05_zoomxpc.m` + `05_zoom_exploit_lab.sh` (+ Drive artifacts)

---

## Session I — Wrap-up + Swift capstone

**Compare** the three case studies on one table: reachability, trust mistake, primitive, impact, lesson.

**Controlled first-party exploit (you own the helper):** [labs/ch08-xpc/README.md](../../../labs/ch08-xpc/README.md) — `06_install_lab.sh` → `swiftc 06_exploit.swift` → run → **`06_uninstall_lab.sh`**. Commands duplicated in [`STUDENT_QUICK_REFERENCE.md`](STUDENT_QUICK_REFERENCE.md).

**Prepare for next module:** How XPC weaknesses chain with **TCC**, **SIP**, and **injection** lessons later in the course (instructor will point to exact modules).

---

## Quick reference: useful commands

```bash
# Mach services advertised by a launchd plist (example)
plutil -p /Library/LaunchDaemons/com.example.plist | head

# Is my helper loaded?
launchctl print system/com.example.vulnerablehelper 2>/dev/null || true

# Strings pass on a helper (instructor demo)
strings -a /Library/PrivilegedHelperTools/SomeHelper | head
```

---

## Figures

See [diagrams.md](diagrams.md).
