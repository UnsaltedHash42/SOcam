# Swift NSXPC lab — vulnerable privileged helper

This lab demonstrates **local privilege escalation** through an **`NSXPCListener`** that accepts **any** client. Run only on a **VM** or machine you can wipe.

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
- Instructor script: `instructor_private/ch08-xpc/LESSON_SCRIPT.md` (not on GitHub — see `FOR_INSTRUCTORS.md`)
