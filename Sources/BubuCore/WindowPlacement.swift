import CoreGraphics

public enum WindowPlacement {
    public static func bottomRight(screen: CGRect, size: CGSize, margin: Double) -> CGRect {
        CGRect(x: max(screen.minX, screen.maxX - size.width - margin),
               y: min(screen.minY + margin, max(screen.minY, screen.maxY - size.height)),
               width: size.width, height: size.height)
    }
}
