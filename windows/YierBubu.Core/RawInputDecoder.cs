using System.Buffers.Binary;
namespace YierBubu.Core;

/// Decodes the documented x64 RAWINPUT layout, not characters or text messages.
public static class RawInputDecoder
{
    public static IReadOnlyList<InputEvent> Decode(ReadOnlySpan<byte> data,KeyboardNormalizer keyboard)
    {
        var result=new List<InputEvent>();
        if(data.Length<24)return result;
        uint kind=BinaryPrimitives.ReadUInt32LittleEndian(data),size=BinaryPrimitives.ReadUInt32LittleEndian(data[4..]);
        if(size>data.Length||size<24)return result;
        if(kind==1&&size>=40){
            ushort scan=BinaryPrimitives.ReadUInt16LittleEndian(data[24..]),flags=BinaryPrimitives.ReadUInt16LittleEndian(data[26..]),virtualKey=BinaryPrimitives.ReadUInt16LittleEndian(data[30..]);
            if(scan==0||scan==0xff||virtualKey>=0xff)return result;
            result.Add(keyboard.Normalize(scan,flags));
        } else if(kind==0&&size>=48){
            ushort flags=BinaryPrimitives.ReadUInt16LittleEndian(data[28..]);
            short delta=BinaryPrimitives.ReadInt16LittleEndian(data[30..]);
            (int Down,int Up,MouseButton Button)[] masks=[(1,2,MouseButton.Left),(4,8,MouseButton.Right),(16,32,MouseButton.Middle)];
            foreach(var b in masks){if((flags&b.Down)!=0)result.Add(new(InputKind.MouseDown,Button:b.Button));if((flags&b.Up)!=0)result.Add(new(InputKind.MouseUp,Button:b.Button));}
            if((flags&0x400)!=0)result.Add(new(InputKind.Scroll,Y:delta/120.0));
            if((flags&0x800)!=0)result.Add(new(InputKind.Scroll,X:delta/120.0));
        }
        return result;
    }
}
