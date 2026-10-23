namespace YierBubu.Core;

public enum InputKind { KeyDown, KeyUp, MouseDown, MouseUp, Scroll }
public enum MouseButton { Left, Right, Middle }
public readonly record struct InputEvent(InputKind Kind, char Key='\0', MouseButton Button=MouseButton.Left, double X=0, double Y=0, bool Repeat=false);

public static class ScanCodes
{
    public const string VisibleKeys="1234567890qwertyuiopasdfghjklzxcvbnm";
    public const string LeftKeys="12345qwertasdfgzxcvb";
    public static bool TryMap(ushort code,bool e0,bool e1,out char key)
    {
        key='\0';if(e0||e1)return false;
        key=code switch {
            >=0x02 and <=0x0b => "1234567890"[code-0x02],
            >=0x10 and <=0x19 => "qwertyuiop"[code-0x10],
            >=0x1e and <=0x26 => "asdfghjkl"[code-0x1e],
            >=0x2c and <=0x32 => "zxcvbnm"[code-0x2c], _ => '\0'};
        return key!='\0';
    }
}
/// Keeps only current physical keys, including invisible modifiers, for repeat detection.
public sealed class KeyboardNormalizer
{
    private readonly HashSet<int> held=[];
    public InputEvent Normalize(ushort scan,ushort flags)
    {
        int token=scan|((flags&6)<<16);
        ScanCodes.TryMap(scan,(flags&2)!=0,(flags&4)!=0,out var key);
        if((flags&1)!=0){held.Remove(token);return new(InputKind.KeyUp,Key:key);}
        bool repeat=!held.Add(token);
        return new(InputKind.KeyDown,Key:key,Repeat:repeat);
    }
    public void Reset()=>held.Clear();
}
public sealed class InputActivity
{
    public long KeyPresses {get;private set;}
    public long LeftClicks {get;private set;}
    public long RightClicks {get;private set;}
    public long MiddleClicks {get;private set;}
    public long ScrollEvents {get;private set;}
    public void Record(InputEvent input)
    {
        switch(input.Kind){
            case InputKind.KeyDown when !input.Repeat:KeyPresses++;break;
            case InputKind.MouseDown:
                switch(input.Button){case MouseButton.Left:LeftClicks++;break;case MouseButton.Right:RightClicks++;break;case MouseButton.Middle:MiddleClicks++;break;}break;
            case InputKind.Scroll when double.IsFinite(input.X)&&double.IsFinite(input.Y)&&(input.X!=0||input.Y!=0):ScrollEvents++;break;
        }
    }
}
