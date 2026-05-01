# Student guide: XPC and privileged helpers

This guide replaces reliance on the course PDF. Session numbers are suggestions; your instructor may merge or split them.

---

## Session A — Why XPC exists

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

**Lab:** [labs/ch08-c-xpc/README.md](../../../labs/ch08-c-xpc/README.md)

**Debug habit:** Print unknown objects with **`xpc_copy_description`** (remember to balance retain/release rules your instructor sets for the course).

**Troubleshooting:**

- **Connection invalid:** Wrong Mach name, plist not loaded, or server not listening.
- **Permission denied / launchd:** Plist in `/Library/LaunchDaemons` requires root and correct ownership.

---

## Session C — NSXPC (Foundation)

**Goals:** Map Objective-C / Swift **protocols** to remote calls; locate **`NSXPCListenerDelegate`** and **`listener:shouldAcceptNewConnection:`**.

**Rules of thumb (NSXPC):**

- Remote methods are **async**; return type is often `void` with a **reply block** for results.
- Argument types must be **XPC-safe** (primitives, `NSData`, a small set of Cocoa types per Apple’s rules).

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

**Capstone lab (controlled):** [labs/xpc/README_STUDENT.md](../../../labs/xpc/README_STUDENT.md)

---

## Session E — Verification APIs (study, not exploit)

**Goals:** Read Apple / Security framework documentation for **`SecCodeCopyGuestWithAttributes`**, **`SecRequirementCreateWithString`**, **`SecCodeCheckValidity`**, and (where allowed in your course) audit-token–based APIs.

**Written exercise:** Write a one-sentence **code requirement** that would allow only *your* team’s signed app `com.example.courseclient` to talk to a helper. Then write one way a **lazy** developer might bypass the spirit of that check.

---

## Sessions F–H — Real-world case studies

Work from **`case-studies/`** and the **instructor bundle** for exact versions. Typical arc per case:

1. **Reachability:** Who can open the Mach / XPC surface?
2. **Trust failure:** Which checklist item (Session D) failed?
3. **Primitive:** What could an attacker ask the helper to do?
4. **Impact:** User → root? sandbox escape? SIP-related effect? (Case-specific.)
5. **Fix:** What did the vendor or Apple change?

**Tracks (names only — details in each file):**

- `case-studies/cve-2021-44214-wifispoof.md`
- `case-studies/cve-2022-26712-packagekit.md`
- `case-studies/zoom-583-lpe.md`

---

## Session I — Wrap-up

**Compare** the three cases on one table: reachability, trust mistake, primitive, impact, lesson.

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
