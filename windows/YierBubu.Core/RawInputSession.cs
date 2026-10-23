using System.Buffers.Binary;
namespace YierBubu.Core;

/// Per-device repeat detection, with logical holds aggregated across keyboards/mice.
/// Device handles and held inputs live only for the current process/session.
public sealed class RawInputSession
{
    private sealed class Device
    {
        public readonly KeyboardNormalizer Keyboard=new();
        public readonly HashSet<char> Keys=[];
        public readonly HashSet<MouseButton> Buttons=[];
    }
    private readonly Dictionary<ulong,Device> devices=[];
    public IReadOnlyList<InputEvent> Decode(ReadOnlySpan<byte> packet)
    {
        if(packet.Length<24)return Array.Empty<InputEvent>();
        uint size=BinaryPrimitives.ReadUInt32LittleEndian(packet[4..]),kind=BinaryPrimitives.ReadUInt32LittleEndian(packet);
        if(size>packet.Length||(kind==0&&size<48)||(kind==1&&size<40)||kind>1)return Array.Empty<InputEvent>();
        ulong handle=BinaryPrimitives.ReadUInt64LittleEndian(packet[8..]);
        if(!devices.TryGetValue(handle,out var device)){device=new();devices.Add(handle,device);}
        var result=new List<InputEvent>();
        foreach(var input in RawInputDecoder.Decode(packet,device.Keyboard)){
            if(input.Kind==InputKind.KeyDown&&input.Key!='\0'){if(!input.Repeat)device.Keys.Add(input.Key);}
            else if(input.Kind==InputKind.KeyUp&&input.Key!='\0'){
                device.Keys.Remove(input.Key);
                if(devices.Values.Any(d=>d.Keys.Contains(input.Key)))continue;
            } else if(input.Kind==InputKind.MouseDown){
                if(!device.Buttons.Add(input.Button))continue;
            } else if(input.Kind==InputKind.MouseUp){
                device.Buttons.Remove(input.Button);
                if(devices.Values.Any(d=>d.Buttons.Contains(input.Button)))continue;
            }
            result.Add(input);
        }
        return result;
    }
    public void Reset()=>devices.Clear();
}
