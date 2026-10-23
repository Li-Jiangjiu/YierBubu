import Foundation
import CoreGraphics
import Testing
@testable import BubuCore

struct WindowPlacementTests {
    @Test func bottomRightUsesVisibleScreenAndMargin() {
        let result = WindowPlacement.bottomRight(
            screen: CGRect(x: 0, y: 0, width: 1440, height: 900),
            size: CGSize(width: 420, height: 280), margin: 24)
        #expect(result == CGRect(x: 996, y: 24, width: 420, height: 280))
    }

    @Test func negativeScreenOriginIsPreserved() {
        let result = WindowPlacement.bottomRight(
            screen: CGRect(x: -1920, y: 50, width: 1920, height: 1080),
            size: CGSize(width: 420, height: 280), margin: 24)
        #expect(result == CGRect(x: -444, y: 74, width: 420, height: 280))
    }

    @Test func smallScreenKeepsOriginVisible() {
        let result = WindowPlacement.bottomRight(
            screen: CGRect(x: 10, y: 20, width: 300, height: 200),
            size: CGSize(width: 420, height: 280), margin: 24)
        #expect(result.origin == CGPoint(x: 10, y: 20))
    }
}
