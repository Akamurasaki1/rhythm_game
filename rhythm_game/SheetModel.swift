import Foundation
import SwiftUI
import CoreGraphics

/// Documents 等のファイル管理で使う簡易ユーティリティ
enum SheetFileManager {
    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}

/// 正規化された座標（0.0..1.0 の想定）
struct NormalizedPosition: Codable, Equatable {
    var x: Double
    var y: Double
}

/// Sheet 内で定義されるノーツの形式（JSON 側の正しい形）
struct SheetNote: Codable, Equatable {
    var time: Double
    var angleDegrees: Double
    var normalizedPosition: NormalizedPosition

    // 将来他フィールドがあれば、ここに追加（例: type, id, meta 等）
}

/// Bundle / file から読み込む Sheet の定義
struct Sheet: Codable, Equatable {
    var title: String
    var notes: [SheetNote]
    var audioFilename: String?
    var offset: Double?

    // JSON の互換性を保つために CodingKeys を定義しておく（必要なら名前マッピング）
    enum CodingKeys: String, CodingKey {
        case title
        case notes
        case audioFilename
        case offset
    }
}

/// アプリ内で再生に使うノーツ表現
/// ContentView の既存コードは Note.time / Note.angleDegrees / Note.normalizedPosition(CGPoint) を想定しているため合わせる
struct Note: Equatable {
    var time: Double
    var angleDegrees: Double
    var normalizedPosition: CGPoint
}

extension Note {
    /// SheetNote から Note へ安全に変換するイニシャライザ
    init(from sheetNote: SheetNote) {
        self.time = sheetNote.time
        self.angleDegrees = sheetNote.angleDegrees
        self.normalizedPosition = CGPoint(x: sheetNote.normalizedPosition.x, y: sheetNote.normalizedPosition.y)
    }
}

/// Helper: SheetNote 配列を Note 配列に変換
extension Array where Element == SheetNote {
    func asNotes() -> [Note] {
        self.map { Note(from: $0) }
    }
}

/// CGPoint を Codable として扱うためのエンコード/デコード実装（Note を直接 Codable にしない設計にしたので補助的）
extension CGPoint: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let x = try c.decode(CGFloat.self, forKey: .x)
        let y = try c.decode(CGFloat.self, forKey: .y)
        self.init(x: x, y: y)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(self.x, forKey: .x)
        try c.encode(self.y, forKey: .y)
    }

    enum CodingKeys: String, CodingKey {
        case x, y
    }
}
