import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

enum KeyboardHitTesting {
    // Nearest visible key rectangles partition the complete keyboard surface.
    // Borders can have gutters while input regions have no unclaimed pixels.
    static func nearest(to point: CGPoint, frames: [CGRect]) -> Int? {
        frames.indices.min { left, right in
            let a = distance(point, frames[left]), b = distance(point, frames[right])
            if a != b { return a < b }
            let ac = hypot(point.x - frames[left].midX, point.y - frames[left].midY)
            let bc = hypot(point.x - frames[right].midX, point.y - frames[right].midY)
            return ac == bc ? left < right : ac < bc
        }
    }
    private static func distance(_ point: CGPoint, _ rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }
}
