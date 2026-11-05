import Foundation
import CoreGraphics

enum ScreenLock {
    /// Poll as well as observing notifications: a missed lock event must not leave a stale break.
    static var isLocked: Bool? {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return nil }
        if session["CGSSessionScreenIsLocked"] as? Bool == true { return true }
        guard session[kCGSessionOnConsoleKey as String] as? Bool == true else { return nil }
        return false
    }
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
