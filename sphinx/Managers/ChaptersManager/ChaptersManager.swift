//
//  ChaptersManager.swift
//  sphinx
//
//  Created by Tomas Timinskas on 26/03/2025.
//  Copyright © 2025 sphinx. All rights reserved.
//


import Foundation

class ChaptersManager : NSObject {
    
    class var sharedInstance : ChaptersManager {
        struct Static {
            static let instance = ChaptersManager()
        }
        return Static.instance
    }
    
    func processChaptersData(
        episode: PodcastEpisode,
        completion: @escaping (Bool, [Chapter]) -> ()
    ) {
        guard let contentFeedItem = ContentFeedItem.getItemWith(itemID: episode.itemID) else {
            completion(false, [])
            return
        }
        if let refereceId = episode.referenceId {
            ///ReferenceID stored in Episode. It was processed before. Try to fetch chapters data
            self.getAndStoreChaptersData(
                referenceId: refereceId,
                episode: episode,
                completion: completion
            )
        } else if let mediaUrl = episode.urlPath {
            ///ReferenceID not stored in Episode. Start process with checking if node exists
            checkIfNodeExists(mediaUrl: mediaUrl) { (nodeExists, refId) in
                if let refId = refId {
                    if nodeExists {
                        ///Node exists, save referenceId and try to fetch chapters data
                        contentFeedItem.referenceId = refId
                        contentFeedItem.managedObjectContext?.saveContext()
                        
                        self.getAndStoreChaptersData(
                            referenceId: refId,
                            episode: episode,
                            completion: completion
                        )
                    } else {
                        ///Node doesn't exist, but it was created. Run GraphMinset workflow to extract chapters
                        self.runGraphMindset(
                            referenceId: refId,
                            episode: episode,
                            completion: { success in
                                if success {
                                    contentFeedItem.referenceId = refId
                                    contentFeedItem.managedObjectContext?.saveContext()
                                    completion(true, [])
                                } else {
                                    completion(false, [])
                                }
                            }
                        )
                    }
                } else {
                    completion(false, [])
                }
            }
        }
    }
    
    func getAndStoreChaptersData(
        referenceId: String,
        episode: PodcastEpisode,
        completion: @escaping (Bool, [Chapter]) -> ()
    ) {
        guard let contentFeedItem = ContentFeedItem.getItemWith(itemID: episode.itemID) else {
            completion(false, [])
            return
        }
        
        self.getChaptersData(referenceId: referenceId, completion: { (success, jsonString) in
            if success, let jsonString = jsonString {
                ///Chapters data available. Store in episode and return them
                contentFeedItem.chaptersData = jsonString
                episode.chapters = PodcastEpisode.getChaptersFrom(json: jsonString)
                completion(true, episode.chapters ?? [])
            } else {
                ///Chapters data unavailable. Check episode status
                self.checkEpisodeStatus(referenceId: referenceId, completion: { (success, nodeStatusResponse) in
                    if success, let nodeStatusResponse = nodeStatusResponse {
                        if nodeStatusResponse.processing {
                            if let projectId = nodeStatusResponse.projectId {
                                ///Node workflow already running. Just wait
                                completion(true, [])
                            } else {
                                ///Node created but workflow not running. Run GraphMinset workflow to extract chapters
                                self.runGraphMindset(
                                    referenceId: referenceId,
                                    episode: episode,
                                    completion: { success in
                                        completion(true, [])
                                    }
                                )
                            }
                        } else if nodeStatusResponse.completed {
                            ///Node created and workflow run. Try to fetch chapters data again
                            self.getChaptersData(referenceId: referenceId, completion: { (success, jsonString) in
                                if success, let jsonString = jsonString {
                                    contentFeedItem.chaptersData = jsonString
                                    episode.chapters = PodcastEpisode.getChaptersFrom(json: jsonString)
                                    completion(true, episode.chapters ?? [])
                                }
                            })
                        } else {
                            completion(false, [])
                        }
                    }
                })
            }
        })
    }
    
    func checkIfNodeExists(
        mediaUrl: String,
        completion: @escaping (Bool, String?) -> ()
    ) {
        API.sharedInstance.checkEpisodeNodeExists(
            mediaUrl: mediaUrl,
            callback: { checkNodeResponse in
                let refId = checkNodeResponse.refId
                
                if checkNodeResponse.success {
                    //Episode was created. Call graphmindset run
                    completion(false, refId)
                } else {
                    //Episode already exists. Try getting chapters
                    completion(true, refId)
                }
            },
            errorCallback: { _ in
                completion(false, nil)
            }
        )
    }
    
    func getChaptersData(
        referenceId: String,
        completion: @escaping (Bool, String?) -> ()
    ) {
        API.sharedInstance.getEpisodeNodeChapters(
            refId: referenceId,
            callback: { chaptersJsonString in
                completion(true, chaptersJsonString)
            },
            errorCallback: { error in
                completion(false, nil)
            }
        )
    }
    
    func runGraphMindset(
        referenceId: String,
        episode: PodcastEpisode,
        completion: @escaping (Bool) -> ()
    ) {
        if
            let mediaUrl = episode.urlPath,
            let date = episode.publishDate,
            let episodeTitle = episode.title
        {
            API.sharedInstance.ceateGrandMindsetRun(
                mediaUrl: mediaUrl,
                refId: referenceId,
                publishDate: Int(date.timeIntervalSince1970),
                title: episodeTitle,
                thumbnailUrl: episode.imageToShow,
                showTitle: episode.showTitle ?? "Show Title",
                callback: { createRunResponse in
                    completion(createRunResponse.success)
                },
                errorCallback: { _ in
                    completion(false)
                }
            )
        }
    }
    
    func checkEpisodeStatus(
        referenceId: String,
        completion: @escaping (Bool, API.NodeStatusResponse?) -> ()
    ) {
        API.sharedInstance.checkEpisodeNodeStatus(
            refId: referenceId,
            callback: { nodeStatusResponse in
                completion(true, nodeStatusResponse)
            },
            errorCallback: { _ in
                completion(false, nil)
            }
        )
    }
}
