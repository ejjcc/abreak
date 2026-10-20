import Foundation

enum ScreenLock {
    /// Locks the session via login.framework's SACLockScreenImmediate (no public API exists);
    /// falls back to sleeping the display, which locks when "require password immediately" is on.
    static func lock() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_NOW),
           let sym = dlsym(handle, "SACLockScreenImmediate") {
            typealias Fn = @convention(c) () -> Int32
            _ = unsafeBitCast(sym, to: Fn.self)()
            return
        }
        Log.write("SACLockScreenImmediate unavailable, falling back to pmset displaysleepnow")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["displaysleepnow"]
        try? task.run()
    }
}
