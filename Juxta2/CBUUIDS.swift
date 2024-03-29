//
//  CBUUIDS.swift
//  Juxta2
//
//  Created by Matt Gaidica on 3/2/23.
//

import Foundation
import CoreBluetooth

struct CBUUIDs{
    public static let JuxtaService = CBUUID.init(string: "FFF0")
    public static let JuxtaLogCountChar = CBUUID.init(string: "FFF1")
    public static let JuxtaMetaCountChar = CBUUID.init(string: "FFF2")
    public static let JuxtaLocalTimeChar = CBUUID.init(string: "FFF3")
    public static let BatteryVoltageChar = CBUUID.init(string: "FFF4")
    public static let DeviceTemperatureChar = CBUUID.init(string: "FFF5")
    public static let JuxtaAdvertiseModeChar = CBUUID.init(string: "FFF6")
    public static let JuxtaDataChar = CBUUID.init(string: "FFF7")
    public static let JuxtaCommandChar = CBUUID.init(string: "FFF8")
    public static let JuxtaSubjectChar = CBUUID.init(string: "FFF9")
    
    public static let InfoService = CBUUID.init(string: "180A")
    public static let InfoSoftwareChar = CBUUID.init(string: "2A28")
}
