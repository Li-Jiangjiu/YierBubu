namespace YierBubu.Core;

public enum InputKind { KeyDown, KeyUp, MouseDown, MouseUp, Scroll }
public enum MouseButton { Left, Right, Middle }
public readonly record struct InputEvent(InputKind Kind, char Key='\0', MouseButton Button=MouseButton.Left, double X=0, double Y=0, bool Repeat=false);

public static class ScanCodes
{
    public const string VisibleKeys="1234567890qwertyuiopasdfghjklzxcvbnm";
    public const string LeftKeys="12345qwertasdfgzxcvb";
    public static bool TryMap(ushort code, bool e0, bool e1, out char key) => throw new NotImplementedException();
}
public sealed class KeyboardNormalizer
{
    public InputEvent Normalize(ushort scan, ushort flags) => throw new NotImplementedException();
    public void Reset() => throw new NotImplementedException();
}
public sealed class InputActivity
{
    public long KeyPresses {get;private set;}
    public long LeftClicks {get;private set;}
    public long RightClicks {get;private set;}
    public long MiddleClicks {get;private set;}
    public long ScrollEvents {get;private set;}
    public void Record(InputEvent input) => throw new NotImplementedException();
}
