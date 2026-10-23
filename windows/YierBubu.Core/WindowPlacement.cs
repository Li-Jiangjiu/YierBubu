namespace YierBubu.Core;
public readonly record struct Rect2(double X,double Y,double Width,double Height);
public static class WindowPlacement
{
    public static Point2 BottomRight(Rect2 screen,double width,double height,double margin)=>Clamp(new(screen.X+screen.Width-width-margin,screen.Y+screen.Height-height-margin),screen,width,height);
    public static Point2 Clamp(Point2 point,Rect2 screen,double width,double height)=>new(Math.Clamp(point.X,screen.X,Math.Max(screen.X,screen.X+screen.Width-width)),Math.Clamp(point.Y,screen.Y,Math.Max(screen.Y,screen.Y+screen.Height-height)));
}
