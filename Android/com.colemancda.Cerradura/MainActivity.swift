import java.util
import android.app
import android.content
import android.os
import android.util
import android.view
import android.widget
import android.graphics

public final class MainActivity: ActivityGroup {
	
	// MARK: - Outlets
	
	lazy var tabHost = findViewById(R.id.tabHost) as! TabHost
	
	// MARK: - Loading

	public override func onCreate(savedInstanceState: Bundle!) {
		super.onCreate(savedInstanceState)
		
		ContentView = R.layout.main
		
		tabHost.setup(self.getLocalActivityManager())
		
		addTab("Near", NearLockActivity.self)
		addTab("Keys", KeysActivity.self)
		
		LockManager.shared.startScan()
	}
	
	// MARK: - Private Methods
	
	private func addTab(name: String, _ activity: Class) {
		
		let tab = tabHost.newTabSpec(name + "Tab")
		let intent = android.content.Intent(self, activity)
		tab.setIndicator(name)
		tab.setContent(intent)
		tabHost.addTab(tab)
	}
}
