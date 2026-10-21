using System.Threading;
using System.Windows;
namespace YierBubu.Windows;

public static class Program
{
    [STAThread]
    public static int Main(string[] args)
    {
        try {
            var assets=new Assets();
            if(args.Contains("--verify-assets"))return File.Exists(Path.Combine(assets.Root,"YierBubu.ico"))?0:2;
            using var mutex=new Mutex(true,"Local\\YierBubu.Windows.Desktop",out bool created);
            if(!created){MessageBox.Show("一二布布已经在运行，请查看右下角托盘的小熊图标。","一二布布");return 0;}
            var app=new Application{ShutdownMode=ShutdownMode.OnExplicitShutdown};
            using var controller=new AppController(app,assets);controller.Start();app.Run();return 0;
        } catch(Exception error) {
            if(!args.Contains("--verify-assets"))MessageBox.Show("一二布布未能启动：\n"+error.Message+"\n\n请完整解压安装包后再运行。","一二布布",MessageBoxButton.OK,MessageBoxImage.Error);
            return 1;
        }
    }
}
