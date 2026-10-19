import Darwin
import Foundation
import IOKit.pwr_mgt

/// Thin wrappers over libproc / IOPM. All calls work on same-user processes without extra permissions.
enum ProcessInspector {
    static func allPIDs() -> [pid_t] {
        let n = proc_listallpids(nil, 0)
        guard n > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(n) + 64)
        let got = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        return Array(pids.prefix(Int(max(got, 0))))
    }

    static func path(of pid: pid_t) -> String? {
        var buf = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &buf, UInt32(buf.count)) > 0 else { return nil }
        return String(cString: buf)
    }

    static func pids(named names: Set<String>) -> [pid_t] {
        allPIDs().filter { pid in
            guard let p = path(of: pid) else { return false }
            return names.contains((p as NSString).lastPathComponent)
        }
    }

    static func isAlive(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    /// Counts established TCP connections and open UDP sockets.
    static func sockets(of pid: pid_t) -> (tcpEstablished: Int, udp: Int) {
        let stride = MemoryLayout<proc_fdinfo>.stride
        let size = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard size > 0 else { return (0, 0) }
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(size) / stride + 16)
        let got = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &fds, Int32(fds.count * stride))
        guard got > 0 else { return (0, 0) }

        var tcp = 0, udp = 0
        for fd in fds.prefix(Int(got) / stride) where fd.proc_fdtype == UInt32(PROX_FDTYPE_SOCKET) {
            var si = socket_fdinfo()
            let len = Int32(MemoryLayout<socket_fdinfo>.size)
            guard proc_pidfdinfo(pid, fd.proc_fd, PROC_PIDFDSOCKETINFO, &si, len) == len else { continue }
            switch Int(si.psi.soi_kind) {
            case Int(SOCKINFO_TCP):
                if si.psi.soi_proto.pri_tcp.tcpsi_state == TSI_S_ESTABLISHED { tcp += 1 }
            case Int(SOCKINFO_IN):
                if si.psi.soi_protocol == IPPROTO_UDP { udp += 1 }
            default:
                break
            }
        }
        return (tcp, udp)
    }

    private static let timebase: mach_timebase_info_data_t = {
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)
        return tb
    }()

    /// Total CPU time consumed by the process, in nanoseconds.
    static func cpuNanos(of pid: pid_t) -> UInt64? {
        var info = rusage_info_v2()
        let ok = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V2, $0) == 0
            }
        }
        guard ok else { return nil }
        // On Apple Silicon these fields are mach absolute time units.
        let ticks = info.ri_user_time + info.ri_system_time
        return ticks * UInt64(timebase.numer) / UInt64(timebase.denom)
    }

    static let displaySleepAssertionTypes: Set<String> = ["PreventUserIdleDisplaySleep", "NoDisplaySleepAssertion"]

    /// pid -> assertion types currently held.
    static func powerAssertions() -> [pid_t: Set<String>] {
        var raw: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&raw) == kIOReturnSuccess,
              let dict = raw?.takeRetainedValue() as? [NSNumber: [[String: Any]]] else { return [:] }
        var result: [pid_t: Set<String>] = [:]
        for (pid, list) in dict {
            result[pid.int32Value] = Set(list.compactMap { $0[kIOPMAssertionTypeKey] as? String })
        }
        return result
    }

    static func name(of pid: pid_t) -> String {
        var buf = [CChar](repeating: 0, count: 256)
        proc_name(pid, &buf, UInt32(buf.count))
        return String(cString: buf)
    }
}
