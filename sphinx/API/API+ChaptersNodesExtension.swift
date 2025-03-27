//
//  API+ChaptersNodesExtension.swift
//  sphinx
//
//  Created by Tomas Timinskas on 25/03/2025.
//  Copyright © 2025 sphinx. All rights reserved.
//
import Foundation
import SwiftyJSON

extension API {
    struct CheckNodeResponse {
        var success: Bool
        var refId: String
        var nodeKey: String?
        var projectId: Int?
        
        init(
            success: Bool,
            refId: String,
            nodeKey: String? = nil,
            projectId: Int? = nil
        ) {
            self.success = success
            self.refId = refId
            self.nodeKey = nodeKey
            self.projectId = projectId
        }
    }
    
    struct NodeStatusResponse {
        var completed: Bool
        var processing: Bool
        var projectId: Int?
        
        init(
            completed: Bool,
            processing: Bool,
            projectId: Int? = nil
        ) {
            self.completed = completed
            self.processing = processing
            self.projectId = projectId
        }
    }
    
    struct CreateRunResponse {
        var success: Bool
        var projectId: Int?
        var refId: String?
        
        init(
            success: Bool,
            projectId: Int? = nil,
            refId: String? = nil
        ) {
            self.success = success
            self.projectId = projectId
            self.refId = refId
        }
    }
    
    
    func checkEpisodeNodeExists(
        mediaUrl: String,
        callback: @escaping CheckNodeCallback,
        errorCallback: @escaping ErrorCallback
    ) {
        let url = "\(API.kGraphMindsetUrl)/add_node?sig=&msg="
        
        var params = [String: AnyObject]()
        params["media_url"] = mediaUrl as AnyObject
        params["content_type"] = "audio_video" as AnyObject
        
        let request : URLRequest? = createRequest(
            url,
            bodyParams: params as NSDictionary,
            method: "POST"
        )
        
        guard let request = request else {
            errorCallback("Error creating request")
            return
        }
        
        sphinxRequest(request) { response in
            switch response.result {
            case .success(let data):
                if let dictionary = data as? NSDictionary, let dataDic = dictionary["data"] as? NSDictionary {
                    if let success = dictionary["success"] as? Bool, success {
                        if
                            let projectId = dataDic["project_id"] as? Int,
                            let refId = dataDic["ref_id"] as? String
                        {
                            callback(
                                CheckNodeResponse(
                                    success: true,
                                    refId: refId,
                                    projectId: projectId
                                )
                            )
                            return
                        }
                    } else {
                        if let nodeKey = dataDic["node_key"] as? String, let refId = dataDic["ref_id"] as? String {
                            callback(
                                CheckNodeResponse(
                                    success: false,
                                    refId: refId,
                                    nodeKey: nodeKey
                                )
                            )
                            return
                        }
                    }
                }
                errorCallback("Error getting response data")
            case .failure(let error):
                errorCallback(error.localizedDescription)
            }
        }
    }
    
