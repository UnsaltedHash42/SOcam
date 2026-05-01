# Chapter 8 — XPC labs (single folder)

All runnable **Chapter 8** teaching code lives here. Files are prefixed **`01_`–`06_`** in the order the course uses them (C → NSXPC → case-study PoCs → Swift capstone).

| Prefix | Lecture / session | Files | Mach / notes |
|--------|-------------------|-------|----------------|
| **01_** | C / `libxpc` (Session B, Lec 02) | `01_xpcclient.c`, `01_xpcserver.c`, `01_com.example.student.xpc.plist.template` | `com.example.student.xpc` |
| **02_** | NSXPC minimal pair (Session C, Lec 03) | `02_nsxpcclient.m`, `02_nsxpcserver.m`, `02_com.offsec.nsxpc.plist.template` | `com.offsec.nsxpc` |
| **03_** | WiFiSpoof-style helper (Lec 06) | `03_wifispoofexp.m` | Third-party helper name in source — VM + licensed app only |
| **04_** | PackageKit / Shove (Lec 07) | `04_shovexpc.m` | **Monterey &lt; 12.4**; run **`sudo ./04_shovexpc`** |
| **05_** | Zoom installer race (Lec 08) | `05_zoomxpc.m`, `05_zoom_exploit_lab.sh` | **Sonoma-class VM** + Drive artifacts named in script header |
| **06_** | Swift privileged helper + exploit (Lec 09) | `06_VulnerableHelper.swift`, `06_exploit.swift`, `06_com.example.vulnerablehelper.plist`, `06_install_lab.sh`, `06_uninstall_lab.sh`, `06_verify_lab.sh` | `com.example.vulnerablehelper` |

Student prose and copy-paste blocks: [`docs/course/ch08-xpc/STUDENT_QUICK_REFERENCE.md`](../../docs/course/ch08-xpc/STUDENT_QUICK_REFERENCE.md) and [`docs/course/ch08-xpc/STUDENT_GUIDE.md`](../../docs/course/ch08-xpc/STUDENT_GUIDE.md).

---

## 01 — C / libxpc Mach service + client

```bash
cd labs/ch08-xpc
clang -fblocks -o 01_xpcclient 01_xpcclient.c
clang -fblocks -o 01_xpcserver 01_xpcserver.c
```

### Install (root) — binary stays in repo clone (class demo)

```bash
SRV_PATH="$PWD/01_xpcserver"
sed "s|__BINPATH__|$SRV_PATH|" 01_com.example.student.xpc.plist.template | sudo tee /Library/LaunchDaemons/com.example.student.xpc.plist >/dev/null
sudo chown root:wheel /Library/LaunchDaemons/com.example.student.xpc.plist
sudo chmod 644 /Library/LaunchDaemons/com.example.student.xpc.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/com.example.student.xpc.plist
./01_xpcclient
```

### Uninstall

```bash
sudo launchctl bootout system /Library/LaunchDaemons/com.example.student.xpc.plist 2>/dev/null || \
  sudo launchctl unload /Library/LaunchDaemons/com.example.student.xpc.plist 2>/dev/null
sudo rm -f /Library/LaunchDaemons/com.example.student.xpc.plist
sudo rm -f /usr/local/libexec/ch08-xpcserver
```

---

## 02 — NSXPC minimal daemon + client

```bash
cd labs/ch08-xpc
gcc -fobjc-arc -framework Foundation 02_nsxpcclient.m -o 02_nsxpcclient
gcc -fobjc-arc -framework Foundation 02_nsxpcserver.m -o 02_nsxpcserver
```

Install plist (same `__BINPATH__` pattern as `01_`):

```bash
SRV_PATH="$PWD/02_nsxpcserver"
sed "s|__BINPATH__|$SRV_PATH|" 02_com.offsec.nsxpc.plist.template | sudo tee /Library/LaunchDaemons/com.offsec.nsxpc.plist >/dev/null
sudo chown root:wheel /Library/LaunchDaemons/com.offsec.nsxpc.plist
sudo chmod 644 /Library/LaunchDaemons/com.offsec.nsxpc.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/com.offsec.nsxpc.plist
./02_nsxpcclient
```

Unload when done: `sudo launchctl bootout system /Library/LaunchDaemons/com.offsec.nsxpc.plist` (and `sudo rm` the plist if you are tearing down the VM image).

---

## 03–05 — Case-study PoCs (VM-only, instructor-licensed targets)

**Legal / safety:** Only run against software and OS builds you are **licensed** to use for education. Prefer **isolated VMs** pinned to the versions your worksheets assume.

```bash
# 03 — WiFiSpoof-style (Objective-C + Authorization + ARC)
gcc -fobjc-arc -framework Foundation -framework Security 03_wifispoofexp.m -o 03_wifispoofexp

# 04 — PackageKit / Shove (Monterey < 12.4)
SDKROOT=$(xcrun --show-sdk-path)
gcc -fobjc-arc -framework Foundation \
  "$SDKROOT/System/Library/PrivateFrameworks/PackageKit.framework/PackageKit.tbd" \
  04_shovexpc.m -o 04_shovexpc

# 05 — Zoom dylib (see 05_zoom_exploit_lab.sh for full race + paths; x86_64 slice)
# Script expects Drive artifacts in the **current working directory** (see script header).
```

---

## 06 — Swift NSXPC capstone (first-party vulnerable helper)

Demonstrates **local privilege escalation** through an `NSXPCListener` that accepts **any** client. **VM only.**

```bash
cd labs/ch08-xpc
sudo ./06_install_lab.sh
swiftc 06_exploit.swift -o exploit
./exploit
sudo ./06_uninstall_lab.sh
```

- **Install** compiles the helper and loads `com.example.vulnerablehelper`.
- **`06_verify_lab.sh`** — optional non-destructive check that `launchd` knows the label.

---

## Troubleshooting (01–02)

- Compile C sources with **`-fblocks`**.
- **`Connection interrupted`:** listener not running, wrong Mach name, or bootstrap failed — check launchd logs with instructor.
- **Signing:** ad hoc `codesign -s -` may be needed on stricter hosts; prefer a **lab VM**.
