//
//  NoteData.swift
//  rhythm_game
//
//  Created by Karen Naito on 2025/11/11.
//

import Foundation
import CoreGraphics

/// 譜面データを別ファイルで管理するための定義
/// - Note 型と、10 個分のサンプル譜面を提供する SampleData
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

    // 10 個のサンプル譜面をプログラム生成して返す
    private static func makeSamples() -> [[Note]] {
        var sets: [[Note]] = []
        for i in 0..<10 {
            var arr: [Note] = []
            let base = Double(i) * 0.15
            for j in 0..<6 {
                let t = 0.8 + Double(j) * 0.55 + base
                let angle = Double((j * 37 + i * 13) % 180) - 90.0
                let nx = min(0.95, max(0.05, 0.15 + Double((j * 31 + i * 7) % 70) / 100.0))
                let ny = min(0.95, max(0.05, 0.2 + Double((j * 17 + i * 11) % 70) / 100.0))
                arr.append(Note(time: t, angleDegrees: angle, normalizedPosition: CGPoint(x: nx, y: ny)))
            }
            sets.append(arr)
        }
        return sets
    }
}
