import java.util

public typealias PeerIdentifier = String

public protocol Peer {
	
	/// Unique identifier of the peer.
	var identifier: PeerIdentifier { get }
}

/// Peripheral Peer
///
/// Represents a remote peripheral device that has been discovered.
public struct Peripheral: Peer {
	
	public let identifier: PeerIdentifier
}
