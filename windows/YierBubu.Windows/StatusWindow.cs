using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
namespace YierBubu.Windows;

public sealed class StatusWindow:Window
{
    private readonly TextBlock status=new(){TextWrapping=TextWrapping.Wrap,FontSize=15,Margin=new Thickness(0,10,0,10)};
    private readonly TextBlock counts=new(){TextWrapping=TextWrapping.Wrap,FontSize=15,Margin=new Thickness(0,6,0,12)};
    public StatusWindow(Action recheck)
    {
        Title="一二布布 · 连接状态";Width=440;Height=410;ResizeMode=ResizeMode.CanMinimize;WindowStartupLocation=WindowStartupLocation.CenterScreen;Background=Brushes.FloralWhite;
        var panel=new StackPanel{Margin=new Thickness(24)};panel.Children.Add(new TextBlock{Text="一二布布 · 键鼠连接",FontSize=22,FontWeight=FontWeights.SemiBold});panel.Children.Add(status);panel.Children.Add(counts);
        panel.Children.Add(new TextBlock{Text="请切换到其他软件，按字母或数字、点击和滚动，观察小熊动作与真实计数。动作演示不会增加这些计数。",TextWrapping=TextWrapping.Wrap,Margin=new Thickness(0,0,0,12)});
        var button=new Button{Content="重新连接",Padding=new Thickness(12,6,12,6),HorizontalAlignment=HorizontalAlignment.Left};button.Click+=(_,_)=>recheck();panel.Children.Add(button);
        panel.Children.Add(new TextBlock{Text="仅用物理键位驱动动画，不读取输入文字、不保存输入历史、不联网。\n普通权限运行；锁屏、安全桌面等场景不会尝试绕过系统限制。",TextWrapping=TextWrapping.Wrap,FontSize=12,Foreground=Brushes.DimGray,Margin=new Thickness(0,18,0,0)});Content=panel;
    }
    public void Update(string value,InputActivity activity){status.Text=value;counts.Text=$"键盘：{activity.KeyPresses}\n左键：{activity.LeftClicks}　右键：{activity.RightClicks}　中键：{activity.MiddleClicks}\n滚动：{activity.ScrollEvents}";}
}
