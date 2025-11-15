//
//  SheetNote+Conpat.swift
//  rhythm_game
//
//  Created by Karen Naito on 2025/11/15.
//

// SheetNote+Compat.swift
// Compatibility shims so older code that uses .x, .y, .angle or the legacy initializer continues to compile
// Place this file in your project (same module as SheetModel.swift)

import Foundation

public extension SheetNote {
    // Computed aliases for legacy flat coords used by older UI code.
    // Mark setters `mutating` because SheetNote is a value type (struct).
    var x: Double {
        get { normalizedPosition.x }
        mutating set { normalizedPosition.x = newValue }
    }

    var y: Double {
        get { normalizedPosition.y }
        mutating set { normalizedPosition.y = newValue }
    }

    // Provide a z alias for code that expects a 3D coordinate.
    // This project uses 2D normalized positions, so z is a no-op with 0.0 default.
    var z: Double {
        get { 0.0 }
        mutating set { /* ignore - 2D model */ }
    }

    // Legacy angle alias (some code used `angle` instead of `angleDegrees`)
    var angle: Double {
        get { angleDegrees }
        mutating set { angleDegrees = newValue }
    }

    // Convenience initializer matching older call sites like:
    // SheetNote(id: ..., time: ..., angle: 0.0, x: 0.5, y: 0.5)
    init(id: String? = nil, time: Double, angle: Double, x: Double, y: Double) {
        self.init(id: id, time: time, angleDegrees: angle, normalizedPosition: Position(x: x, y: y))
    }
}
