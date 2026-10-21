namespace YierBubu.Core;

public sealed record InteractionSnapshot(IReadOnlySet<char> Keys,IReadOnlySet<MouseButton> Buttons,double ScrollX=0,double ScrollY=0,char? LeftKey=null,char? RightKey=null,bool Resting=false)
{
    public static InteractionSnapshot Empty=>new(new HashSet<char>(),new HashSet<MouseButton>());
}
/// Short-lived feedback only: no typed text or event history is retained.
public sealed class InteractionState
{
    private sealed record Press(bool Held,double Until,long Order);
    private readonly Dictionary<char,Press> keys=[];
    private readonly Dictionary<MouseButton,Press> buttons=[];
    private double scrollX,scrollY,scrollUntil,lastActivity,lastTime;
    private long order;
    public InteractionState(double now){lastActivity=lastTime=now;}
    public void Handle(InputEvent input,double time)
    {
        Normalize(time);
        switch(input.Kind){
            case InputKind.KeyDown:
                if(!ScanCodes.VisibleKeys.Contains(input.Key)||input.Key=='\0')return;
                lastActivity=time;
                if(input.Repeat||(keys.TryGetValue(input.Key,out var held)&&held.Held))return;
                keys[input.Key]=new(true,time+0.1,++order);break;
            case InputKind.KeyUp:
                if(keys.TryGetValue(input.Key,out var key)){keys[input.Key]=key with{Held=false};lastActivity=time;}break;
            case InputKind.MouseDown:
                lastActivity=time;
                if(buttons.TryGetValue(input.Button,out var down)&&down.Held)return;
                buttons[input.Button]=new(true,time+0.12,++order);break;
            case InputKind.MouseUp:
                if(buttons.TryGetValue(input.Button,out var button)){buttons[input.Button]=button with{Held=false};lastActivity=time;}break;
            case InputKind.Scroll:
                if(!double.IsFinite(input.X)||!double.IsFinite(input.Y)||(input.X==0&&input.Y==0))return;
                if(time>=scrollUntil){scrollX=scrollY=0;}
                scrollX=Math.Clamp(scrollX*input.X<0?input.X:scrollX+input.X,-100,100);
                scrollY=Math.Clamp(scrollY*input.Y<0?input.Y:scrollY+input.Y,-100,100);
                scrollUntil=time+0.18;lastActivity=time;break;
        }
        Prune(time);
    }
    public InteractionSnapshot Snapshot(double time)
    {
        Normalize(time);Prune(time);
        var ordered=keys.OrderByDescending(p=>p.Value.Order).Select(p=>p.Key).ToArray();
        char? left=ordered.Where(k=>ScanCodes.LeftKeys.Contains(k)).Select(k=>(char?)k).FirstOrDefault();
        char? right=ordered.Where(k=>!ScanCodes.LeftKeys.Contains(k)).Select(k=>(char?)k).FirstOrDefault();
        return new(new HashSet<char>(keys.Keys),new HashSet<MouseButton>(buttons.Keys),time<scrollUntil?scrollX:0,time<scrollUntil?scrollY:0,left,right,keys.Count==0&&buttons.Count==0&&time>=scrollUntil&&time-lastActivity>=15);
    }
    public void Reset(double time){keys.Clear();buttons.Clear();scrollX=scrollY=0;scrollUntil=time;lastActivity=lastTime=time;order=0;}
    private void Normalize(double time){if(time<lastTime)Reset(time);lastTime=time;}
    private void Prune(double time)
    {
        foreach(var k in keys.Where(p=>!p.Value.Held&&p.Value.Until<=time).Select(p=>p.Key).ToArray())keys.Remove(k);
        foreach(var k in buttons.Where(p=>!p.Value.Held&&p.Value.Until<=time).Select(p=>p.Key).ToArray())buttons.Remove(k);
        if(time>=scrollUntil){scrollX=scrollY=0;}
    }
}
