import Foundation
import CoreGraphics

/// 外部譜面データ（10個のサンプルを提供）
public struct Note: Identifiable {
    public let id: UUID
    public let time: Double
    public let angleDegrees: Double
    public let normalizedPosition: CGPoint

    public init(id: UUID = UUID(), time: Double, angleDegrees: Double, normalizedPosition: CGPoint) {
        self.id = id
        self.time = time
        self.angleDegrees = angleDegrees
        self.normalizedPosition = normalizedPosition
    }
}

public enum SampleData {
    public static let samples: [[Note]] = makeSamples()

    // 10個のサンプル譜面を生成
    private static func makeSamples() -> [[Note]] {
        var sets: [[Note]] = []
        for i in 0..<10 {
            var arr: [Note] = []
            let base = Double(i) * 0.12
            // 各譜面は 5〜7 個のノートを持たせる（例）
            let count = 5 + (i % 3)
            for j in 0..<count {
                let t = 0.8 + Double(j) * 0.6 + base
                let angle = Double((j * 37 + i * 13) % 180) - 90.0
                let nx = min(0.92, max(0.08, 0.15 + Double((j * 31 + i * 7) % 70) / 100.0))
                let ny = min(0.92, max(0.08, 0.2 + Double((j * 17 + i * 11) % 70) / 100.0))
                arr.append(Note(time: t, angleDegrees: angle, normalizedPosition: CGPoint(x: nx, y: ny)))
            }
            sets.append(arr)
        }
        return sets
    }
}