    func getEpisodeNodeChapters(
        refId: String,
        
        callback: @escaping GetNodeChaptersCallback,
        errorCallback: @escaping ErrorCallback
    ) {
        let url = "\(API.kGraphMindsetUrl)/graph/subgraph?node_type=[\"Chapter\"]&depth=1&include_properties=true&start_node=\(refId)"
        
        let request : URLRequest? = createRequest(
            url,
            bodyParams: nil,
            method: "GET"
        )
        
        guard let request = request else {
            errorCallback("Error creating request")
            return
        }
        
        sphinxRequest(request) { response in
            switch response.result {
            case .success(let data):
                if let dictionary = data as? NSDictionary {
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: dictionary, options: .withoutEscapingSlashes)
                        if let jsonString = String(data: jsonData, encoding: .utf8) {
                            callback(jsonString)
                            return
                        }
                    } catch {
                        print("Error converting NSDictionary to JSON: \(error.localizedDescription)")
                    }
                }
                errorCallback("Error getting response data")
            case .failure(let error):
                errorCallback(error.localizedDescription)
            }
        }
    }
    
    func checkEpisodeNodeStatus(
        refId: String,
        callback: @escaping GetNodeStatusCallback,
        errorCallback: @escaping ErrorCallback
    ) {
        let url = "\(API.kGraphMindsetUrl)/node/\(refId)"
        
        let request : URLRequest? = createRequest(
            url,
            bodyParams: nil,
            method: "GET"
        )
        
        guard let request = request else {
            errorCallback("Error creating request")
            return
        }
        
        sphinxRequest(request) { response in
            switch response.result {
            case .success(let data):
                if let dictionary = data as? NSDictionary, let properties = dictionary["properties"] as? NSDictionary {
                    if let status = properties["status"] as? String {
                        if status == "completed" {
                            callback(
                                NodeStatusResponse(
                                    completed: true,
                                    processing: false,
                                    projectId: Int((properties["projectId"] as? String) ?? "")
                                )
                            )
                            return
                        } else if status == "processing" {
                            callback(
                                NodeStatusResponse(
                                    completed: false,
                                    processing: true,
                                    projectId: Int((properties["projectId"] as? String) ?? "")
                                )
                            )
                            return
                        }
                    }
                    callback(
                        NodeStatusResponse(
                            completed: false,
                            processing: false,
                            projectId: nil
                        )
                    )
                }
                errorCallback("Error getting response data")
            case .failure(let error):
                errorCallback(error.localizedDescription)
            }
        }
    }
    
    func ceateGrandMindsetRun(
        mediaUrl: String,
        refId: String,
        publishDate: Int,
        title: String,
        thumbnailUrl: String?,
        showTitle: String,
        callback: @escaping CreateRunCallback,
        errorCallback: @escaping ErrorCallback
    ) {
        let url = "https://api.stakwork.com/api/v1/projects"
        
        var varsParams = [String: AnyObject]()
        varsParams["media_url"] = mediaUrl as AnyObject
        varsParams["ref_id"] = refId as AnyObject
        varsParams["episode_publish_date"] = publishDate as AnyObject
        varsParams["episode_title"] = title as AnyObject
        varsParams["episode_thumbnail_url"] = thumbnailUrl as AnyObject
        varsParams["show_title"] = showTitle as AnyObject
        
        var attributesParams = [String: AnyObject]()
        attributesParams["vars"] = varsParams as AnyObject
        
        var setVarsParams = [String: AnyObject]()
        setVarsParams["attributes"] = attributesParams as AnyObject
        
        var workflowParams = [String: AnyObject]()
        workflowParams["set_var"] = setVarsParams as AnyObject
        
        var params = [String: AnyObject]()
        params["name"] = mediaUrl as AnyObject
        params["workflow_id"] = 43837 as AnyObject
        params["workflow_params"] = workflowParams as AnyObject
        
        let request : URLRequest? = createRequest(
            url,
            bodyParams: params as NSDictionary,
            method: "POST",
            token: "REPLACE_WITH_TOKEN"
        )
        
        guard let request = request else {
            errorCallback("Error creating request")
            return
        }
        
        sphinxRequest(request) { response in
            switch response.result {
            case .success(let data):
                if let dictionary = data as? NSDictionary {
                    if let data = dictionary["data"] as? NSDictionary, let success = dictionary["success"] as? Bool, success {
                        callback(
                            CreateRunResponse(
                                success: true,
                                projectId: data["project_id"] as? Int,
                                refId: refId
                            )
                        )
                        return
                    }
                }
                errorCallback("Error getting response data")
            case .failure(let error):
                errorCallback(error.localizedDescription)
            }
        }
    }
    
    func checkProjectStatus(
        projectId: String,
        callback: @escaping StatusProjectCallback,
        errorCallback: @escaping ErrorCallback
    ) {
        let url = "https://api.stakwork.com/api/v1/projects/\(projectId)/status"
        
        let request : URLRequest? = createRequest(
            url,
            bodyParams: nil,
            method: "GET",
            token: "eb193226b5f74a8b8fff70f9822a2b35​"
        )
        
        guard let request = request else {
            return
        }
        
        sphinxRequest(request) { response in
            switch response.result {
            case .success(let data):
                if let dictionary = data as? NSDictionary {
                    if let success = dictionary["success"] as? Bool , success {
                        if let data = dictionary["data"] as? NSDictionary, let status = data["status"] as? String {
                            if status == "error" {
                                errorCallback("Project error")
                                return
                            }
                            callback(true)
                            return
                        }
                    }
                    errorCallback("Error parsing response")
                }
            case .failure(let error):
                print(error)
                errorCallback(error.localizedDescription)
            }
        }
    }
}

