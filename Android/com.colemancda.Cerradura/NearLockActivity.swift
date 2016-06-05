﻿import java.util
import android.app
import android.content
import android.os
import android.util
import android.view
import android.widget
import android.graphics.drawable

public class NearLockActivity: Activity {
	
	// MARK: - Outlets
	
	lazy var actionButton = findViewById(R.id.ActionButton) as! ImageButton
	
	// MARK: - Loading

	public override func onCreate(savedInstanceState: Bundle!) {

		super.onCreate(savedInstanceState)

		// Set our view from the "NearLockActivity" layout resource
		ContentView = R.layout.nearlockactivity
		
		actionButton.OnClickListener = { (v: View!) in self.buttonPressed() }
		
		self.updateUI()
	}
	
	// MARK: - Actions
	
	private func buttonPressed() {
		
		print("Action button pressed")
		
		
	}
	
	// MARK: - Methods
	
	private func updateUI() {
		
		actionButton.setBackgroundResource(R.drawable.scananimation)
		let scanAnimation = actionButton.Background as! AnimationDrawable
		scanAnimation.start()
	}
}