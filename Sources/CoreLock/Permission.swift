//
//  Permission.swift
//  Lock
//
//  Created by Alsey Coleman Miller on 4/20/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

#if os(Linux)
    import Glibc
#endif

import SwiftFoundation

/// A Key's permission level.
public enum Permission {
    
    /// This key belongs to the owner of the lock and has unlimited rights.
    case owner
    
    /// This key can create new keys, and has anytime access. 
    case admin
    
    /// This key has anytime access.
    case anytime
    
    //// This ket has access during certain hours and can expire.
    case scheduled(Schedule)
    
    /// Byte value of the permission type.
    public var byte: Byte {
        
        switch self {
            
        case .owner:        return 0x00
        case .admin:        return 0x01
        case .anytime:      return 0x02
        case .scheduled(_): return 0x03
        }
    }
    
    public static let length = 1 + sizeof(Int64.self) + (2 * sizeof(UInt16)) + Schedule.Weekdays.length // 20
    
    public func toBigEndian() -> Data {
        
        switch self {
            
        case let .scheduled(schedule):
            
            var expiryBigEndianValue = Int64(schedule.expiry.since1970).bigEndian
            
            var expiryBytes = [UInt8](repeating: 0, count: sizeof(Int64))
            
            withUnsafePointer(&expiryBigEndianValue) { memcpy(&expiryBytes, $0, sizeof(Int64.self)) }
            
            let startBytes = schedule.interval.rawValue.startIndex.bigEndian.bytes
            
            let endBytes = schedule.interval.rawValue.endIndex.bigEndian.bytes
            
            let weekdaysBytes = schedule.weekdays.toData().byteValue
            
            let bytes = [self.byte] + expiryBytes + [startBytes.0, startBytes.1, endBytes.0, endBytes.1] + weekdaysBytes
            
            return Data(byteValue: bytes)
        
        case .owner, .admin, .anytime:
            
            var bytes = [UInt8](repeating: 0, count: Permission.length)
            
            bytes[0] = self.byte
            
            return Data(byteValue: bytes)
        }
    }
    
    public init?(bigEndian: Data) {
        
        guard bigEndian.byteValue.count == Permission.length
            else { return nil }
        
        let byteValue = bigEndian.byteValue
        
        let permissionTypeByte = byteValue[0]
        
        switch permissionTypeByte {
            
        case Permission.owner.byte: self = .owner
            
        case Permission.admin.byte: self = .admin
            
        case Permission.anytime.byte: self = .anytime
            
        // scheduled
        case 0x03:
            
            var dateBytes = Array(byteValue[1 ..< 1 + sizeof(Int64)])
            
            var dateValue: Int64 = 0
            
            withUnsafeMutablePointer(&dateValue) { memcpy($0, &dateBytes, sizeof(Int64)) }
            
            dateValue = dateValue.bigEndian
            
            let start = UInt16.init(bytes: (byteValue[sizeof(Int64) + 1], byteValue[sizeof(Int64) + 2])).bigEndian
            
            let end = UInt16.init(bytes: (byteValue[sizeof(Int64) + 3], byteValue[sizeof(Int64) + 4])).bigEndian
            
            guard start <= end else { return nil }
            
            guard let interval = Schedule.Interval(rawValue: start ... end)
                else { return nil }
            
            let weekdaysBytes = Array(byteValue[sizeof(Int64) + 5 ... sizeof(Int64) + 5])
            
            guard let weekdays = Schedule.Weekdays(data: Data(byteValue: weekdaysBytes))
                else { return nil }
            
            let schedule = Schedule(expiry: Date(since1970: TimeInterval(dateValue)), interval: interval, weekdays: weekdays)
            
            self = .scheduled(schedule)
            
        // invalid type byte
        default: return nil
        }
    }
}

public extension Permission {
    
    /// Specifies the time and dates a permission is valid.
    public struct Schedule {
        
        /// The date this permission becomes invalid.
        public var expiry: Date
        
        /// The minute interval range the lock can be unlocked.
        public var interval: Interval
        
        /// The days of the week the permission is valid
        public var weekdays: Weekdays
        
        public init(expiry: Date, interval: Interval = Interval.anytime, weekdays: Weekdays) {
            
            self.expiry = expiry
            self.interval = interval
            self.weekdays = weekdays
        }
        
