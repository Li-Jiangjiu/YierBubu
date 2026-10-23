namespace YierBubu.Core;

public sealed record PawPose(Point2 Shoulder,Point2 Contact,double Angle,bool IsMouse)
{
    public Point2 TipOffset=>new(-Math.Sin(Angle)*44,Math.Cos(Angle)*44);
    public Point2 Center=>new(Contact.X-TipOffset.X,Contact.Y-TipOffset.Y);
    public Point2 Tip=>new(Center.X+TipOffset.X,Center.Y+TipOffset.Y);
    public Point2 Elbow=>new(Shoulder.X+(Center.X-Shoulder.X)*0.5,Math.Max(Shoulder.Y,Center.Y)+16);
    public static PawPose Idle(bool left)=>new(left?new(905,700):new(1200,765),left?new(835,705):new(1130,784),0,false);
    public static PawPose IdleMouse=>new(new(355,539),new(352,591),0,true);
    public static PawPose? Typing(char label)=>SceneLayout.Key(label) is { } key?new(Idle(key.LeftPaw).Shoulder,key.Contact,0.28,false):null;
    public static PawPose Mouse(IReadOnlySet<MouseButton> buttons,bool scrolling)
    {
        var b=scrolling||buttons.Contains(MouseButton.Middle)||buttons.Count>1?MouseButton.Middle:buttons.Contains(MouseButton.Left)?MouseButton.Left:MouseButton.Right;
        return new(IdleMouse.Shoulder,SceneLayout.MouseContact(b),0.75,true);
    }
    public PawPose Interpolate(PawPose target,double t)=>new(Point2.Lerp(Shoulder,target.Shoulder,t),Point2.Lerp(Contact,target.Contact,t),Angle+(target.Angle-Angle)*t,IsMouse);
}
public sealed class PawMotion(PawPose pose)
{
    private PawPose from=pose,target=pose;
    private double started;
    public void Retarget(PawPose value,double now){if(value==target)return;from=Pose(now);target=value;started=now;}
    public PawPose Pose(double now){double t=Math.Clamp((now-started)/0.075,0,1);return t>=1?target:from.Interpolate(target,t*t*(3-2*t));}
    public bool IsAnimating(double now)=>from!=target&&now<started+0.075;
}
public sealed record ScenePaws(PawPose? Left,PawPose? Right,PawPose? Mouse)
{
    public static ScenePaws From(InteractionSnapshot s)=>new(s.LeftKey is {} l?PawPose.Typing(l):null,s.RightKey is {} r?PawPose.Typing(r):null,s.Buttons.Count>0||s.ScrollX!=0||s.ScrollY!=0?PawPose.Mouse(s.Buttons,s.ScrollX!=0||s.ScrollY!=0):null);
}
