# Chapter 8 — reference POCs (organization-private GitHub)

These files reproduce the **worked examples** from your licensed course materials so you **do not live-code** during class. They are **dangerous** on real machines: use **isolated VMs** only, matching **OS versions** noted below.

| File | Topic | Target environment |
|------|--------|----------------------|
| [`wifispoofexp.m`](wifispoofexp.m) | CVE-2021-44214-style helper abuse | **Vulnerable WiFiSpoof build** from your Drive + **not** from Downloads (authd path issue) |
| [`shovexpc.m`](shovexpc.m) | CVE-2022-26712 PackageKit / Shove | **Monterey &lt; 12.4** VM; run binary **`sudo`** as in original lab |
| [`zoomxpc.m`](zoomxpc.m) | Zoom daemon XPC stub | Loaded via dylib injection path in shell script |
| [`zoom_exploit_lab.sh`](zoom_exploit_lab.sh) | Full race + pkg + Rosetta path | **Sonoma** VM + artifacts named in script header |
| [`nsxpcclient.m`](nsxpcclient.m) / [`nsxpcserver.m`](nsxpcserver.m) | Minimal NSXPC pair | Requires plist install `com.offsec.nsxpc` (template included) |
| [`com.offsec.nsxpc.plist.template`](com.offsec.nsxpc.plist.template) | LaunchDaemon for NSXPC demo | Edit `__BINPATH__` |

**Also in repo (first-party teaching):** `labs/ch08-c-xpc/`, `labs/xpc/` — heavily commented Swift/C labs.

## Build cheatsheet

```bash
# WiFiSpoof PoC (Objective-C + Authorization + ARC)
gcc -fobjc-arc -framework Foundation -framework Security wifispoofexp.m -o wifispoofexp

# PackageKit / Shove (Objective-C + PackageKit + ARC)
SDKROOT=$(xcrun --show-sdk-path)
gcc -fobjc-arc -framework Foundation \
  "$SDKROOT/System/Library/PrivateFrameworks/PackageKit.framework/PackageKit.tbd" \
  shovexpc.m -o shovexpc

# Zoom dylib (often x86_64 for old Zoom)
gcc -arch x86_64 -dynamiclib -framework Foundation …   # see zoom_exploit_lab.sh

# NSXPC minimal
gcc -fobjc-arc -framework Foundation nsxpcclient.m -o nsxpcclient
gcc -fobjc-arc -framework Foundation nsxpcserver.m -o nsxpcserver
```

## Legal / pedagogy

- Only run against software you are **licensed** to use for education.
- Prefer **your Drive bundle** pinned to the **exact** vulnerable versions your worksheets assume.
