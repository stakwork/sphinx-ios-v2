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
        let host = SphinxOnionManager.sharedInstance.tribesServerIP
        let hostProtocol = SphinxOnionManager.sharedInstance.isProductionEnv ? "https" : "http"
        var url = API.getUrl(route: "\(hostProtocol)://\(host)/tribes?limit=\(limit)&sortBy=member_count&page=\(page)")
        
        if !tags.isEmpty {
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
        callback: @escaping CreateGroupCallback,
        errorCallback: @escaping EmptyCallback
    ) {
        let hostProtocol = SphinxOnionManager.sharedInstance.isProductionEnv ? "https" : "http"
        let finalHost = SphinxOnionManager.sharedInstance.isProductionEnv ? host : SphinxOnionManager.sharedInstance.kTestV2TribesServer
        let url = API.getUrl(route: "\(hostProtocol)://\(finalHost)/tribes/\(uuid)")
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
    
    func getTribeLeaderboard(
        tribeUUID:String,
        callback: @escaping GetTribeBadgesCallback,
        errorCallback: @escaping EmptyCallback
    ){
        let urlPath = API.tribesV1Url + "/leaderboard/\(tribeUUID)"
        
        let urlComponents = URLComponents(string: urlPath)!

        guard let urlString = urlComponents.url?.absoluteString else {
            errorCallback()
            return
        }

        guard let request = createRequest(
            urlString,
            bodyParams: nil,
            method: "GET"
        ) else {
            errorCallback()
            return
        }

        sphinxRequest(request) { response in
            switch response.result {
            case .success(let data):
                if let json = data as? [NSDictionary] {
                    //print(json)
                    callback(json)
                    return
                }
                //print(response.response?.statusCode)
                errorCallback()
            case .failure(_):
                //print(response.response?.statusCode)
                errorCallback()
            }
        }
    }
}
