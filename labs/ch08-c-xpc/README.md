# C / libxpc Mach service lab

Minimal **root LaunchDaemon** listener + **unprivileged client** for Chapter **8.2–style** XPC API practice. Mach service name: **`com.example.student.xpc`** (change everywhere if you conflict).

## Prerequisites

- macOS with **Command Line Tools** or Xcode.
- A **disposable VM** if you load into `/Library/LaunchDaemons` (recommended).
- Ability to run **`sudo`** for install/uninstall.

## Build

```bash
cd labs/ch08-c-xpc
clang -fblocks -o xpcclient xpcclient.c
clang -fblocks -o xpcserver xpcserver.c
```

If linking fails, try adding `-framework Foundation` (platform-dependent).

## Install (root)

1. Copy the server binary to a stable path (example uses `/usr/local/libexec` — create directory if needed, or use `/tmp` **only** for a quick smoke test with a plist pointing there).

   ```bash
   sudo mkdir -p /usr/local/libexec
   sudo cp xpcserver /usr/local/libexec/ch08-xpcserver
   sudo chmod 755 /usr/local/libexec/ch08-xpcserver
   ```

2. Copy the plist template and **replace** `__BINPATH__` with the same path:

   ```bash
   sed "s|__BINPATH__|/usr/local/libexec/ch08-xpcserver|g" com.example.student.xpc.plist.template > /tmp/ch08.plist
   sudo cp /tmp/ch08.plist /Library/LaunchDaemons/com.example.student.xpc.plist
   sudo chown root:wheel /Library/LaunchDaemons/com.example.student.xpc.plist
   ```

3. Load:

   ```bash
   sudo launchctl bootstrap system /Library/LaunchDaemons/com.example.student.xpc.plist
   ```

   On older macOS, use: `sudo launchctl load /Library/LaunchDaemons/com.example.student.xpc.plist`

## Run client (normal user)

```bash
./xpcclient
```

You should see a reply dictionary containing `"reply" => "this is my reply"` (or similar).

## Uninstall

```bash
sudo launchctl bootout system /Library/LaunchDaemons/com.example.student.xpc.plist 2>/dev/null || \
  sudo launchctl unload /Library/LaunchDaemons/com.example.student.xpc.plist 2>/dev/null
sudo rm -f /Library/LaunchDaemons/com.example.student.xpc.plist
sudo rm -f /usr/local/libexec/ch08-xpcserver
```

## Troubleshooting

- **Signing / Gatekeeper:** Student-built daemons may need ad hoc signing (`codesign -s - …`) on stricter hosts; prefer a **lab VM**.
- **`Connection interrupted`:** Server not running, wrong Mach name, or bootstrap failed — check `log show --predicate 'subsystem == "com.apple.launchd"' --last 2m` (instructor assist).
- **Blocks:** Always compile with **`-fblocks`**.

## Safety

This installs a **globally named** Mach service as **root**. Remove when done. Do not reuse `com.example.student.xpc` on shared machines without coordination.
