import Foundation
import SheetModel
import SwiftUI

// Use BundledSheet and SampleEntry from SampleTypes.swift

func loadBundledSheets() -> [BundledSheet] {
    var results: [BundledSheet] = []
    let decoder = JSONDecoder()

    // 1) Try subdirectory "bundled-sheets"
    if let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "bundled-sheets") {
        for url in urls {
            do {
                let data = try Data(contentsOf: url)
                let s = try decoder.decode(Sheet.self, from: data)
                results.append(BundledSheet(filename: url.lastPathComponent, sheet: <#Sheet#>))
            } catch {
                print("loadBundledSheets: failed to decode bundled sheet at \(url): \(error)")
            }
        }
    }

    // 2) Fallback: search bundle root for .json files
    if results.isEmpty {
        if let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) {
            for url in urls {
                do {
                    let data = try Data(contentsOf: url)
                    let s = try decoder.decode(Sheet.self, from: data)
                    if !results.contains(where: { $0.filename == url.lastPathComponent }) {
                        results.append(BundledSheet(filename: url.lastPathComponent, sheet: <#Sheet#>))
                    }
                } catch {
                    // ignore non-sheet JSON
                }
            }
        }
    }

    return results
}

func bundleURLForAudio(named audioFilename: String?) -> URL? {
    guard let audioFilename = audioFilename, !audioFilename.isEmpty else { return nil }
    let ext = (audioFilename as NSString).pathExtension
    let name = (audioFilename as NSString).deletingPathExtension

    if let url = Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? "wav" : ext, subdirectory: "bundled-audio") {
        return url
    }
    if let url = Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? "wav" : ext) {
        return url
    }
    return nil
}

func makeSampleEntries(from sampleDataSets: [[Note]]) -> [SampleEntry] {
    var entries: [SampleEntry] = []

    // built-ins
    for (i, s) in sampleDataSets.enumerated() {
        let name = "Builtin \(i + 1)"
        entries.append(SampleEntry(name: name, notes: s as! [SheetNote]))
    }

    // saved sheets (Documents)
    let saved = SheetFileManager.loadAllSavedSheets()
    for (filename, sheet) in saved {
        let displayName = sheet.title.isEmpty ? filename : "\(sheet.title) (\(filename))"
        let mapped: [Note] = sheet.notes.map {
            Note(time: $0.time, angleDegrees: $0.angle, normalizedPosition: $0.normalizedPosition)
        }
        entries.append(SampleEntry(name: displayName, notes: mapped as! [SheetNote], bundledFilename: filename, sheetObject: sheet))
    }

    // bundled sheets
    let bundled = loadBundledSheets()
    for b in bundled {
        let displayName = b.sheet.title.isEmpty ? b.filename : "\(b.sheet.title) (bundle)"
        let mapped: [Note] = b.sheet.notes.map {
            Note(time: $0.time, angleDegrees: $0.angle, normalizedPosition: <#Position#>)
        }
        entries.append(SampleEntry(name: displayName, notes: mapped as! [SheetNote], bundledFilename: b.filename, sheetObject: b.sheet))
    }

    return entries
}