        /// Verify that the specified date is valid for this schedule.
        public func valid(_ date: Date = Date()) -> Bool {
            
            guard date < expiry else { return false }
            
            // need to get hour and minute of day to validate
            let dateComponents = DateComponents(date: date)
            
            let minutesValue = UInt16(dateComponents.minute * dateComponents.hour)
            
            guard interval.rawValue.contains(minutesValue)
                else { return false }
            
            let canOpenOnDay = weekdays[Int(dateComponents.weekday)]
            
            guard canOpenOnDay else { return false }
            
            return true
        }
    }
}

public extension Permission.Schedule {
    
    /// The minute interval range the lock can be unlocked.
    public struct Interval: RawRepresentable {
        
        public static let min: UInt16 = 0
        
        public static let max: UInt16 = 1440
        
        /// Interval for anytime access.
        public static let anytime = Interval(rawValue: Interval.min ... Interval.max)!
        
        public let rawValue: Range<UInt16>
        
        public init?(rawValue: Range<UInt16>) {
            
            guard rawValue.endIndex <= Interval.max
                else { return nil }
            
            self.rawValue = rawValue
        }
    }
}

public extension Permission.Schedule {
    
    public struct Weekdays: DataConvertible {
        
        public static let length = 7
        
        public var sunday: Bool
        public var monday: Bool
        public var tuesday: Bool
        public var wednesday: Bool
        public var thursday: Bool
        public var friday: Bool
        public var saturday: Bool
        
        public init(sunday: Bool,
                    monday: Bool,
                    tuesday: Bool,
                    wednesday: Bool,
                    thursday: Bool,
                    friday: Bool,
                    saturday: Bool) {
            
            self.sunday = sunday
            self.monday = monday
            self.tuesday = tuesday
            self.wednesday = wednesday
            self.thursday = thursday
            self.friday = friday
            self.saturday = saturday
        }
        
        public subscript (weekday: Int) -> Bool {
            
            get {
                
                switch weekday {
                    
                case 1: return sunday
                case 2: return monday
                case 3: return tuesday
                case 4: return wednesday
                case 5: return thursday
                case 6: return friday
                case 7: return saturday
                    
                default: fatalError("Invalid weekday \(weekday)")
                }
            }
            
            set {
                
                switch weekday {
                    
                case 1: sunday = newValue
                case 2: monday = newValue
                case 3: tuesday = newValue
                case 4: wednesday = newValue
                case 5: thursday = newValue
                case 6: friday = newValue
                case 7: saturday = newValue
                    
                default: fatalError("Invalid weekday \(weekday)")
                }
            }
        }
        
        public init?(data: Data) {
            
            guard data.byteValue.count == Weekdays.length
                else { return nil }
            
            guard let sunday = BluetoothBool(rawValue: data.byteValue[0])?.boolValue,
                let monday = BluetoothBool(rawValue: data.byteValue[1])?.boolValue,
                let tuesday = BluetoothBool(rawValue: data.byteValue[2])?.boolValue,
                let wednesday = BluetoothBool(rawValue: data.byteValue[3])?.boolValue,
                let thursday = BluetoothBool(rawValue: data.byteValue[4])?.boolValue,
                let friday = BluetoothBool(rawValue: data.byteValue[5])?.boolValue,
                let saturday = BluetoothBool(rawValue: data.byteValue[6])?.boolValue
                else { return nil }
            
            self.sunday = sunday
            self.monday = monday
            self.tuesday = tuesday
            self.wednesday = wednesday
            self.thursday = thursday
            self.friday = friday
            self.saturday = saturday
        }
        
        public func toData() -> Data {
            
            var bytes = [UInt8](repeating: 0, count: Weekdays.length)
            
            bytes[0] = BluetoothBool(sunday).rawValue
            bytes[1] = BluetoothBool(monday).rawValue
            bytes[2] = BluetoothBool(tuesday).rawValue
            bytes[3] = BluetoothBool(wednesday).rawValue
            bytes[4] = BluetoothBool(thursday).rawValue
            bytes[5] = BluetoothBool(friday).rawValue
            bytes[6] = BluetoothBool(saturday).rawValue
            
            return Data(byteValue: bytes)
        }
    }
}
