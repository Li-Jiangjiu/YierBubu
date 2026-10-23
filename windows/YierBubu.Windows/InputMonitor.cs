using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Windows.Interop;
namespace YierBubu.Windows;

/// A dedicated message-only window keeps read-only listening independent of pet visibility.
public sealed class InputMonitor:IDisposable
{
    private readonly HwndSource source;
    private readonly RawInputSession session=new();
    public bool Listening {get;private set;}
    public string Status {get;private set;}="监听已停止";
    public InputActivity Activity {get;}=new();
    public event Action<InputEvent>? Input;
    public event Action? Reset;
    public InputMonitor()
    {
        var parameters=new HwndSourceParameters("YierBubu read-only input"){ParentWindow=new nint(-3),Width=0,Height=0,WindowStyle=0};
        source=new HwndSource(parameters);source.AddHook(Hook);
    }
    public void Start()
    {
        Stop();var devices=Devices(0x2100,source.Handle); // INPUTSINK | DEVNOTIFY; never NOLEGACY.
        if(!NativeMethods.RegisterRawInputDevices(devices,(uint)devices.Length,(uint)Marshal.SizeOf<NativeMethods.RawInputDevice>())){
            Status="监听失败 · "+new Win32Exception(Marshal.GetLastWin32Error()).Message;return;
        }
        Listening=true;Status="监听中 · 仅触发动作";
    }
    public void Stop()
    {
        if(Listening){var devices=Devices(1,0);if(!NativeMethods.RegisterRawInputDevices(devices,(uint)devices.Length,(uint)Marshal.SizeOf<NativeMethods.RawInputDevice>())){Status="停止监听失败";throw new Win32Exception(Marshal.GetLastWin32Error());}}
        Listening=false;session.Reset();Reset?.Invoke();Status="监听已停止";
    }
    private static NativeMethods.RawInputDevice[] Devices(uint flags,nint target)=>[
        new(){UsagePage=1,Usage=6,Flags=flags,Target=target},new(){UsagePage=1,Usage=2,Flags=flags,Target=target}];
    private nint Hook(nint hwnd,int message,nint wParam,nint lParam,ref bool handled)
    {
        if(message==0x00fe){session.Reset();Reset?.Invoke();}
        if(message!=0x00ff||!Listening)return 0;
        uint size=0;
        if(NativeMethods.GetRawInputData(lParam,0x10000003,0,ref size,24)==uint.MaxValue||size<24||size>65536)return 0;
        nint buffer=Marshal.AllocHGlobal((int)size);
        try{
            uint copied=NativeMethods.GetRawInputData(lParam,0x10000003,buffer,ref size,24);
            if(copied==uint.MaxValue||copied!=size)return 0;
            byte[] bytes=new byte[size];Marshal.Copy(buffer,bytes,0,(int)size);
            foreach(var input in session.Decode(bytes)){Activity.Record(input);Input?.Invoke(input);}
        } finally{Marshal.FreeHGlobal(buffer);}
        // Leave unhandled so DefWindowProc can perform WM_INPUT cleanup.
        return 0;
    }
    public void Dispose(){Stop();source.RemoveHook(Hook);source.Dispose();}
}
