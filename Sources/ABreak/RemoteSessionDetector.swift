import Foundation
import ABreakCore

/// Detects that this Mac is being remotely viewed/controlled by watching the host process
/// of a remote-desktop tool (UURemote: `UURemoteServer`). An idle host keeps one signaling
/// connection and ~0% CPU; a live session adds media sockets and capture/encode load.
final class RemoteSessionDetector {
    var processNames: Set<String> {
        didSet { if processNames != oldValue { pids = []; lastScan = .distantPast } }
    }
    var rule = RemoteEvidenceRule()
    private(set) var latch = ActivityLatch(onAfter: 2, offAfter: 20)
    private(set) var lastSamples: [RemoteProcessSample] = []

    private var pids: [pid_t] = []
    private var lastScan = Date.distantPast
    private var lastCPU: [pid_t: (nanos: UInt64, at: Date)] = [:]

    init(processNames: Set<String>) {
        self.processNames = processNames
    }

    var isActive: Bool { latch.isOn }

    @discardableResult
    func poll(now: Date = Date()) -> Bool {
        if now.timeIntervalSince(lastScan) > 30 || pids.contains(where: { !ProcessInspector.isAlive($0) }) {
            pids = ProcessInspector.pids(named: processNames)
            lastScan = now
        }
        let assertions = ProcessInspector.powerAssertions()
        lastSamples = pids.map { sample($0, now: now, assertions: assertions[$0] ?? []) }
        return latch.update(lastSamples.contains(where: rule.isActive), at: now)
    }

    private func sample(_ pid: pid_t, now: Date, assertions: Set<String>) -> RemoteProcessSample {
        let sockets = ProcessInspector.sockets(of: pid)
        var cpu = 0.0
        if let nanos = ProcessInspector.cpuNanos(of: pid) {
            if let prev = lastCPU[pid], nanos >= prev.nanos {
                let wall = now.timeIntervalSince(prev.at)
                if wall > 0 { cpu = Double(nanos - prev.nanos) / 1e9 / wall * 100 }
            }
            lastCPU[pid] = (nanos, now)
        }
        return RemoteProcessSample(
            pid: pid,
            name: ProcessInspector.name(of: pid),
            tcpEstablished: sockets.tcpEstablished,
            udpSockets: sockets.udp,
            cpuPercent: cpu,
            holdsDisplayAssertion: !assertions.isDisjoint(with: ProcessInspector.displaySleepAssertionTypes)
        )
    }
}
