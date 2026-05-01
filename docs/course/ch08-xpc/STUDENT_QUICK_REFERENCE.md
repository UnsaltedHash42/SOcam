# Chapter 8 — quick reference (keep this open; take minimal notes)

Use this page **during labs** so you can run commands from one place. Deep explanations and teaching order are in **[STUDENT_GUIDE.md](STUDENT_GUIDE.md)** and **[diagrams.md](diagrams.md)**.

---

## All code paths in this repo (Chapter 8)

| Topic | Directory | What it is |
|-------|-----------|------------|
| **C / libxpc** Mach service + client | [`labs/ch08-xpc/`](../../../labs/ch08-xpc/) | `01_xpcserver.c`, `01_xpcclient.c`, plist template — listener vs client flag |
| **NSXPC** minimal daemon + client | [`labs/ch08-xpc/`](../../../labs/ch08-xpc/) | `02_nsxpcserver.m`, `02_nsxpcclient.m`, `02_com.offsec.nsxpc.plist.template` |
| **Case-study PoCs** (dangerous — VM only) | [`labs/ch08-xpc/`](../../../labs/ch08-xpc/) | `03_wifispoofexp.m`, `04_shovexpc.m`, `05_zoomxpc.m`, `05_zoom_exploit_lab.sh` — see that folder’s README for OS requirements |
| **Swift** privileged helper + exploit | [`labs/ch08-xpc/`](../../../labs/ch08-xpc/) | `06_VulnerableHelper.swift`, `06_exploit.swift`, `06_install_lab.sh`, `06_uninstall_lab.sh` |

**Drive-only artifacts** (Zoom pkg/zip, old WiFiSpoof, EvenBetter zip, Monterey VM): **[README.md — Lab artifacts](README.md)**.

---

## Mach names & labels (defaults in repo)

| Lab | Mach service / Label | Plist filename (after install) |
|-----|----------------------|--------------------------------|
| C XPC | `com.example.student.xpc` | `com.example.student.xpc.plist` |
| NSXPC demo | `com.offsec.nsxpc` | `com.offsec.nsxpc.plist` |
| Swift capstone | `com.example.vulnerablehelper` | from `labs/ch08-xpc/` install script |

If a lab fails with **connection invalid**, the name in **source**, **plist**, and **`launchctl print`** must match **exactly**.

---

## Copy-paste: C lab (`labs/ch08-xpc`)

```bash
cd labs/ch08-xpc
clang -fblocks -Wall -o 01_xpcserver 01_xpcserver.c
clang -fblocks -Wall -o 01_xpcclient 01_xpcclient.c
SRV_PATH="$PWD/01_xpcserver"
sed "s|__BINPATH__|$SRV_PATH|" 01_com.example.student.xpc.plist.template | sudo tee /Library/LaunchDaemons/com.example.student.xpc.plist >/dev/null
sudo chown root:wheel /Library/LaunchDaemons/com.example.student.xpc.plist
sudo chmod 644 /Library/LaunchDaemons/com.example.student.xpc.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/com.example.student.xpc.plist
./01_xpcclient
```

**Unload when done:** see [labs/ch08-xpc/README.md](../../../labs/ch08-xpc/README.md) (bootout + `rm` plist + remove binary if you copied it out of the repo).

---

## Copy-paste: NSXPC demo (`labs/ch08-xpc`)

```bash
cd labs/ch08-xpc
clang -fobjc-arc -framework Foundation -o 02_nsxpcserver 02_nsxpcserver.m
clang -fobjc-arc -framework Foundation -o 02_nsxpcclient 02_nsxpcclient.m
SRV_PATH="$PWD/02_nsxpcserver"
sed "s|__BINPATH__|$SRV_PATH|" 02_com.offsec.nsxpc.plist.template | sudo tee /Library/LaunchDaemons/com.offsec.nsxpc.plist >/dev/null
sudo chown root:wheel /Library/LaunchDaemons/com.offsec.nsxpc.plist
sudo chmod 644 /Library/LaunchDaemons/com.offsec.nsxpc.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/com.offsec.nsxpc.plist
./02_nsxpcclient
```

**Unload:** `sudo launchctl bootout system/com.offsec.nsxpc` then `sudo rm /Library/LaunchDaemons/com.offsec.nsxpc.plist`.

---

## Copy-paste: Swift capstone (`labs/ch08-xpc`)

```bash
cd labs/ch08-xpc
sudo ./06_install_lab.sh
swiftc 06_exploit.swift -o /tmp/exploit_run
/tmp/exploit_run
sudo ./06_uninstall_lab.sh
```

Details: [labs/ch08-xpc/README.md](../../../labs/ch08-xpc/README.md).

---

## Case-study worksheets (concepts + Hopper prompts)

| CVE track | Worksheet |
|-----------|-----------|
| WiFiSpoof | [case-studies/cve-2021-44214-wifispoof.md](case-studies/cve-2021-44214-wifispoof.md) |
| PackageKit / Shove | [case-studies/cve-2022-26712-packagekit.md](case-studies/cve-2022-26712-packagekit.md) |
| Zoom | [case-studies/zoom-583-lpe.md](case-studies/zoom-583-lpe.md) |

Runnable PoC source for those lectures lives in **`labs/ch08-xpc/`** — only on instructor-approved VMs and software builds.

---

## One-line reminders

- **Listener vs client:** third argument to `xpc_connection_create_mach_service` — `0` vs `XPC_CONNECTION_MACH_SERVICE_LISTENER`.
- **NSXPC privileged helper:** `initWithMachServiceName:options:` includes **`NSXPCConnectionPrivileged`** (often `0x1000` in disassembly).
- **Trust gate:** `listener:shouldAcceptNewConnection:` — if it always returns YES with no `SecCode*` path, treat the surface as **reachable**.
- **WiFiSpoof PoC:** run the compiled binary from **`~`**, not **`~/Downloads`** (Authorization / `authd` path issue).
