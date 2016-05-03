import swift
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
	
	private var foundDevices = [BluetoothDevice]()
	
	public func startScan() {
			
		log?("Scanning...")
		
		foundDevices = []
		
		let scanCallback = LockScanCallback(self)
		
		scanner.startScan(scanCallback)
		
		wait(scanDuration * 1000)
		
		scanner.flushPendingScanResults(scanCallback)
		scanner.stopScan(scanCallback)
		
		wait(1000)
		
		log?("Found \(foundDevices.count) devices")
	}
}

// MARK: - Supporting Types

private final class LockScanCallback: ScanCallback {
	
	weak var lockManager: LockManager?
	
	init(_ lockManager: LockManager) {
		
		self.lockManager = lockManager
	}
	
	func onScanResult(callbackType: Integer!, _ result: ScanResult!) {
		
		lockManager?.foundDevices.append(result.getDevice())
	}
	
	//func onBatchScanResults(results: List<ScanResult>!) { }
	
	func onScanFailed(errorCode: Integer!) {
		
		let error = ScanError(rawValue: UInt8(errorCode))!
		
		lockManager.log?("Could not scan. \(error)")
	}
}

public enum ScanError: UInt8 {
	
	case AlreadyStarted				  = 1
	case ApplicationRegistrationFailed   = 2
	case FeatureUnsupported			  = 3
	case InternalError				   = 4
}

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
