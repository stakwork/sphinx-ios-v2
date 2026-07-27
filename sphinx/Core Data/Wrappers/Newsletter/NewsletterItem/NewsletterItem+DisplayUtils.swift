//
//  NewsletterItem+DisplayUtils.swift
//  sphinx
//
//  Created by Tomas Timinskas on 27/10/2021.
//  Copyright © 2021 sphinx. All rights reserved.
//

import Foundation

extension NewsletterItem {
    
    var titleForDisplay: String { title ?? "Untitled" }
    
    @MainActor 
    var publishDateText: String {
        guard let datePublished = datePublished else {
            return "Unknown Publish Date"
        }
        
        let calendar = Calendar.autoupdatingCurrent
        
        let dateComponents = calendar.dateComponents(
            [
                .year,
                .month,
                .day,
                .hour,
                .minute,
                .second,
            ],
            from: Date(),
            to: datePublished
        )
        

        return Self.dateFormatter.localizedString(
            from: dateComponents
        )
    }
    
    @MainActor
    var updateDateText: String {
        guard let dateUpdated = dateUpdated else {
            return "Unknown Update Date"
        }
        
        let calendar = Calendar.autoupdatingCurrent
        
        let dateComponents = calendar.dateComponents(
            [
                .year,
                .month,
                .day,
                .hour,
                .minute,
                .second,
            ],
            from: Date(),
            to: dateUpdated
        )
        

        return Self.dateFormatter.localizedString(
            from: dateComponents
        )
    }
}
