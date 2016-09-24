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
public enum Permission: Equatable {
    
    /// This key belongs to the owner of the lock and has unlimited rights.
    case owner
    
    /// This key can create new keys, and has anytime access. 
    case admin
    
    /// This key has anytime access.
    case anytime
    
    //// This key has access during certain hours and can expire.
    case scheduled(Schedule)
    
    /// Byte value of the permission type.
    public var type: PermissionType {
        
        switch self {
            
        case .owner:        return .owner
        case .admin:        return .admin
        case .anytime:      return .anytime
        case .scheduled(_): return .scheduled
        }
    }
    
    public static let length = 1 + MemoryLayout<Int64>.size + (2 * MemoryLayout<UInt16>.size) + Schedule.Weekdays.length // 20
    
    public func toBigEndian() -> Data {
        
        switch self {
            
        case let .scheduled(schedule):
            
            var expiryBigEndianValue = Int64(schedule.expiry.timeIntervalSince1970).bigEndian
            
            var expiryBytes = [UInt8](repeating: 0, count: MemoryLayout<Int64>.size)
            
            withUnsafePointer(to: &expiryBigEndianValue) { let _ = memcpy(&expiryBytes, $0, MemoryLayout<Int64>.size) }
            
            let startBytes = schedule.interval.rawValue.lowerBound.bigEndian.bytes
            
            let endBytes = schedule.interval.rawValue.upperBound.bigEndian.bytes
            
            let weekdaysBytes = schedule.weekdays.toData().bytes
            
            let bytes = [self.type.rawValue] + expiryBytes + [startBytes.0, startBytes.1, endBytes.0, endBytes.1] + weekdaysBytes
            
            assert(bytes.count == type(of: self).length)
            
            return Data(bytes: bytes)
        
        case .owner, .admin, .anytime:
            
            var bytes = [UInt8](repeating: 0, count: Permission.length)
            
            bytes[0] = self.type.rawValue
            
            return Data(bytes: bytes)
        }
    }
    
    public init?(bigEndian: Data) {
        
        guard bigEndian.bytes.count == Permission.length
            else { return nil }
        
        let byteValue = bigEndian.bytes
        
        let permissionTypeByte = byteValue[0]
        
        switch permissionTypeByte {
            
        case PermissionType.owner.rawValue: self = .owner
            
        case PermissionType.admin.rawValue: self = .admin
            
        case PermissionType.anytime.rawValue: self = .anytime
            
        // scheduled
        case PermissionType.scheduled.rawValue:
            
            var dateBytes = Array(byteValue[1 ..< 1 + MemoryLayout<Int64>.size])
            
            var dateValue: Int64 = 0
            
            withUnsafeMutablePointer(to: &dateValue) { let _ = memcpy($0, &dateBytes, MemoryLayout<Int64>.size) }
            
            dateValue = dateValue.bigEndian
            
            let start = UInt16.init(bytes: (byteValue[MemoryLayout<Int64>.size + 1], byteValue[MemoryLayout<Int64>.size + 2])).bigEndian
            
            let end = UInt16.init(bytes: (byteValue[MemoryLayout<Int64>.size + 3], byteValue[MemoryLayout<Int64>.size + 4])).bigEndian
            
            guard start <= end else { return nil }
            
            guard let interval = Schedule.Interval(rawValue: start ... end)
                else { return nil }
            
            let weekdaysBytes = Array(byteValue[MemoryLayout<Int64>.size + 5 ..< MemoryLayout<Int64>.size + 5 + Schedule.Weekdays.length])
            
            guard let weekdays = Schedule.Weekdays(data: Data(bytes: weekdaysBytes))
                else { return nil }
            
            let schedule = Schedule(expiry: Date(timeIntervalSince1970: TimeInterval(dateValue)), interval: interval, weekdays: weekdays)
            
            self = .scheduled(schedule)
            
        // invalid type byte
        default: return nil
        }
    }
}

public enum PermissionType: UInt8 {
    
    case owner
    case admin
    case anytime
    case scheduled
}

public func == (lhs: Permission, rhs: Permission) -> Bool {
    
    switch (lhs, rhs) {
        
    case (.owner, .owner): return true
    case (.admin, .admin): return true
    case (.anytime, .anytime): return true
    case let (.scheduled(lhsSchedule), .scheduled(rhsSchedule)): return lhsSchedule == rhsSchedule
        
    default: return false
    }
}

// MARK: - Schedule

public extension Permission {
    
    /// Specifies the time and dates a permission is valid.
    public struct Schedule: Equatable {
        
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

public func == (lhs: Permission.Schedule, rhs: Permission.Schedule) -> Bool {
    
    return lhs.expiry == rhs.expiry
        && lhs.interval == rhs.interval
        && lhs.weekdays == rhs.weekdays
}

// MARK: - Schedule Interval

public extension Permission.Schedule {
    
    /// The minute interval range the lock can be unlocked.
    public struct Interval: RawRepresentable, Equatable {
        
        public static let min: UInt16 = 0
        
        public static let max: UInt16 = 1440
        
        /// Interval for anytime access.
        public static let anytime = Interval(rawValue: Interval.min ... Interval.max)!
        
        public let rawValue: ClosedRange<UInt16>
        
        public init?(rawValue: ClosedRange<UInt16>) {
            
            guard rawValue.upperBound <= Interval.max
                else { return nil }
            
            self.rawValue = rawValue
        }
    }
}

// MARK: - Schedule Weekdays

public extension Permission.Schedule {
    
    public struct Weekdays: DataConvertible, Equatable {
        
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
            
            guard data.count == Weekdays.length
                else { return nil }
            
            guard let sunday = BluetoothBool(rawValue: data.bytes[0])?.boolValue,
                let monday = BluetoothBool(rawValue: data.bytes[1])?.boolValue,
                let tuesday = BluetoothBool(rawValue: data.bytes[2])?.boolValue,
                let wednesday = BluetoothBool(rawValue: data.bytes[3])?.boolValue,
                let thursday = BluetoothBool(rawValue: data.bytes[4])?.boolValue,
                let friday = BluetoothBool(rawValue: data.bytes[5])?.boolValue,
                let saturday = BluetoothBool(rawValue: data.bytes[6])?.boolValue
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
            
            return Data(bytes: bytes)
        }
    }
}

public func == (lhs: Permission.Schedule.Weekdays, rhs: Permission.Schedule.Weekdays) -> Bool {
    
    return lhs.sunday == rhs.sunday
        && lhs.monday == rhs.monday
        && lhs.tuesday == rhs.tuesday
        && lhs.wednesday == rhs.wednesday
        && lhs.thursday == rhs.thursday
        && lhs.friday == rhs.friday
        && lhs.saturday == rhs.saturday
}
