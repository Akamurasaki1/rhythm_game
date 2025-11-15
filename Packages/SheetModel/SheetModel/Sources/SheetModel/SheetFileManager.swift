//
//  SheetFileManager.swift
//  SheetModel
//
//  Created by Karen Naito on 2025/11/15.
//

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
}

public extension Notification.Name {
    static let sheetSaved = Notification.Name("SheetSavedNotification")
}
