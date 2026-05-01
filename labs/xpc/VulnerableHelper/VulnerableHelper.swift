import Foundation

// 1. Define the Protocol
@objc(VulnerableHelperProtocol)
protocol VulnerableHelperProtocol {
    func executeCommand(_ command: String, withReply reply: @escaping (String) -> Void)
}

// 2. Implement the Service Class
class VulnerableHelper: NSObject, VulnerableHelperProtocol, NSXPCListenerDelegate {
    
    // The Vulnerable Method
    func executeCommand(_ command: String, withReply reply: @escaping (String) -> Void) {
        NSLog("Recieved command: \(command)")
        
        let task = Process()
        task.launchPath = "/bin/zsh"
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
    
    // The Listener Delegate - THIS IS WHERE THE BUG IS
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // VULNERABILITY: We accept ALL connections.
        // We SHOULD be checking:
        // 1. newConnection.auditToken
        // 2. SecCodeCopyGuestWithAttributes(...)
        // 3. Verify it is signed by OUR Team ID.
        
        newConnection.exportedInterface = NSXPCInterface(with: VulnerableHelperProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }
}

// 3. Main Entry Point
let delegate = VulnerableHelper()
let listener = NSXPCListener(machServiceName: "com.example.vulnerablehelper")
listener.delegate = delegate
listener.resume()

// Keep the daemon running
RunLoop.main.run()
