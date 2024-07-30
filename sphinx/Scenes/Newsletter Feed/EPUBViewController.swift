import UIKit
import WebKit
import EPUBKit
import Zip

class EPUBViewController: UIViewController {
    var webView: WKWebView!
    var book: EPUBDocument?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        webView = WKWebView(frame: self.view.bounds)
        self.view.addSubview(webView)
        
        let remoteURL = URL(string: "https://files.bt2.bard.garden:21433/The%20Tragedy%20of%20Great%20Power%20Politics%20by%20John%20J%20Mearsheimer%20ePUB%20eBOOK-ZAK/Tragedy%20of%20great%20power%20politics%2C%20The%20-%20John%20J.%20Mearsheimer.epub")!
        downloadEPUB(from: remoteURL) { localURL in
            guard let localURL = localURL else {
                print("Failed to download EPUB.")
                return
            }
            self.openEPUB(at: localURL)
        }
    }
    
    private func downloadEPUB(from url: URL, completion: @escaping (URL?) -> Void) {
        let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            if let error = error {
                print("Download error: \(error)")
                completion(nil)
                return
            }
            guard let localURL = localURL else {
                print("Download failed: No local URL.")
                completion(nil)
                return
            }
            print("Downloaded file URL: \(localURL)")
            completion(localURL)
        }
        task.resume()
    }
    
    private func openEPUB(at url: URL) {
        do {
//            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
//            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
//            print("Temporary directory created at: \(tempDir.path)")
//            
//            let epubFile = tempDir.appendingPathComponent("book.epub")
//            try FileManager.default.copyItem(at: url, to: epubFile)
//            print("EPUB file copied to: \(epubFile.path)")
//            
//            let unzippedDir = tempDir.appendingPathComponent("unzipped")
//            try FileManager.default.createDirectory(at: unzippedDir, withIntermediateDirectories: true, attributes: nil)
//            print("Unzipped directory created at: \(unzippedDir.path)")
//            
//            try Zip.unzipFile(epubFile, destination: unzippedDir, overwrite: true, password: nil)
//            print("Unzipped EPUB contents to: \(unzippedDir.path)")
            
            let document = try EPUBDocument(url: url)
            self.book = document
            if let document = document,
               let firstSpineItem = document.spine.items.first {
                if let htmlContent = try? self.contentForSpineItem(firstSpineItem, in: document) {
                    webView.loadHTMLString(htmlContent, baseURL: document.contentDirectory)
                }
            }
        } catch {
            print("Failed to open EPUB: \(error)")
        }
    }
    
    private func contentForSpineItem(_ spineItem: EPUBSpineItem, in document: EPUBDocument) throws -> String {
        guard let idref = document.manifest.items[spineItem.idref] else {
            throw NSError(domain: "EPUBViewController", code: 0, userInfo: [NSLocalizedDescriptionKey: "Spine item not found in manifest"])
        }
        
        let itemPath = document.contentDirectory.appendingPathComponent(idref.path).path
        print("Attempting to read content from path: \(itemPath)")
        let content = try String(contentsOfFile: itemPath, encoding: .utf8)
        return content
    }
}
