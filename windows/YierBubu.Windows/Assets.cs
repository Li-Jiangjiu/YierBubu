using System.Security.Cryptography;
using System.Windows.Media.Imaging;
namespace YierBubu.Windows;

public sealed class Assets
{
    public BitmapSource Scene {get;}
    public BitmapSource Cleanplate {get;}
    public BitmapSource Paws {get;}
    public string Root {get;}
    public Assets(string? root=null)
    {
        Root=root??Path.Combine(AppContext.BaseDirectory,"Assets");
        Scene=Load("compact-scene.png","67cf9f967fe6bb3370dbaa1a6501e4f5a1705417c6e220e5648f1eed3a91abe7");
        Cleanplate=Load("compact-cleanplate.png","d9fb6272ef3f0b79ecee602f133a3c585110eab628389c9b1955a45d6b0995ba");
        Paws=Load("compact-paws.png","663d0edec1eb9b14781c1216f22b00b8a804a02852e0e7b261a257f16817c481");
    }
    private BitmapSource Load(string name,string hash)
    {
        string path=Path.Combine(Root,name);
        if(!File.Exists(path))throw new FileNotFoundException("动画资源缺失，请完整解压安装包后重试。",name);
        byte[] bytes=File.ReadAllBytes(path);
        if(!string.Equals(Convert.ToHexString(SHA256.HashData(bytes)),hash,StringComparison.OrdinalIgnoreCase))throw new InvalidDataException("动画资源校验失败，请重新下载安装包。");
        using var stream=new MemoryStream(bytes);
        var image=new BitmapImage();image.BeginInit();image.CacheOption=BitmapCacheOption.OnLoad;image.StreamSource=stream;image.EndInit();image.Freeze();
        if(image.PixelWidth!=1536||image.PixelHeight!=1024)throw new InvalidDataException("动画资源尺寸不正确。");
        return image;
    }
}
