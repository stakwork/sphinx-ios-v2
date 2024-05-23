//
//  APIGroupsExtension.swift
//  sphinx
//
//  Created by Tomas Timinskas on 15/01/2020.
//  Copyright © 2020 Sphinx. All rights reserved.
//

import Foundation
import SwiftyJSON
import Alamofire

extension API {            
    func getTribesList(
        callback: @escaping GetAllTribesCallback,
        errorCallback: @escaping EmptyCallback,
        limit : Int = 20,
        searchTerm:String? = nil,
        page : Int = 0,
        tags : [String] = []
    ) {
        var url = API.getUrl(route: "\(API.kTribesServer)/tribes?limit=\(limit)&sortBy=member_count&page=\(page)")
        if tags.isEmpty == false {
            url.append("&tags=")
            for tag in tags {
                url.append("\(tag),")
            }
            url.remove(at: url.index(url.endIndex, offsetBy: -1))
        }
        
        url += (searchTerm == nil) ? "" : "&search=\(searchTerm!)"
        
        guard let request = createRequest(url.percentEscaped ?? url, bodyParams: nil, method: "GET") else {
            errorCallback()
            return
        }
        
        AF.request(request).responseJSON { response in
            switch response.result {
            case .success(let data):
                callback(data as? [NSDictionary] ?? [])
            case .failure(let error):
                errorCallback()
            }
        }
    }
    
    func getTribeInfo(
        host: String,
        uuid: String,
        useSSL:Bool=true,
        callback: @escaping CreateGroupCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        var url = API.getUrl(route: "https://\(host)/tribes/\(uuid)")
        url = useSSL ? (url) : (url.replacingOccurrences(of: "https", with: "http"))
        let tribeRequest : URLRequest? = createRequest(url, bodyParams: nil, method: "GET")
        
        guard let request = tribeRequest else {
            errorCallback()
            return
        }
        
        //NEEDS TO BE CHANGED
        sphinxRequest(request) { response in
            switch response.result {
            case .success(let data):
                if let json = data as? NSDictionary {
                    callback(JSON(json))
                } else {
                    errorCallback()
                }
            case .failure(let error):
                print(error)
                errorCallback()
            }
        }
    }
    
    func requestAction(
        messageId: Int,
        contactId: Int,
        action: String,
        callback: @escaping CreateGroupCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        guard let request = getURLRequest(route: "/member/\(contactId)/\(action)/\(messageId)", params: nil, method: "PUT") else {
            errorCallback()
            return
        }
        
        sphinxRequest(request) { response in
            switch response.result {
            case .success(let data):
                if let json = data as? NSDictionary {
                    if let success = json["success"] as? Bool, let response = json["response"] as? NSDictionary, success {
                        callback(JSON(response))
                        return
                    }
                }
                errorCallback()
            case .failure(_):
                errorCallback()
            }
        }
    }
    
    func addTribeMember(
        params: [String: AnyObject],
        callback: @escaping CreateGroupCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        
        guard let request = getURLRequest(route: "/tribe_member", params: params as NSDictionary?, method: "POST") else {
            errorCallback()
            return
        }
        
        sphinxRequest(request) { response in
            switch response.result {
            case .success(let data):
                if let json = data as? NSDictionary {
                    if let success = json["success"] as? Bool, let response = json["response"] as? NSDictionary, success {
                        callback(JSON(response))
                        return
                    }
                }
                errorCallback()
            case .failure(_):
                errorCallback()
            }
        }
    }
    
}
