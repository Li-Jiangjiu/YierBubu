using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Interop;
using System.Text.Json;
using System.Runtime.InteropServices;
using YierBubu.Core;
using YierBubu.Windows;

internal sealed class NotVerifiedException(string message):Exception(message);

internal static class Program
{
    [DllImport("user32.dll")] private static extern nint GetForegroundWindow();
    [DllImport("user32.dll",SetLastError=true)] private static extern uint GetRegisteredRawInputDevices([Out] NativeMethods.RawInputDevice[]? devices,ref uint count,uint size);
    [STAThread]
    static int Main(string[] args)
    {
        string output=args.Length>0?Path.GetFullPath(args[0]):Path.GetFullPath("smoke-output");Directory.CreateDirectory(output);
        var results=new Dictionary<string,object>();int failures=0,skipped=0;
        void Test(string name,Action body){try{body();results[name]="pass";Console.WriteLine("PASS "+name);}catch(NotVerifiedException e){results[name]="not-verified: "+e.Message;skipped++;Console.WriteLine("NOT VERIFIED "+name+": "+e.Message);}catch(Exception e){results[name]=e.ToString();failures++;Console.WriteLine("FAIL "+name+": "+e.Message);}}
        void Check(bool ok,string message){if(!ok)throw new Exception(message);}
        var app=new Application{ShutdownMode=ShutdownMode.OnExplicitShutdown};
        var assets=new Assets();
        var renderer=new SceneRenderer(assets);
        BitmapSource Frame(InteractionSnapshot s,string file){var visual=new DrawingVisual();using(var dc=visual.RenderOpen())renderer.Draw(dc,s,ScenePaws.From(s),false);var bitmap=new RenderTargetBitmap(1536,1024,96,96,PixelFormats.Pbgra32);bitmap.Render(visual);var encoder=new PngBitmapEncoder();encoder.Frames.Add(BitmapFrame.Create(bitmap));using var f=File.Create(Path.Combine(output,file+".png"));encoder.Save(f);return bitmap;}
        int WhiteNear(BitmapSource b,Point2 point){int count=0;byte[] pixels=new byte[1536*1024*4];b.CopyPixels(pixels,1536*4,0);for(int y=(int)point.Y-18;y<point.Y+18;y++)for(int x=(int)point.X-18;x<point.X+18;x++){int i=(y*1536+x)*4;if(pixels[i+3]>200&&pixels[i]>235&&pixels[i+1]>235&&pixels[i+2]>235)count++;}return count;}
        Test("approved-assets-load",()=>Check(assets.Scene.PixelWidth==1536&&assets.Paws.PixelHeight==1024,"invalid dimensions"));
        Test("missing-assets-fail-clearly",()=>{try{_ = new Assets(Path.Combine(output,"missing"));throw new Exception("missing art accepted");}catch(FileNotFoundException){}});
        Frame(InteractionSnapshot.Empty,"idle");
        foreach(var key in SceneLayout.Keys){var k=key;Test("actual-paw-pixels-"+k.Label,()=>{var state=new InteractionState(0);state.Handle(new(InputKind.KeyDown,Key:k.Label),0);var b=Frame(state.Snapshot(0.01),"key-"+k.Label);Check(WhiteNear(b,k.Contact)>12,"paw not at key contact");});}
        var mouseFrames=new Dictionary<MouseButton,BitmapSource>();
        foreach(var button in Enum.GetValues<MouseButton>())Test("mouse-frame-"+button,()=>{var s=new InteractionState(0);s.Handle(new(InputKind.MouseDown,Button:button),0);mouseFrames[button]=Frame(s.Snapshot(0),"mouse-"+button);});
        byte Blue(BitmapSource image,int x,int y){var pixel=new byte[4];image.CopyPixels(new Int32Rect(x,y,1,1),pixel,4,0);return pixel[0];}
        Test("left-mouse-color-in-bubus-left-region",()=>Check(Blue(mouseFrames[MouseButton.Left],335,636)+20<Blue(mouseFrames[MouseButton.Right],335,636),"left button region reversed"));
        Test("right-mouse-color-in-bubus-right-region",()=>Check(Blue(mouseFrames[MouseButton.Right],245,623)+20<Blue(mouseFrames[MouseButton.Left],245,623),"right button region reversed"));
        Test("simultaneous-keys-and-mouse-frame",()=>{var s=new InteractionState(0);s.Handle(new(InputKind.KeyDown,Key:'a'),0);s.Handle(new(InputKind.KeyDown,Key:'j'),0);s.Handle(new(InputKind.MouseDown),0);Frame(s.Snapshot(0),"combined");});
        var window=new PetWindow(new PetView(assets));window.Show();
        try {
            Test("transparent-floating-nonactivating-window",()=>{Check(window.AllowsTransparency&&window.Topmost&&!window.ShowInTaskbar&&!window.ShowActivated,"wrong window flags");Check((NativeMethods.GetWindowLongPtr(new WindowInteropHelper(window).Handle,-20).ToInt64()&0x08000000)!=0,"NOACTIVATE missing");});
            Test("scale-and-reset-position",()=>{window.SetScale(0.75);Check(window.Width==225&&window.Height==150,"75% size");window.SetScale(1.25);Check(window.Width==375&&window.Height==250,"125% size");window.SetScale(1);window.ResetPosition();Check(double.IsFinite(window.Left)&&double.IsFinite(window.Top),"position invalid");});
            Test("style-changes-preserve-foreground-window",()=>{
                var foreground=new Window{Title="Focus sentinel",Width=200,Height=100};foreground.Show();foreground.Activate();
                try {var before=GetForegroundWindow();if(before==0||before!=new WindowInteropHelper(foreground).Handle)throw new NotVerifiedException("runner cannot activate foreground sentinel; interactive focus not verified");window.SetClickThrough(true);Check(GetForegroundWindow()==before,"pet stole focus enabling click-through");window.SetClickThrough(false);Check(GetForegroundWindow()==before,"pet stole focus disabling click-through");}finally{foreground.Close();}
            });
            Test("click-through-native-style",()=>{window.SetClickThrough(true);Check((NativeMethods.GetWindowLongPtr(new WindowInteropHelper(window).Handle,-20).ToInt64()&0x20)!=0,"transparent style missing");window.SetClickThrough(false);Check((NativeMethods.GetWindowLongPtr(new WindowInteropHelper(window).Handle,-20).ToInt64()&0x20)==0,"transparent style persisted");});
            Test("hide-show-keeps-window-usable",()=>{window.Hide();Check(!window.IsVisible,"did not hide");window.Show();Check(window.IsVisible,"did not show");});
            Test("raw-input-registration-and-stop",()=>{using var input=new InputMonitor();input.Start();Check(input.Listening,input.Status);input.Stop();Check(!input.Listening,"listener remained active");});
        } finally {window.Close();}
        void Pump(double seconds){var frame=new System.Windows.Threading.DispatcherFrame();var timer=new System.Windows.Threading.DispatcherTimer{Interval=TimeSpan.FromSeconds(seconds)};timer.Tick+=(_,_)=>{frame.Continue=false;};timer.Start();System.Windows.Threading.Dispatcher.PushFrame(frame);timer.Stop();}
        uint Registered(){uint count=0;uint result=GetRegisteredRawInputDevices(null,ref count,(uint)Marshal.SizeOf<NativeMethods.RawInputDevice>());if(result==uint.MaxValue)throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());return count;}
        byte[] ViewPixels(Visual visual){var b=new RenderTargetBitmap(300,200,96,96,PixelFormats.Pbgra32);b.Render(visual);var bytes=new byte[300*200*4];b.CopyPixels(bytes,1200,0);return bytes;}
        Test("actual-controller-demo-hide-listener-and-disposal",()=>{
            using(var controller=new AppController(app,assets)){
                controller.Start();Pump(0.1);var pet=app.Windows.OfType<PetWindow>().Single();var before=ViewPixels((Visual)pet.Content);
                controller.StartDemo();Pump(0.33);Check(!before.SequenceEqual(ViewPixels((Visual)pet.Content)),"demo did not animate through dispatcher");
                controller.ToggleVisibility();Pump(0.05);Check(!pet.IsVisible&&Registered()==2,"hiding stopped input or retained pet");
                controller.ToggleVisibility();Pump(0.05);Check(pet.IsVisible,"show failed");
            }
            Pump(0.05);Check(app.Windows.Count==0&&Registered()==0,"window or Raw Input registration survived disposal");
        });
        results["environment"]=new{os=RuntimeInformation.OSDescription,architecture=RuntimeInformation.ProcessArchitecture.ToString(),sourceCommit=Environment.GetEnvironmentVariable("SOURCE_COMMIT")??"local",physicalInputVerified=false,windows10ClientVerified=false,windows11ClientVerified=false,scope="RenderTargetBitmap + real HWND/styles + Raw Input API registration; no synthetic system input"};
        results["summary"]=new{failures,skipped,passed=results.Count-1-failures-skipped,total=results.Count-1};
        File.WriteAllText(Path.Combine(output,"result.json"),JsonSerializer.Serialize(results,new JsonSerializerOptions{WriteIndented=true}));app.Shutdown();return failures==0?0:1;
    }
}
