//
//  Chapter+Computed.swift
//  sphinx
//
//  Created by Tomas Timinskas on 11/03/2025.
//  Copyright © 2025 sphinx. All rights reserved.
//

import Foundation
import CoreData

public class Chapter {
    
    public var dateAddedToGraph: Date
    public var nodeType: String
    public var isAd: Bool
    public var name: String
    public var sourceLink: String
    public var timestamp: String
    public var referenceId: String
    
    
    init(dateAddedToGraph: Date, nodeType: String, isAd: Bool, name: String, sourceLink: String, timestamp: String, referenceId: String) {
        self.dateAddedToGraph = dateAddedToGraph
        self.nodeType = nodeType
        self.isAd = isAd
        self.name = name
        self.sourceLink = sourceLink
        self.timestamp = timestamp
        self.referenceId = referenceId
    }    
}
