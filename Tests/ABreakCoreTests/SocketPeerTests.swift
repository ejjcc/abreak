import Testing
@testable import ABreakCore

@Test func localProxyPeersAreNotRemoteConnections() {
    #expect(SocketPeer.isLoopback([127, 0, 0, 1]))
    #expect(SocketPeer.isLoopback([127, 42, 0, 2]))
    #expect(SocketPeer.isLoopback(Array(repeating: 0, count: 15) + [1]))
    #expect(SocketPeer.isLoopback(Array(repeating: 0, count: 10) + [255, 255, 127, 0, 0, 1]))
    #expect(!SocketPeer.isLoopback([192, 168, 1, 2]))
    #expect(!SocketPeer.isLoopback([198, 18, 1, 17])) // Surge's routed address is still a network peer.
    #expect(!SocketPeer.isLoopback([0, 0, 0, 0])) // Unconnected UDP remains observable.
    #expect(!SocketPeer.isLoopback([0x20, 1] + Array(repeating: 0, count: 13) + [1]))
    #expect(!SocketPeer.isLoopback(Array(repeating: 0, count: 10) + [255, 255, 192, 168, 1, 2]))
}
