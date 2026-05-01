import Foundation

/*
 * =============================================================================
 * VulnerableHelper — teaching-only privileged XPC service (Swift / NSXPC)
 * =============================================================================
 *
 * PURPOSE
 *   This binary is installed as root via LaunchDaemon and exposes an NSXPC
 *   Mach service. It is deliberately insecure so students can practice
 *   connecting from an unprivileged process — the same *class* of bug as many
 *   real-world privileged-helper mistakes, but limited to this lab Mach name.
 *
 * WHAT STUDENTS HAVE IN GIT vs GOOGLE DRIVE
 *   • All Swift/C source for this course’s XPC labs lives in the repo.
 *   • Google Drive (or similar) is only for large apps (e.g. Slack.app) or
 *     VM images — not for this helper’s source.
 *   • “Real world” CVE labs (WiFiSpoof, PackageKit, Zoom) use worksheets under
 *     docs/course/ch08-xpc/case-studies/ plus binaries *you* provide; we do
 *     not ship full third-party exploit PoC source here (legal + bitrot).
 *
 * MACH SERVICE NAME
 *   Must match 06_com.example.vulnerablehelper.plist and the client in
 *   06_exploit.swift — change all three together if you rename.
 *
 * =============================================================================
 */

// MARK: - Remote protocol (must match the client)

/// Methods the **client** may invoke on this service. `@objc` exposes the
/// selector names to the Objective-C runtime, which NSXPC uses for dispatch.
/// Every argument/return must be XPC-safe (see Apple’s NSXPC docs).
@objc(VulnerableHelperProtocol)
protocol VulnerableHelperProtocol {
    /// Runs a shell command as **root** (because this process is root).
    /// The `reply` block is how async results return to the caller.
    func executeCommand(_ command: String, withReply reply: @escaping (String) -> Void)
}

// MARK: - Service implementation

/// The object that actually handles remote messages.
/// `NSXPCListenerDelegate` — decides whether to accept new XPC connections.
class VulnerableHelper: NSObject, VulnerableHelperProtocol, NSXPCListenerDelegate {

    /// **Dangerous by design:** runs `command` through `/bin/zsh -c` as root.
    /// In a real helper you would whitelist operations, not arbitrary shell.
    func executeCommand(_ command: String, withReply reply: @escaping (String) -> Void) {
        NSLog("Received command: \(command)")

        let task = Process()
        task.launchPath = "/bin/zsh"
        // `-c` runs a single string as a script — maximum power, maximum abuse.
        task.arguments = ["-c", command]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                reply(output)
            } else {
                reply("Command executed, but no output.")
            }
        } catch {
            reply("Error: \(error)")
        }
    }

    // MARK: NSXPCListenerDelegate — **authorization gate** (intentionally broken)

    /// Called once per incoming `NSXPCConnection` **before** messages flow.
    ///
    /// **Secure pattern (not implemented here):**
    /// 1. Obtain the peer’s code signing identity (e.g. `SecCodeCopyGuestWithAttributes`
    ///    with audit token, not raw PID — PID reuse breaks naive checks).
    /// 2. Build a `SecRequirement` string (team ID, bundle ID, hardened runtime).
    /// 3. Call `SecCodeCheckValidity` (or equivalent) and return `false` if it fails.
    ///
    /// **What this lab does wrong:** returns `true` for everyone, so any local
    /// process that can open the Mach service name can become root via
    /// `executeCommand`.
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        _ = listener // required by protocol; unused here

        // VULNERABILITY: unconditional accept — the heart of the lab.
        // Students compare this to Apple’s EvenBetterAuthorizationSample / SecCode patterns.

        newConnection.exportedInterface = NSXPCInterface(with: VulnerableHelperProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }
}

// MARK: - Launch as Mach-based listener (matches plist MachServices key)

/// Global scope: `NSXPCListener(machServiceName:)` ties this process to the
/// name registered in launchd (`com.example.vulnerablehelper`). launchd holds
/// the receive right; this process becomes the XPC listener for that service.
let delegate = VulnerableHelper()
let listener = NSXPCListener(machServiceName: "com.example.vulnerablehelper")
listener.delegate = delegate
listener.resume()

// Block forever — daemons must not exit or the service disappears.
RunLoop.main.run()
