import Foundation

/// Keep the activity name: a display-sleep assertion alone is not evidence of video.
public struct PowerAssertion: Equatable, Sendable {
    public var type: String
    public var name: String
    public var isActive: Bool

    public init(type: String, name: String, isActive: Bool) {
        self.type = type
        self.name = name
        self.isActive = isActive
    }

    public var preventsDisplaySleep: Bool {
        isActive && (type == "PreventUserIdleDisplaySleep" || type == "NoDisplaySleepAssertion")
    }

    public var isVideoPlayback: Bool {
        guard preventsDisplaySleep else { return false }
        // Chromium, WebKit and VLC describe playback explicitly. Their audio-only
        // assertions prevent system sleep instead and do not pass the guard above.
        // Capture, screen wake locks, continuity and unknown activities are not video.
        switch name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "video wake lock", "playing video",
             "com.apple.webcore: htmlmediaelement playback", "vlc media playback":
            return true
        default:
            return false
        }
    }
}
