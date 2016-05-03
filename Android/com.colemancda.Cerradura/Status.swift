
/// Lock status
public enum Status: UInt8 {
	
	/// Initial Status
	case setup
	
	/// Idle / Unlock Mode
	case unlock
	
	/// New Key being added to database.
	case newKey
}


