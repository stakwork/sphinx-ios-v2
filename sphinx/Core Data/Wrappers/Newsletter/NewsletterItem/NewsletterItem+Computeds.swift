//
//  NewsletterItem+Computeds.swift
//  sphinx
//
//  Created by Tomas Timinskas on 27/10/2021.
//  Copyright © 2021 sphinx. All rights reserved.
//

import Foundation

extension NewsletterItem {
    
    @MainActor static let dateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        
        return formatter
    }()
    
    func saveAsCurrentArticle() {
        newsletterFeed?.currentArticleID = itemID
    }
}
