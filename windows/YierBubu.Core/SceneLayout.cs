namespace YierBubu.Core;

public readonly record struct Point2(double X,double Y)
{
    public static Point2 Lerp(Point2 a,Point2 b,double t)=>new(a.X+(b.X-a.X)*t,a.Y+(b.Y-a.Y)*t);
}
public sealed record KeyGeometry(char Label,Point2 Center,Point2 Across,Point2 Depth,bool LeftPaw)
{
    public Point2 SurfaceCenter(bool pressed)=>new(Center.X,Center.Y+(pressed?2:-6));
    public Point2[] SurfaceCorners(bool pressed)=>Corners(pressed?2:-6);
    public Point2[] Corners(double offset=0)=>new (double U,double V)[]{(-1,-1),(1,-1),(1,1),(-1,1)}.Select(p=>new Point2(Center.X+p.U*Across.X+p.V*Depth.X,Center.Y+p.U*Across.Y+p.V*Depth.Y+offset)).ToArray();
    public Point2 Contact=>new(Center.X-Depth.X*0.72,Center.Y+2-Depth.Y*0.72);
    public bool ContainsSurface(Point2 point,bool pressed)
    {
        var c=SurfaceCenter(pressed);double x=point.X-c.X,y=point.Y-c.Y,det=Across.X*Depth.Y-Across.Y*Depth.X;
        return Math.Abs((x*Depth.Y-y*Depth.X)/det)<=1&&Math.Abs((Across.X*y-Across.Y*x)/det)<=1;
    }
}
public static class SceneLayout
{
    public const double Width=1536,Height=1024;
    public static IReadOnlyList<KeyGeometry> Keys {get;}=BuildKeys();
    private static KeyGeometry[] BuildKeys()
    {
        (string Labels,Point2 Origin,Point2 Step)[] rows=[("1234567890",new(632,655),new(72.5,22)),("qwertyuiop",new(597,693),new(77,22.7)),("asdfghjkl",new(575,731),new(80,24.3)),("zxcvbnm",new(600,782),new(86,26.5))];
        return rows.SelectMany((row,r)=>row.Labels.Select((label,i)=>new KeyGeometry(label,new(row.Origin.X+i*row.Step.X,row.Origin.Y+i*row.Step.Y),new(32.5*(1+r*0.045),9.8*(1+r*0.045)),new(-17.5*(1+r*0.045),13.8*(1+r*0.045)),i<5))).ToArray();
    }
    public static KeyGeometry? Key(char label)=>Keys.FirstOrDefault(k=>k.Label==label);
    public static Point2 MouseContact(MouseButton b)=>b switch{MouseButton.Left=>new(324,622),MouseButton.Right=>new(255,592),_=>new(280,601)};
    public static Point2[] MouseRegion(MouseButton b)=>b switch{
        MouseButton.Left=>[new(356,553),new(395,564),new(407,591),new(350,637),new(286,653),new(307,601)],
        MouseButton.Right=>[new(250,577),new(314,553),new(356,553),new(307,601),new(224,633)],
        _=>[new(254,619),new(295,578),new(306,587),new(265,628)]};
    public static bool MouseContains(Point2 p,MouseButton button)
    {
        var points=MouseRegion(button);bool inside=false;
        for(int i=0;i<points.Length;i++){var a=points[i];var b=points[(i+1)%points.Length];if((a.Y>p.Y)!=(b.Y>p.Y)&&p.X<(b.X-a.X)*(p.Y-a.Y)/(b.Y-a.Y)+a.X)inside=!inside;}
        return inside;
    }
}
