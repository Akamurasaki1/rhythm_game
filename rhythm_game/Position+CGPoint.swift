import Foundation
import CoreGraphics

public extension Position {
    init(_ point: CGPoint) {
        self.init(x: Double(point.x), y: Double(point.y))
    }
}

public extension CGPoint {
    init(_ position: Position) {
        self.init(x: CGFloat(position.x), y: CGFloat(position.y))
    }
}