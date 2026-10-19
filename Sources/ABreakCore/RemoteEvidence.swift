import Foundation

/// One observation of a remote-desktop host process (e.g. UURemoteServer).
public struct RemoteProcessSample: Equatable, Sendable {
    public var pid: Int32
    public var name: String
    public var tcpEstablished: Int
    public var udpSockets: Int
    public var cpuPercent: Double
    public var holdsDisplayAssertion: Bool

    public init(pid: Int32, name: String, tcpEstablished: Int, udpSockets: Int, cpuPercent: Double, holdsDisplayAssertion: Bool) {
        self.pid = pid
        self.name = name
        self.tcpEstablished = tcpEstablished
        self.udpSockets = udpSockets
        self.cpuPercent = cpuPercent
        self.holdsDisplayAssertion = holdsDisplayAssertion
    }
}

public struct RemoteEvidenceRule: Equatable, Sendable {
    /// An idle host keeps exactly one signaling connection; a live session opens media transport on top of it.
    public var tcpThreshold = 2
    public var udpThreshold = 1
    /// Screen capture + encoding keeps the host busy; an idle host sits at ~0%.
    public var cpuThreshold = 3.0

    public init() {}

    public func isActive(_ s: RemoteProcessSample) -> Bool {
        s.tcpEstablished >= tcpThreshold
            || s.udpSockets >= udpThreshold
            || s.cpuPercent >= cpuThreshold
            || s.holdsDisplayAssertion
    }
}
