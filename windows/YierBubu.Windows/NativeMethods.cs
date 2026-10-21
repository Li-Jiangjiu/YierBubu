using System.Runtime.InteropServices;
namespace YierBubu.Windows;

public static class NativeMethods
{
    [StructLayout(LayoutKind.Sequential)] public struct RawInputDevice { public ushort UsagePage,Usage;public uint Flags;public nint Target; }
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left,Top,Right,Bottom; }
    [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Auto)] public struct MonitorInfo { public int Size;public Rect Monitor,Work;public uint Flags; }
    [DllImport("user32.dll",SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] public static extern bool RegisterRawInputDevices([In]RawInputDevice[] devices,uint count,uint size);
    [DllImport("user32.dll",SetLastError=true)] public static extern uint GetRawInputData(nint input,uint command,nint data,ref uint size,uint headerSize);
    [DllImport("user32.dll",EntryPoint="GetWindowLongPtrW",SetLastError=true)] public static extern nint GetWindowLongPtr(nint window,int index);
    [DllImport("user32.dll",EntryPoint="SetWindowLongPtrW",SetLastError=true)] public static extern nint SetWindowLongPtr(nint window,int index,nint value);
    [DllImport("user32.dll",SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] public static extern bool SetWindowPos(nint window,nint after,int x,int y,int width,int height,uint flags);
    [DllImport("user32.dll")] public static extern nint MonitorFromWindow(nint window,uint flags);
    [DllImport("user32.dll",CharSet=CharSet.Auto)] [return:MarshalAs(UnmanagedType.Bool)] public static extern bool GetMonitorInfo(nint monitor,ref MonitorInfo info);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(nint window);
}
