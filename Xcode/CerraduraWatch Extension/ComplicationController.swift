//
//  ComplicationController.swift
//  CerraduraWatch WatchKit Extension
//
//  Created by Alsey Coleman Miller on 5/1/16.
//  Copyright © 2016 ColemanCDA. All rights reserved.
//

import ClockKit

final class ComplicationController: NSObject, CLKComplicationDataSource {
    
    override init() {
        super.init()
        
        print("Initialized \(self.dynamicType)")
    }
    
    let blueTintColor = UIColor(red: CGFloat(0.278), green: CGFloat(0.506), blue: CGFloat(0.976), alpha: CGFloat(1.000))
    
    // MARK: - Timeline Configuration
    
    @objc(getSupportedTimeTravelDirectionsForComplication:withHandler:)
    func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler handler: (CLKComplicationTimeTravelDirections) -> ()) {
        
        handler([.backward])
    }
    
     @objc(getTimelineStartDateForComplication:withHandler:)
    func getTimelineStartDate(for complication: CLKComplication, withHandler handler: (NSDate?) -> ()) {
        
        let date = History.shared.events.first?.date ?? NSDate()
        
        print("Complication timeline start date: \(date)")
        
        handler(date)
    }
    
    @objc(getTimelineEndDateForComplication:withHandler:)
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: (NSDate?) -> ()) {
        
        let date = History.shared.events.last?.date ?? NSDate()
        
        print("Complication timeline end date: \(date)")
        
        handler(date)
    }
    
    @objc(getPrivacyBehaviorForComplication:withHandler:)
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: (CLKComplicationPrivacyBehavior) -> ()) {
        
        handler(.showOnLockScreen)
    }
    
    // MARK: - Timeline Population
    
    @objc(getCurrentTimelineEntryForComplication:withHandler:)
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: (CLKComplicationTimelineEntry?) -> ()) {
        // Call the handler with the current timeline entry
        
        print("Complication current timeline entry")
        
        let event = History.shared.events.last?.event ?? .foundLock(nil)
        
        let template = self.template(for: complication, event: event)
        
        handler(CLKComplicationTimelineEntry(date: NSDate(), complicationTemplate: template))
    }
    
    /*
    @objc(getTimelineEntriesForComplication:beforeDate:limit:withHandler:)
    func getTimelineEntries(for complication: CLKComplication, before date: NSDate, limit: Int, withHandler handler: (([CLKComplicationTimelineEntry]?) -> ())) {
        
        print("Complication Timeline before \(date)")
        
        var events = History.shared.events.reversed().filter { $0.date.earlierDate(date) == $0.date }
        
        events = Array(events.prefix(limit))
        
        let entries = events.map { CLKComplicationTimelineEntry(date: $0.date, complicationTemplate: self.template(for: complication, event: $0.event)) }
        
        handler(entries)
    }*/
    
    // MARK: - Update Scheduling
    
    /*
    @objc(getNextRequestedUpdateDateWithHandler:)
    func getNextRequestedUpdateDate(handler: (NSDate?) -> ()) {
        // Call the handler with the date when you would next like to be given the opportunity to update your complication content
        /*
        let futureDate = NSDate().addingTimeInterval(60*30)
        
        handler(futureDate);
        
        print("Next date complication will be updated: \(futureDate)")
        */
        handler(nil)
    }*/
    
    // MARK: - Placeholder Templates
    
    @objc(getPlaceholderTemplateForComplication:withHandler:)
    func getPlaceholderTemplate(for complication: CLKComplication, withHandler handler: (CLKComplicationTemplate?) -> ()) {
        // This method will be called once per supported complication, and the results will be cached
        
        print("Providing placeholder template for complication")
        
        let template = self.template(for: complication, event: .foundLock(.admin))
        
        handler(template)
    }
    
    // MARK: - Private Methods
    
    private func template(for complication: CLKComplication, event: Event) -> CLKComplicationTemplate {
        
        switch complication.family {
            
        case .modularSmall:
            
            let imageName: String
                
            switch event {
                
            case let .foundLock(permission):
                
                if let permission = permission {
                    
                    switch permission {
                    case .owner: imageName = "modularSmallOwner"
                    case .admin: imageName = "modularSmallAdmin"
                    case .anytime: imageName = "modularSmallAnytime"
                    case .scheduled: imageName = "modularSmallScheduled"
                    }
                    
                } else {
                    
                    imageName = "modularSmallScan"
                }
                
            case let .unlock(permission):
                
                switch permission {
                case .owner: imageName = "modularSmallOwner"
                case .admin: imageName = "modularSmallAdmin"
                case .anytime: imageName = "modularSmallAnytime"
                case .scheduled: imageName = "modularSmallScheduled"
                }
            }
            
            let image = UIImage(named: imageName)!
            
            let complicationTemplate = CLKComplicationTemplateModularSmallSimpleImage()
            
            let imageProvider = CLKImageProvider(onePieceImage: image)
            
            imageProvider.tintColor = blueTintColor
            
            complicationTemplate.imageProvider = imageProvider
            
            return complicationTemplate
            
        default: fatalError("Complication family \(complication.family.rawValue) not supported")
        }
    }
}
