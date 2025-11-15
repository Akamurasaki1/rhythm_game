import Foundation
import CoreGraphics

public struct SheetNote: Codable, Identifiable {
    public var id: String
    public var time: Double      // 秒
    public var angle: Double     // 度
    public var x: Double         // 0..1
    public var y: Double         // 0..1
    public var type: String?     // optional: "flick"/"hold"/"tap"
    public var length: Double?   // for hold notes

    public init(id: String = UUID().uuidString, time: Double, angle: Double, x: Double, y: Double, type: String? = nil, length: Double? = nil) {
        self.id = id
        self.time = time
        self.angle = angle
        self.x = x
        self.y = y
        self.type = type
        self.length = length
    }

    // 小さなバリデーションヘルパー
    public func isValid() -> Bool {
        return time.isFinite && x >= 0.0 && x <= 1.0 && y >= 0.0 && y <= 1.0
    }
}

public struct Sheet: Codable {
    public var version: Int
    public var title: String
    public var difficulty: String
    public var level: Int?
    public var id: String
    public var bpm: Double?
    public var offset: Double?
    public var audioFilename: String?
    public var metadata: [String: String]?
    public var notes: [SheetNote]

    public init(version: Int = 1, title: String = "Untitled", difficulty: String = "Normal", level: Int? = nil, id: String = UUID().uuidString, bpm: Double? = nil, offset: Double? = 0.0, audioFilename: String? = nil, movieFilename: String? = nil, metadata: [String: String]? = nil, notes: [SheetNote] = []) {
        self.version = version
        self.title = title
        self.difficulty = difficulty
        self.level = level
        self.id = id
        self.bpm = bpm
        self.offset = offset
        self.audioFilename = audioFilename
        self.metadata = metadata
        self.notes = notes
    }

    // 基本バリデーション
    public func validate() -> [String] {
        var errors: [String] = []
        if version <= 0 { errors.append("version must be > 0") }
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append("title empty") }
        for n in notes {
            if !n.isValid() {
                errors.append("invalid note: \(n.id)")
            }
        }
        return errors
    }
}
