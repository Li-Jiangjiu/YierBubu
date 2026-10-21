using System.Diagnostics;
using System.Windows;
using System.Windows.Threading;
using Microsoft.Win32;
using Forms=System.Windows.Forms;
namespace YierBubu.Windows;

public sealed class AppController:IDisposable
{
    private readonly Application app;
    private readonly PetView view;
    private readonly PetWindow window;
    private readonly InputMonitor input=new();
    private readonly Forms.NotifyIcon tray;
    private readonly System.Drawing.Icon icon;
    private readonly DispatcherTimer frames=new(){Interval=TimeSpan.FromSeconds(1.0/60)},heartbeat=new(){Interval=TimeSpan.FromSeconds(1)},blinkEnd=new(){Interval=TimeSpan.FromSeconds(0.12)};
    private readonly InteractionState state=new(Now);
    private StatusWindow? status;
    private bool hidden,sessionActive=true,disposed,lastResting;
    private double animationUntil,lastBlink;
    private readonly Queue<(double Time,InputEvent Input)> demo=[];
    private readonly Forms.ToolStripMenuItem visibility=new("隐藏小熊"),clickThrough=new("鼠标穿透"){CheckOnClick=true};
    public static double Now=>Stopwatch.GetTimestamp()/(double)Stopwatch.Frequency;
    public AppController(Application app,Assets assets)
    {
        this.app=app;view=new(assets);window=new(view);
        icon=new System.Drawing.Icon(Path.Combine(assets.Root,"YierBubu.ico"));
        tray=new Forms.NotifyIcon{Icon=icon,Text="一二布布 · 桌面陪伴",Visible=false};
        var menu=new Forms.ContextMenuStrip();menu.Items.Add(new Forms.ToolStripMenuItem("一二布布 · 陪你敲键盘"){Enabled=false});
        visibility.Click+=(_,_)=>ToggleVisibility();menu.Items.Add(visibility);
        clickThrough.Click+=(_,_)=>window.SetClickThrough(clickThrough.Checked);menu.Items.Add(clickThrough);
        var size=new Forms.ToolStripMenuItem("小熊大小");
        foreach(int percent in new[]{75,100,125}){var item=new Forms.ToolStripMenuItem(percent+"%"){Checked=percent==100};item.Click+=(_,_)=>{window.SetScale(percent/100.0);foreach(Forms.ToolStripMenuItem other in size.DropDownItems)other.Checked=other==item;};size.DropDownItems.Add(item);}menu.Items.Add(size);
        Add(menu,"恢复到屏幕右下角",()=>window.ResetPosition());Add(menu,"动作演示",StartDemo);menu.Items.Add(new Forms.ToolStripSeparator());
        Add(menu,"连接状态与真实计数…",ShowStatus);Add(menu,"重新连接",()=>{input.Start();UpdateStatus();});menu.Items.Add(new Forms.ToolStripSeparator());Add(menu,"退出一二布布",()=>app.Shutdown());
        tray.ContextMenuStrip=menu;tray.DoubleClick+=(_,_)=>ShowStatus();
        input.Input+=OnInput;input.Reset+=ResetActions;frames.Tick+=(_,_)=>Tick();heartbeat.Tick+=(_,_)=>IdleTick();blinkEnd.Tick+=(_,_)=>{blinkEnd.Stop();view.SetBlinking(false);};
    }
    private static void Add(Forms.ContextMenuStrip menu,string title,Action action){var item=new Forms.ToolStripMenuItem(title);item.Click+=(_,_)=>action();menu.Items.Add(item);}
    public void Start()
    {
        window.Show();tray.Visible=true;input.Start();lastBlink=Now;heartbeat.Start();
        SystemEvents.SessionSwitch+=SessionChanged;SystemEvents.PowerModeChanged+=PowerChanged;SystemEvents.DisplaySettingsChanged+=DisplayChanged;
        if(!input.Listening)ShowStatus();
    }
    private void OnInput(InputEvent value)
    {
        if(value.Repeat)return;
        if(demo.Count>0){demo.Clear();state.Reset(Now);}
        state.Handle(value,Now);Animate();
    }
    private void Animate(){animationUntil=Now+0.3;if(!hidden&&sessionActive){view.SetInteraction(state.Snapshot(Now),Now);frames.Start();}}
    private void Tick()
    {
        double now=Now;
        while(demo.TryPeek(out var next)&&now>=next.Time){demo.Dequeue();state.Handle(next.Input,now);animationUntil=now+0.3;}
        if(!hidden&&sessionActive){view.SetInteraction(state.Snapshot(now),now);view.Refresh();}
        if(demo.Count==0&&now>=animationUntil&&!view.IsAnimating(now))frames.Stop();
    }
    private void IdleTick()
    {
        UpdateStatus();if(hidden||!sessionActive)return;
        double now=Now;var snapshot=state.Snapshot(now);
        if(snapshot.Resting!=lastResting){lastResting=snapshot.Resting;view.SetInteraction(snapshot,now);}
        if(now-lastBlink>=4&&snapshot.Keys.Count==0&&snapshot.Buttons.Count==0&&snapshot.ScrollX==0&&snapshot.ScrollY==0){lastBlink=now;view.SetBlinking(true);blinkEnd.Start();}
    }
    private void ResetActions(){demo.Clear();state.Reset(Now);frames.Stop();blinkEnd.Stop();view.SetBlinking(false);view.SetSuspended(hidden||!sessionActive);if(!hidden&&sessionActive)Animate();}
    private void ToggleVisibility()
    {
        hidden=!hidden;visibility.Text=hidden?"显示小熊":"隐藏小熊";demo.Clear();state.Reset(Now);view.SetSuspended(hidden||!sessionActive);
        if(hidden){frames.Stop();blinkEnd.Stop();window.Hide();}else{window.Show();Animate();}
    }
    private void StartDemo()
    {
        if(hidden)ToggleVisibility();ResetActions();double start=Now;
        (double Delay,InputEvent Event)[] sequence=[
            (0.2,new(InputKind.KeyDown,Key:'a')),(0.45,new(InputKind.KeyUp,Key:'a')),
            (0.6,new(InputKind.KeyDown,Key:'s')),(0.85,new(InputKind.KeyUp,Key:'s')),
            (1,new(InputKind.KeyDown,Key:'d')),(1.25,new(InputKind.KeyUp,Key:'d')),
            (1.5,new(InputKind.KeyDown,Key:'c')),(1.9,new(InputKind.KeyUp,Key:'c')),
            (2.2,new(InputKind.MouseDown,Button:MouseButton.Left)),(2.5,new(InputKind.MouseUp,Button:MouseButton.Left)),
            (2.8,new(InputKind.MouseDown,Button:MouseButton.Right)),(3.1,new(InputKind.MouseUp,Button:MouseButton.Right)),
            (3.4,new(InputKind.MouseDown,Button:MouseButton.Middle)),(3.7,new(InputKind.MouseUp,Button:MouseButton.Middle)),
            (4,new(InputKind.Scroll,Y:4)),(4.4,new(InputKind.Scroll,Y:-4)),(4.8,new(InputKind.Scroll,X:4)),(5.2,new(InputKind.Scroll,X:-4))];
        foreach(var action in sequence)demo.Enqueue((start+action.Delay,action.Event));frames.Start();
    }
    private void ShowStatus(){if(status==null){status=new StatusWindow(()=>{input.Start();UpdateStatus();});status.Closed+=(_,_)=>status=null;}UpdateStatus();status.Show();status.Activate();}
    private void UpdateStatus(){status?.Update(input.Status,input.Activity);}
    private void Dispatch(Action action){if(!disposed)app.Dispatcher.BeginInvoke(()=>{if(!disposed)action();});}
    private void SessionChanged(object sender,SessionSwitchEventArgs e)
    {
        if(e.Reason is SessionSwitchReason.SessionLock or SessionSwitchReason.SessionLogoff or SessionSwitchReason.RemoteDisconnect or SessionSwitchReason.ConsoleDisconnect)Dispatch(Suspend);
        else if(e.Reason is SessionSwitchReason.SessionUnlock or SessionSwitchReason.SessionLogon or SessionSwitchReason.RemoteConnect or SessionSwitchReason.ConsoleConnect)Dispatch(Resume);
    }
    private void PowerChanged(object sender,PowerModeChangedEventArgs e){if(e.Mode==PowerModes.Suspend)Dispatch(Suspend);else if(e.Mode==PowerModes.Resume)Dispatch(Resume);}
    private void DisplayChanged(object? sender,EventArgs e)=>Dispatch(()=>window.ResetPosition());
    private void Suspend(){sessionActive=false;input.Stop();ResetActions();}
    private void Resume(){sessionActive=true;input.Start();ResetActions();}
    public void Dispose()
    {
        if(disposed)return;disposed=true;
        SystemEvents.SessionSwitch-=SessionChanged;SystemEvents.PowerModeChanged-=PowerChanged;SystemEvents.DisplaySettingsChanged-=DisplayChanged;
        frames.Stop();heartbeat.Stop();blinkEnd.Stop();demo.Clear();input.Input-=OnInput;input.Reset-=ResetActions;input.Dispose();
        status?.Close();window.Close();tray.Visible=false;tray.ContextMenuStrip?.Dispose();tray.Dispose();icon.Dispose();
    }
}
