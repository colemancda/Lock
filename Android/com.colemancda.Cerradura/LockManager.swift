import java.util
import android.bluetooth.le
import android.bluetooth


public final class LockManager {
		
	// MARK: - Initialization
	
	public static let shared: LockManager = LockManager()
	
	private init() { }
	
	// MARK: - Properties
		
	public var log: (String -> ())?
	
	public let scanDuration = 2
	
	public let foundLock = Observable<(peripheral: Peripheral, UUID: UUID, status: Status, model: Model, version: UInt64)?>()
	
	// MARK: - Private Properties
	
	private lazy var adapter: android.bluetooth.BluetoothAdapter = BluetoothAdapter.getDefaultAdapter()!
	
	private lazy var scanner: android.bluetooth.le.BluetoothLeScanner = adapter.getBluetoothLeScanner()
	
	public func startScan() {
		
		class LockScanCallback: ScanCallback {
			
			
		}
			
		log?("Scanning...")
		
		scanner.startScan()
	}
}

// MARK: - Supporting Types

public final class Observable<Value> {
	
	// MARK: - Properties
	
	public private(set) var value: Value? {
		
		didSet {
			
			for observer in observers {
				
				observer.callback(value)
			}
		}
	}
	
	// MARK: - Private Properties
	
	private var observers = [Observer<Value>]()
	
	private var nextID = 1
	
	// MARK: - Initialization
	
	public init(_ value: Value? = nil) {
		
		self.value = value
	}
	
	// MARK: - Methods
	
	public func observe(callback: Value? -> ()) -> Int {
		
		let identifier = nextID
		
		// create notification
		let observer = com.colemancda.cerradura.Observer.init(identifier, callback)
		
		// increment ID
		nextID += 1
		
		// add to queue
		observers.append(observer)
		
		return identifier
	}
	
	public func remove(observer identifier: Int) -> Bool {
		
		var index: Int!
		
		for (elementIndex, element) in self.observers.enumerate() {
		 
			if element.identifier == identifier {
				
				index = elementIndex
				break
			}
		}
		
		guard index != nil
			else { return false }
		
		observers.removeAtIndex(index)
		
		return true
	}
}

private struct Observer<Value> {
	
	let identifier: Int
	
	let callback: Value? -> ()
	
	init(_ identifier: Int, _ callback: Value? -> ()) {
		
		self.identifier = identifier
		self.callback = callback
	}
}
