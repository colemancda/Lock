//
//  Version.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 7/1/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import Foundation.NSBundle

/// Version of the app.
public let AppVersion = Bundle.main().infoDictionary!["CFBundleShortVersionString"] as! String

/// Build of the app.
public let AppBuild = Bundle.main().infoDictionary!["CFBundleVersion"] as! String

/// The App Group of Cerradura.
public let AppGroup = "group.com.colemancda.Cerradura"
