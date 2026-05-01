# Swift NSXPC lab — vulnerable privileged helper

This lab demonstrates **local privilege escalation** through an **`NSXPCListener`** that accepts **any** client. Run only on a **VM** or machine you can wipe.

**At a glance:** install → compile exploit → run → uninstall commands are also on **[`docs/course/ch08-xpc/STUDENT_QUICK_REFERENCE.md`](../../docs/course/ch08-xpc/STUDENT_QUICK_REFERENCE.md)** so you can follow without copying this README into your notes.

## What lives in Git vs Google Drive

| Material | Where |
|----------|--------|
| **All source** for this XPC unit (Swift helper + client, C client/server, plists, scripts) | **This repository** — well commented on purpose |
| **Large apps** (Slack, old vulnerable installers, VM disks) | **Google Drive** (or similar) — see repo root `resources/README.md` |

## “Real world” CVE labs (WiFiSpoof, PackageKit, Zoom)

Those sessions use **worksheets** under `docs/course/ch08-xpc/case-studies/` plus **binaries your instructor puts on Drive**. We do **not** ship full third-party exploit PoC source in git (copyright, patch level, and repo size). The **only** runnable exploit code in-tree for XPC is **`Exploit/exploit.swift`** against **`com.example.vulnerablehelper`** — same *idea* (missing client auth on a privileged XPC surface), controlled scope.

## Components

| Path | Role |
|------|------|
| `VulnerableHelper/VulnerableHelper.swift` | Root helper — **intentionally insecure** |
| `VulnerableHelper/com.example.vulnerablehelper.plist` | LaunchDaemon template |
| `install_lab.sh` | Compile helper, install to `/Library/PrivilegedHelperTools`, load launchd |
| `uninstall_lab.sh` | Unload service, remove plist + binary, remove class marker file |
| `verify_lab.sh` | Optional: exit 0 if `launchd` knows about the helper (after install) |
| `Exploit/exploit.swift` | Unprivileged client that speaks the same `@objc` protocol |

Mach service name: **`com.example.vulnerablehelper`**

## Install (requires admin)

```bash
cd labs/xpc
sudo ./install_lab.sh
```

Verify:

```bash
launchctl print system/com.example.vulnerablehelper 2>/dev/null | head
```

## Run exploit (normal user)

```bash
cd labs/xpc
swiftc Exploit/exploit.swift -o exploit
./exploit
```

Expected: output from `id` and a **root-owned** marker file under `/Library/PrivilegedHelperTools/` (see `exploit.swift` payload).

## Cleanup (requires admin)

```bash
sudo ./uninstall_lab.sh
```

## What to notice

- `listener(_:shouldAcceptNewConnection:)` returns **`true`** without **`SecCode`** / requirement checks.
- The exploit **does not** need to be root; it only needs a Mach lookup to the service (policy may still block in hardened environments — use the course VM).

## Related reading

- Course student guide: `docs/course/ch08-xpc/STUDENT_GUIDE.md`
- Instructor voice lectures: `instructor/ch08-xpc/00_HOW_TO_TEACH_CH08.md` and `01_…`–`09_…` (see repo root `README.md`); optional Swift lines in `instructor/ch08-xpc/module_09_xpc.md`
