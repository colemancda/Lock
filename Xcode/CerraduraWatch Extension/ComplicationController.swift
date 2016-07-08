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
    
    func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler handler: (CLKComplicationTimeTravelDirections) -> ()) {
        
        handler([])
    }
    
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: (CLKComplicationPrivacyBehavior) -> ()) {
        
        handler(.showOnLockScreen)
    }
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: (CLKComplicationTimelineEntry?) -> ()) {
        
        print("Providing current timeline entry for complication")
        
        let template = self.template(for: complication)
        
        let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
        
        handler(entry)
    }
    
    func getPlaceholderTemplate(for complication: CLKComplication, withHandler handler: (CLKComplicationTemplate?) -> ()) {
        // This method will be called once per supported complication, and the results will be cached
        
        print("Providing placeholder template for complication")
        
        let template = self.template(for: complication)
        
        handler(template)
    }
    
    // MARK: - Private Methods
    
    private func template(for complication: CLKComplication) -> CLKComplicationTemplate {
        
        switch complication.family {
            
        case .modularSmall:
            
            let image = #imageLiteral(resourceName: "modularSmallAdmin")
            
            let complicationTemplate = CLKComplicationTemplateModularSmallSimpleImage()
            
            let imageProvider = CLKImageProvider(onePieceImage: image)
            
            imageProvider.tintColor = blueTintColor
            
            complicationTemplate.imageProvider = imageProvider
            
            return complicationTemplate
            
        default: fatalError("Complication family \(complication.family.rawValue) not supported")
        }
    }
}
