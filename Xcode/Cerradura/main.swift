//
//  main.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/19/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation
import UIKit
import GATT

// print app info
print("Launching Cerradura v\(AppVersion) Build \(AppBuild)")

// add NSPersistentStore to Cerradura.Store
try! LoadPersistentStore()

UIApplicationMain(Process.argc, nil, nil, NSStringFromClass(AppDelegate))