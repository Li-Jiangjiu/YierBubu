using System.Windows;
using System.Windows.Media;
namespace YierBubu.Windows;

public sealed class PetView:FrameworkElement
{
    private readonly SceneRenderer renderer;
    private PawMotion left=new(PawPose.Idle(true)),right=new(PawPose.Idle(false)),mouse=new(PawPose.IdleMouse);
    private InteractionSnapshot state=InteractionSnapshot.Empty;
    private bool suspended,blinking;
    public PetView(Assets assets){renderer=new(assets);Focusable=false;}
    public bool IsAnimating(double now)=>!suspended&&(left.IsAnimating(now)||right.IsAnimating(now)||mouse.IsAnimating(now));
    public void SetInteraction(InteractionSnapshot value,double now)
    {
        state=value;
        left.Retarget(value.LeftKey is {} l?PawPose.Typing(l)!:PawPose.Idle(true),now);
        right.Retarget(value.RightKey is {} r?PawPose.Typing(r)!:PawPose.Idle(false),now);
        mouse.Retarget(value.Buttons.Count>0||value.ScrollX!=0||value.ScrollY!=0?PawPose.Mouse(value.Buttons,value.ScrollX!=0||value.ScrollY!=0):PawPose.IdleMouse,now);
        InvalidateVisual();
    }
    public void SetSuspended(bool value)
    {
        suspended=value;blinking=false;state=InteractionSnapshot.Empty;
        left=new(PawPose.Idle(true));right=new(PawPose.Idle(false));mouse=new(PawPose.IdleMouse);InvalidateVisual();
    }
    public void SetBlinking(bool value){blinking=value;InvalidateVisual();}
    public void Refresh()=>InvalidateVisual();
    protected override void OnRender(DrawingContext dc)
    {
        base.OnRender(dc);double now=AppController.Now;
        var poses=new ScenePaws(state.LeftKey!=null||left.IsAnimating(now)?left.Pose(now):null,state.RightKey!=null||right.IsAnimating(now)?right.Pose(now):null,state.Buttons.Count>0||state.ScrollX!=0||state.ScrollY!=0||mouse.IsAnimating(now)?mouse.Pose(now):null);
        dc.PushTransform(new ScaleTransform(ActualWidth/1536,ActualHeight/1024));renderer.Draw(dc,state,poses,blinking);dc.Pop();
    }
}
