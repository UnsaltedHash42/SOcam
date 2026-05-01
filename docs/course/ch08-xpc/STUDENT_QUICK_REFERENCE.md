# Chapter 8 — quick reference (keep this open; take minimal notes)

Use this page **during labs** so you can run commands from one place. Deep explanations and teaching order are in **[STUDENT_GUIDE.md](STUDENT_GUIDE.md)** and **[diagrams.md](diagrams.md)**.

---

## All code paths in this repo (Chapter 8)

| Topic | Directory | What it is |
|-------|-----------|------------|
| **C / libxpc** Mach service + client | [`labs/ch08-c-xpc/`](../../../labs/ch08-c-xpc/) | `xpcserver.c`, `xpcclient.c`, plist template — listener vs client flag |
| **NSXPC** minimal daemon + client | [`labs/ch08-pocs/`](../../../labs/ch08-pocs/) | `nsxpcserver.m`, `nsxpcclient.m`, `com.offsec.nsxpc.plist.template` |
| **Case-study PoCs** (dangerous — VM only) | [`labs/ch08-pocs/`](../../../labs/ch08-pocs/) | `wifispoofexp.m`, `shovexpc.m`, `zoomxpc.m`, `zoom_exploit_lab.sh` — see that folder’s README for OS requirements |
| **Swift** privileged helper + exploit | [`labs/xpc/`](../../../labs/xpc/) | `VulnerableHelper/`, `Exploit/exploit.swift`, `install_lab.sh`, `uninstall_lab.sh` |

**Drive-only artifacts** (Zoom pkg/zip, old WiFiSpoof, EvenBetter zip, Monterey VM): **[README.md — Lab artifacts](README.md)**.

---

## Mach names & labels (defaults in repo)

| Lab | Mach service / Label | Plist filename (after install) |
|-----|----------------------|--------------------------------|
| C XPC | `com.example.student.xpc` | `com.example.student.xpc.plist` |
| NSXPC demo | `com.offsec.nsxpc` | `com.offsec.nsxpc.plist` |
| Swift capstone | `com.example.vulnerablehelper` | from `labs/xpc/` install script |

If a lab fails with **connection invalid**, the name in **source**, **plist**, and **`launchctl print`** must match **exactly**.

---

## Copy-paste: C lab (`labs/ch08-c-xpc`)

```bash
cd labs/ch08-c-xpc
clang -fblocks -Wall -o xpcserver xpcserver.c
clang -fblocks -Wall -o xpcclient xpcclient.c
SRV_PATH="$PWD/xpcserver"
sed "s|__BINPATH__|$SRV_PATH|" com.example.student.xpc.plist.template | sudo tee /Library/LaunchDaemons/com.example.student.xpc.plist >/dev/null
sudo chown root:wheel /Library/LaunchDaemons/com.example.student.xpc.plist
sudo chmod 644 /Library/LaunchDaemons/com.example.student.xpc.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/com.example.student.xpc.plist
./xpcclient
```

**Unload when done:** see [labs/ch08-c-xpc/README.md](../../../labs/ch08-c-xpc/README.md) (bootout + `rm` plist + remove binary if you copied it out of the repo).

---

## Copy-paste: NSXPC demo (`labs/ch08-pocs`)

```bash
cd labs/ch08-pocs
clang -fobjc-arc -framework Foundation -o nsxpcserver nsxpcserver.m
clang -fobjc-arc -framework Foundation -o nsxpcclient nsxpcclient.m
SRV_PATH="$PWD/nsxpcserver"
sed "s|__BINPATH__|$SRV_PATH|" com.offsec.nsxpc.plist.template | sudo tee /Library/LaunchDaemons/com.offsec.nsxpc.plist >/dev/null
sudo chown root:wheel /Library/LaunchDaemons/com.offsec.nsxpc.plist
sudo chmod 644 /Library/LaunchDaemons/com.offsec.nsxpc.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/com.offsec.nsxpc.plist
./nsxpcclient
```

**Unload:** `sudo launchctl bootout system/com.offsec.nsxpc` then `sudo rm /Library/LaunchDaemons/com.offsec.nsxpc.plist`.

---

## Copy-paste: Swift capstone (`labs/xpc`)

```bash
cd labs/xpc
sudo ./install_lab.sh
swiftc Exploit/exploit.swift -o /tmp/exploit_run
/tmp/exploit_run
sudo ./uninstall_lab.sh
```

Details: [labs/xpc/README_STUDENT.md](../../../labs/xpc/README_STUDENT.md).

---

## Case-study worksheets (concepts + Hopper prompts)

| CVE track | Worksheet |
|-----------|-----------|
| WiFiSpoof | [case-studies/cve-2021-44214-wifispoof.md](case-studies/cve-2021-44214-wifispoof.md) |
| PackageKit / Shove | [case-studies/cve-2022-26712-packagekit.md](case-studies/cve-2022-26712-packagekit.md) |
| Zoom | [case-studies/zoom-583-lpe.md](case-studies/zoom-583-lpe.md) |

Runnable PoC source for those lectures lives in **`labs/ch08-pocs/`** — only on instructor-approved VMs and software builds.

---

## One-line reminders

- **Listener vs client:** third argument to `xpc_connection_create_mach_service` — `0` vs `XPC_CONNECTION_MACH_SERVICE_LISTENER`.
- **NSXPC privileged helper:** `initWithMachServiceName:options:` includes **`NSXPCConnectionPrivileged`** (often `0x1000` in disassembly).
- **Trust gate:** `listener:shouldAcceptNewConnection:` — if it always returns YES with no `SecCode*` path, treat the surface as **reachable**.
- **WiFiSpoof PoC:** run the compiled binary from **`~`**, not **`~/Downloads`** (Authorization / `authd` path issue).
