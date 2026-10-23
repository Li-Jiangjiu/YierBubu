using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
namespace YierBubu.Windows;

public sealed class PetWindow:Window
{
    public double Scale {get;private set;}=1;
    public bool ClickThrough {get;private set;}
    public PetWindow(PetView view)
    {
        Title="一二布布";Width=300;Height=200;WindowStyle=WindowStyle.None;ResizeMode=ResizeMode.NoResize;
        AllowsTransparency=true;Background=Brushes.Transparent;Topmost=true;ShowInTaskbar=false;ShowActivated=false;Focusable=false;Content=view;
        Left=SystemParameters.WorkArea.X+SystemParameters.WorkArea.Width-324;Top=SystemParameters.WorkArea.Y+SystemParameters.WorkArea.Height-224;
        SourceInitialized+=(_,_)=>{UpdateStyles();ResetPosition();};
        MouseLeftButtonDown+=(_,e)=>{if(!ClickThrough&&e.ButtonState==MouseButtonState.Pressed){DragMove();e.Handled=true;}};
    }
    private nint Handle=>new WindowInteropHelper(this).Handle;
    private void UpdateStyles()
    {
        if(Handle==0)return;
        long style=NativeMethods.GetWindowLongPtr(Handle,-20).ToInt64()|0x08000000|0x80; // NOACTIVATE | TOOLWINDOW
        style=ClickThrough?style|0x20:style&~0x20;
        NativeMethods.SetWindowLongPtr(Handle,-20,new nint(style));
        NativeMethods.SetWindowPos(Handle,0,0,0,0,0,0x0037); // FRAMECHANGED | NOMOVE | NOSIZE | NOZORDER | NOACTIVATE
    }
    public void SetClickThrough(bool enabled){ClickThrough=enabled;UpdateStyles();}
    public void SetScale(double value){if(value!=0.75&&value!=1&&value!=1.25)return;Scale=value;Width=300*value;Height=200*value;ResetPosition();}
    public void ResetPosition()
    {
        if(Handle==0)return;
        var info=new NativeMethods.MonitorInfo{Size=Marshal.SizeOf<NativeMethods.MonitorInfo>()};
        if(!NativeMethods.GetMonitorInfo(NativeMethods.MonitorFromWindow(Handle,2),ref info))return;
        double factor=Math.Max(96,NativeMethods.GetDpiForWindow(Handle))/96.0;
        var p=WindowPlacement.BottomRight(new(info.Work.Left,info.Work.Top,info.Work.Right-info.Work.Left,info.Work.Bottom-info.Work.Top),Width*factor,Height*factor,24*factor);
        NativeMethods.SetWindowPos(Handle,0,(int)p.X,(int)p.Y,0,0,0x0015); // NOSIZE | NOZORDER | NOACTIVATE
    }
}
