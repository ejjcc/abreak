/// Peer address bytes in network order, as returned by libproc.
public enum SocketPeer {
    public static func isLoopback(_ bytes: [UInt8]) -> Bool {
        if bytes.count == 4 { return bytes[0] == 127 }
        guard bytes.count == 16 else { return false }
        if bytes.dropLast().allSatisfy({ $0 == 0 }) && bytes.last == 1 { return true }
        // IPv4-mapped IPv6, e.g. ::ffff:127.0.0.1.
        return bytes.prefix(10).allSatisfy({ $0 == 0 })
            && bytes[10] == 255 && bytes[11] == 255 && bytes[12] == 127
    }
}
