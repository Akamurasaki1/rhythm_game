import Foundation
import CoreGraphics

// SheetNote / Sheet を JSON に保存するための Codable モデル
public struct SheetNote: Codable, Identifiable {
    public var id: UUID
    public var time: Double      // hit 時刻（秒）
    public var angle: Double     // 度
    public var x: Double         // 0..1 正規化
    public var y: Double         // 0..1 正規化
    public var type: String?     // 任意拡張

    public init(id: UUID = UUID(), time: Double, angle: Double, x: Double, y: Double, type: String? = nil) {
        self.id = id
        self.time = time
        self.angle = angle
        self.x = x
        self.y = y
        self.type = type
    }
}

public struct Sheet: Codable {
    public var version: Int = 1
    public var title: String = "Untitled"
    public var difficulty: String = "Normal" // e.g. Easy/Normal/Hard or numeric
    public var bpm: Double? = nil
    public var offset: Double? = 0.0
    /// audioFilename は JSON と同じフォルダにある wav のファイル名（相対パス）
    public var audioFilename: String? = nil
    public var metadata: [String: String]? = nil
    public var notes: [SheetNote] = []

    public init(version: Int = 1, title: String = "Untitled", difficulty: String = "Normal", bpm: Double? = nil, offset: Double? = 0.0, audioFilename: String? = nil, metadata: [String: String]? = nil, notes: [SheetNote] = []) {
        self.version = version
        self.title = title
        self.difficulty = difficulty
        self.bpm = bpm
        self.offset = offset
        self.audioFilename = audioFilename
        self.metadata = metadata
        self.notes = notes
    }
}
