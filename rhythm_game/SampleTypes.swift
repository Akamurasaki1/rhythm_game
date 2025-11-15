//
//  SampleTypes.swift
//  rhythm_game
//
//  Created by Karen Naito on 2025/11/15.
//
//
//  SampleTypes.swift
//  rhythm_game
//
//  Created by Karen Naito on 2025/11/15.
//

// Add to rhythm_game target
import Foundation
import CoreGraphics
import SheetModel

// SheetNote 型 は既にプロジェクトにある前提（time, angleDegrees, normalizedPosition: CGPoint）
// SampleEntry は UI 用のエントリ。必要ならフィールドを拡張してください。
public struct SampleEntry {
    public var name: String
    public var notes: [SheetNote]
    /// オリジン情報（バンドル内なら bundledFilename に値を入れる）
    public var bundledFilename: String?      // 例: "115もぺもぺ2019.json"
    public var sheetObject: Sheet?           // if available, keep the decoded Sheet for metadata/audioFilename

    public init(name: String, notes: [SheetNote], bundledFilename: String? = nil, sheetObject: Sheet? = nil) {
        self.name = name
        self.notes = notes
        self.bundledFilename = bundledFilename
        self.sheetObject = sheetObject
    }
}

// Helper typed wrapper for bundled sheet discovery (avoid unlabeled tuple issues)
public struct BundledSheet {
    public var filename: String
    public var sheet: Sheet
    public init(filename: String, sheet: Sheet) {
        self.filename = filename
        self.sheet = sheet
    }
}
