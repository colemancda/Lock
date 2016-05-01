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
    func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler handler: CLKComplicationTimeTravelDirections -> ()) {
        
        handler([])
    }
    
     @objc(getTimelineStartDateForComplication:withHandler:)
    func getTimelineStartDate(for complication: CLKComplication, withHandler handler: (NSDate?) -> ()) {
        handler(nil)
    }
    
    @objc(getTimelineEndDateForComplication:withHandler:)
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: (NSDate?) -> ()) {
        handler(nil)
    }
    
    @objc(getPrivacyBehaviorForComplication:withHandler:)
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: (CLKComplicationPrivacyBehavior) -> ()) {
        
        handler(.showOnLockScreen)
    }
    
    // MARK: - Timeline Population
    
    @objc(getCurrentTimelineEntryForComplication:withHandler:)
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: CLKComplicationTimelineEntry? -> ()) {
        // Call the handler with the current timeline entry
        
        print("Updating current timeline entry for complication")
        
        switch complication.family {
            
        case .modularSmall:
            
            let image = UIImage(named: "modularSmallAdmin")!
            
            let complicationTemplate = CLKComplicationTemplateModularSmallSimpleImage()
            
            let imageProvider = CLKImageProvider(onePieceImage: image)
            
            imageProvider.tintColor = blueTintColor
            
            complicationTemplate.imageProvider = imageProvider
            
            handler(CLKComplicationTimelineEntry(date: NSDate(), complicationTemplate: complicationTemplate))
            
        default: fatalError("Complication family \(complication.family.rawValue) not supported")
        }
        
        handler(nil)
    }
    
    @objc(getTimelineEntriesForComplication:beforeDate:limit:withHandler:)
    func getTimelineEntries(for complication: CLKComplication, before date: NSDate, limit: Int, withHandler handler: (([CLKComplicationTimelineEntry]?) -> ())) {
        // Call the handler with the timeline entries prior to the given date
        handler(nil)
    }
    
    @objc(getTimelineEntriesForComplication:afterDate:limit:withHandler:)
    func getTimelineEntries(for complication: CLKComplication, after date: NSDate, limit: Int, withHandler handler: (([CLKComplicationTimelineEntry]?) -> ())) {
        // Call the handler with the timeline entries after to the given date
        handler(nil)
    }
    
    // MARK: - Update Scheduling
    
    @objc(getNextRequestedUpdateDateWithHandler:)
    func getNextRequestedUpdateDate(handler: (NSDate?) -> Void) {
        // Call the handler with the date when you would next like to be given the opportunity to update your complication content
        
        let futureDate = NSDate().addingTimeInterval(60*30)
        
        handler(futureDate);
        
        print("Next date complication will be updated: \(futureDate)")
    }
    
    // MARK: - Placeholder Templates
    
    @objc(getPlaceholderTemplateForComplication:withHandler:)
    func getPlaceholderTemplate(for complication: CLKComplication, withHandler handler: (CLKComplicationTemplate?) -> ()) {
        // This method will be called once per supported complication, and the results will be cached
        
        print("Providing placeholder template for complication")
        
        switch complication.family {
            
        case .modularSmall:
            
            let image = UIImage(named: "modularSmallAdmin")!
            
            let complicationTemplate = CLKComplicationTemplateModularSmallSimpleImage()
            
            let imageProvider = CLKImageProvider(onePieceImage: image)
            
            imageProvider.tintColor = blueTintColor
            
            complicationTemplate.imageProvider = imageProvider
            
            handler(complicationTemplate)
            
        default: fatalError("Complication family \(complication.family.rawValue) not supported")
        }
    }
    
}
