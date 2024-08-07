//
//  EpubConverterManager.swift
//  sphinx
//
//  Created by James Carucci on 8/7/24.
//  Copyright © 2024 sphinx. All rights reserved.
//

import Foundation
import Alamofire
import ObjectMapper

class EpubConverterManager {
    private let baseURL = "https://epub-converter-proto-ludy4.ondigitalocean.app"
    
    func convertEpub(url: String) async throws -> URL {
        let convertedPdfUrl = try await initiateConversion(epubUrl: url)
        return convertedPdfUrl//try await downloadAndSavePdf(from: convertedPdfUrl)
    }
    
    private func initiateConversion(epubUrl: String) async throws -> URL {
        let endpoint = "\(baseURL)/convert-url"
        let parameters: [String: Any] = ["url": epubUrl]
        
        let response: ConversionResponse = try await AF.request(endpoint,
                                                               method: .post,
                                                               parameters: parameters,
                                                               encoding: JSONEncoding.default)
            .validate()
            .serializingDecodable(ConversionResponse.self)
            .value
        
        guard let pdfUrl = URL(string: response.pdfUrl) else {
            throw ConversionError.invalidPdfUrl
        }
        
        return pdfUrl
    }
    
    private func downloadAndSavePdf(from url: URL) async throws -> URL {
        let destination: DownloadRequest.Destination = { _, _ in
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsURL.appendingPathComponent(url.lastPathComponent)
            return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        
        let downloadResponse = try await AF.download(url, to: destination).serializingDownloadedFileURL().value
        
        return downloadResponse
    }
    
    func findEpubInDirectory(directoryPath: String) async throws -> URL? {
        var path = directoryPath
        
        // Check if the directoryPath already includes the base URL
        if path.lowercased().hasPrefix(API.sharedInstance.btBaseUrl.lowercased()) {
            path = String(path.dropFirst(API.sharedInstance.btBaseUrl.count))
        }
        
        // First, encode the path
        guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw ConversionError.invalidUrl
        }
        
        // Construct the full URL string
        let urlString = "\(API.sharedInstance.btBaseUrl)\(encodedPath)?json"
        
        // Create URL from the encoded string
        guard let url = URL(string: urlString) else {
            throw ConversionError.invalidUrl
        }
        
        print("Requesting URL: \(url.absoluteString)") // Debug print
        
        let response: BTMediaResponse = try await withCheckedThrowingContinuation { continuation in
            AF.request(url).validate().responseString { response in
                switch response.result {
                case .success(let jsonString):
                    if let directoryResponse = Mapper<BTMediaResponse>().map(JSONString: jsonString) {
                        continuation.resume(returning: directoryResponse)
                    } else {
                        continuation.resume(throwing: ConversionError.invalidResponse)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
        
        if let epubFile = response.paths?.first(where: { ($0.name ?? "").lowercased().hasSuffix(".epub") }) {
            let epubPath = path + "/" + (epubFile.name ?? "")
            guard let encodedEpubPath = epubPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
                throw ConversionError.invalidUrl
            }
            return URL(string: "\(API.sharedInstance.btBaseUrl)\(encodedEpubPath)")
        }
        
        return nil
    }
}

extension EpubConverterManager {
    enum ConversionError: Error {
        case serverError
        case invalidPdfUrl
        case downloadError
        case invalidUrl
        case invalidResponse
    }
    
    struct ConversionResponse: Codable {
        let pdfUrl: String
    }
}
