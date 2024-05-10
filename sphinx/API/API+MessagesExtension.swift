//
//  APIMessagesExtension.swift
//  sphinx
//
//  Created by Tomas Timinskas on 21/11/2019.
//  Copyright © 2019 Sphinx. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

extension API {
    
    func sendMessage(
        params: [String: AnyObject],
        callback:@escaping MessageObjectCallback,
        errorCallback:@escaping EmptyCallback
    ) {
        
        guard let request = getURLRequest(route: "/messages", params: params as NSDictionary?, method: "POST") else {
            errorCallback()
            return
        }

        sphinxRequest(request) { response in
            switch response.result {
            case .success(let data):
                if let json = data as? NSDictionary {
                    if let response = json["response"] as? NSDictionary {
                        callback(JSON(response))
                    } else {
                        errorCallback()
                    }
                }
            case .failure(_):
                errorCallback()
            }
        }
    }


}
