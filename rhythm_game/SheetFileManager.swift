import Foundation
import UIKit

public struct SheetFileManager {
    public static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    public static func urlForFile(named filename: String) -> URL {
        var name = filename
        if !name.hasSuffix(".json") { name += ".json" }
        return documentsURL.appendingPathComponent(name)
    }

    // save JSON (Sheet) to Documents/<filename>.json
    public static func save(sheet: Sheet, filename: String) throws {
        let url = urlForFile(named: filename)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(sheet)
        try data.write(to: url, options: .atomic)
        NotificationCenter.default.post(name: .sheetSaved, object: nil, userInfo: ["filename": url.lastPathComponent])
    }

    public static func load(filename: String) throws -> Sheet {
        let url = urlForFile(named: filename)
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(Sheet.self, from: data)
    }

    public static func listSavedFiles() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]))?
            .filter { $0.pathExtension.lowercased() == "json" } ?? []
    }

    public static func loadAllSavedSheets() -> [(filename: String, sheet: Sheet)] {
        let urls = listSavedFiles()
        var result: [(String, Sheet)] = []
        for url in urls {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let s = try decoder.decode(Sheet.self, from: data)
                result.append((url.lastPathComponent, s))
            } catch {
                print("Failed to load sheet at \(url): \(error)")
            }
        }
        return result
    }

    // Export helper: prepare URLs (JSON + optional audio) for sharing via UIActivityViewController.
    // - sheetFilename: base name (without .json) that was used for save
    // - audioSourceURL: optional URL to an audio file (e.g. imported from picker); if nil and sheet.audioFilename exists, we will try to use Documents/<audioFilename>
    public static func prepareExportURLs(sheetFilename: String, audioSourceURL: URL? = nil) throws -> [URL] {
        var urls: [URL] = []
        let jsonURL = urlForFile(named: sheetFilename)
        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            throw NSError(domain: "SheetFileManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sheet JSON not found: \(jsonURL.path)"])
        }
        urls.append(jsonURL)

        // try audio
        if let audioSrc = audioSourceURL {
            // if audioSource is outside documents, copy into Documents with its filename and include
            let dest = documentsURL.appendingPathComponent(audioSrc.lastPathComponent)
            if audioSrc.path != dest.path {
                // overwrite if exists
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: audioSrc, to: dest)
            }
            urls.append(dest)
        } else {
            // try to read audio filename from JSON
            do {
                let data = try Data(contentsOf: jsonURL)
                let decoder = JSONDecoder()
                if let s = try? decoder.decode(Sheet.self, from: data), let audioName = s.audioFilename {
                    let audioURL = documentsURL.appendingPathComponent(audioName)
                    if FileManager.default.fileExists(atPath: audioURL.path) {
                        urls.append(audioURL)
                    } else {
                        // no audio found — it's OK, export will just include JSON
                        print("Audio referenced but not found at: \(audioURL.path)")
                    }
                }
            } catch {
                print("prepareExportURLs: can't decode JSON: \(error)")
            }
        }

        return urls
    }
}

public extension Notification.Name {
    static let sheetSaved = Notification.Name("SheetSavedNotification")
}
