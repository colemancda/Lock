import java.util
import android.app
import android.content
import android.os
import android.util
import android.view
import android.widget
import android.graphics

public final class MainActivity: Activity {
	
	// MARK: - Outlets
	
	lazy var mainContentView: FrameLayout = self.findViewById(R.id.MainContentView) as! FrameLayout
	
	// MARK: - Loading

	public override func onCreate(savedInstanceState: Bundle!) {
		super.onCreate(savedInstanceState)
		ContentView = R.layout.main
		
		
	}
	
	// MARK: - Actions
	
	
}
