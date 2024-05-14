//
//  APIUsersExtension.swift
//  sphinx
//
//  Created by Tomas Timinskas on 21/11/2019.
//  Copyright © 2019 Sphinx. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

extension API {
    
    public func uploadImage(userId: Int? = nil, chatId: Int? = nil, image: UIImage, progressCallback: @escaping UploadProgressCallback, callback: @escaping UploadCallback) {
        guard let imgData = image.jpegData(compressionQuality: 0.5) else {
            callback(false, nil)
            return
        }
        
        let method = HTTPMethod(rawValue: "POST")
        let ip = UserData.sharedInstance.getNodeIP()
        let url = API.getUrl(route: "\(ip)/upload")
        var parameters: [String: String] = [:]
        
        if let userId = userId {
            parameters["contact_id"] = "\(userId)"
        } else if let chatId = chatId {
            parameters["chat_id"] = "\(chatId)"
        }
        
        var httpHeaders = HTTPHeaders()
        let headers = UserData.sharedInstance.getAuthenticationHeader()
        
        for (key, value) in headers {
            httpHeaders.add(name: key, value: value)
        }
        
        AF.upload(multipartFormData: { multipartFormData in
            for (key, value) in parameters {
                multipartFormData.append(value.data(using: String.Encoding.utf8)!, withName: key)
            }
            multipartFormData.append(imgData, withName: "file", fileName: "file.jpg", mimeType: "image/jpg")
        }, to: url, method: method, headers: httpHeaders).uploadProgress(queue: .main, closure: { progress in
            let progressInt = Int(round(progress.fractionCompleted * 100))
            progressCallback(progressInt)
        }).responseJSON { (response) in
            switch response.result {
            case .success(let data):
                if let json = data as? NSDictionary {
                    if let success = json["success"] as? Bool, let fileURL = json["photo_url"] as? String, success {
                        callback(true, fileURL)
                        return
                    }
                }
                callback(false, nil)
            case .failure(_):
                callback(false, nil)
            }
        }
    }
}
