using YierBubu.Core;

var tests = new List<(string, Action)>();
void Test(string name, Action body) => tests.Add((name, body));
void Check(bool condition, string message = "assertion failed") { if (!condition) throw new Exception(message); }
InputEvent Down(char key, bool repeat = false) => new(InputKind.KeyDown, Key: key, Repeat: repeat);
InputEvent Up(char key) => new(InputKind.KeyUp, Key: key);

Test("all 36 physical main keys map independently of text input", () => {
    (ushort scan, char key)[] expected = [(0x02,'1'),(0x03,'2'),(0x04,'3'),(0x05,'4'),(0x06,'5'),(0x07,'6'),(0x08,'7'),(0x09,'8'),(0x0a,'9'),(0x0b,'0'),(0x10,'q'),(0x11,'w'),(0x12,'e'),(0x13,'r'),(0x14,'t'),(0x15,'y'),(0x16,'u'),(0x17,'i'),(0x18,'o'),(0x19,'p'),(0x1e,'a'),(0x1f,'s'),(0x20,'d'),(0x21,'f'),(0x22,'g'),(0x23,'h'),(0x24,'j'),(0x25,'k'),(0x26,'l'),(0x2c,'z'),(0x2d,'x'),(0x2e,'c'),(0x2f,'v'),(0x30,'b'),(0x31,'n'),(0x32,'m')];
    foreach (var (scan,key) in expected) Check(ScanCodes.TryMap(scan,false,false,out var actual) && actual == key,$"scan {scan:x}");
});
Test("unknown extended media and numpad never impersonate main keys", () => {
    foreach(ushort scan in new ushort[]{0,0x39,0x3b,0x47,0x48,0x52,0x56,0xff}) Check(!ScanCodes.TryMap(scan,false,false,out _));
    Check(!ScanCodes.TryMap(0x10,true,false,out _)); Check(!ScanCodes.TryMap(0x1e,false,true,out _));
});
Test("normalizer detects autorepeat and accepts a fresh press after release", () => {
    var n = new KeyboardNormalizer();
    Check(!n.Normalize(0x1e,0).Repeat); Check(n.Normalize(0x1e,0).Repeat);
    Check(n.Normalize(0x1e,1).Kind == InputKind.KeyUp); Check(!n.Normalize(0x1e,0).Repeat);
    n.Reset(); Check(!n.Normalize(0x1e,0).Repeat);
});
Test("extended key release cannot release held main key", () => {
    var n=new KeyboardNormalizer(); n.Normalize(0x1e,0); n.Normalize(0x1e,3);
    Check(n.Normalize(0x1e,0).Repeat);
});
Test("quick tap remains visible for 100ms then expires", () => {
    var s=new InteractionState(0);s.Handle(Down('a'),0);s.Handle(Up('a'),0.01);
    Check(s.Snapshot(0.099).Keys.Contains('a')); Check(!s.Snapshot(0.101).Keys.Contains('a'));
});
Test("long hold survives minimum then releases immediately", () => {
    var s=new InteractionState(0);s.Handle(Down('a'),0);Check(s.Snapshot(20).Keys.Contains('a'));
    s.Handle(Up('a'),20);Check(s.Snapshot(20).Keys.Count==0);
});
Test("repeat events do not extend a released pulse", () => {
    var s=new InteractionState(0);s.Handle(Down('a'),0);s.Handle(Down('a',true),0.05);s.Handle(Up('a'),0.06);
    Check(s.Snapshot(0.11).Keys.Count==0);
});
Test("independent paws select latest held key in each half", () => {
    var s=new InteractionState(0);s.Handle(Down('a'),0);s.Handle(Down('s'),0.01);s.Handle(Down('j'),0.02);
    var f=s.Snapshot(0.05);Check(f.Keys.Count==3 && f.LeftKey=='s' && f.RightKey=='j');
    s.Handle(Up('s'),0.2);Check(s.Snapshot(0.2).LeftKey=='a');
});
Test("key and mouse feedback can coexist", () => {
    var s=new InteractionState(0);s.Handle(Down('a'),0);s.Handle(new(InputKind.MouseDown,Button:MouseButton.Left),0);
    var f=s.Snapshot(0.01);Check(f.Keys.Contains('a')&&f.Buttons.Contains(MouseButton.Left));
});
Test("mouse taps use 120ms minimum independently", () => {
    var s=new InteractionState(0);s.Handle(new(InputKind.MouseDown,Button:MouseButton.Right),0);
    s.Handle(new(InputKind.MouseUp,Button:MouseButton.Right),0.01);
    Check(s.Snapshot(0.119).Buttons.Contains(MouseButton.Right));Check(s.Snapshot(0.121).Buttons.Count==0);
});
Test("scroll pulse expires after 180ms and reversed direction replaces", () => {
    var s=new InteractionState(0);s.Handle(new(InputKind.Scroll,X:2,Y:4),0);s.Handle(new(InputKind.Scroll,Y:-1),0.01);
    var f=s.Snapshot(0.1);Check(f.ScrollX==2 && f.ScrollY==-1);Check(s.Snapshot(0.191).ScrollY==0);
});
Test("zero and nonfinite scroll never activate feedback", () => {
    var s=new InteractionState(0);s.Handle(new(InputKind.Scroll,Y:double.NaN),0);s.Handle(new(InputKind.Scroll,X:double.PositiveInfinity),0);s.Handle(new(InputKind.Scroll),0);
    var f=s.Snapshot(0);Check(f.ScrollX==0&&f.ScrollY==0);
});
Test("unknown key and orphan release cannot create action", () => {
    var s=new InteractionState(0);s.Handle(Down(' '),0);s.Handle(Up('a'),0);Check(s.Snapshot(0).Keys.Count==0);
});
Test("rest begins after 15 seconds only when idle", () => {
    var s=new InteractionState(0);Check(!s.Snapshot(14.9).Resting);Check(s.Snapshot(15).Resting);
    s.Handle(Down('a'),16);Check(!s.Snapshot(50).Resting);
});
Test("reset and clock rollback clear every held device", () => {
    var s=new InteractionState(10);s.Handle(Down('a'),10);s.Handle(new(InputKind.MouseDown),10);s.Handle(new(InputKind.Scroll,Y:3),10);
    var f=s.Snapshot(9);Check(f.Keys.Count==0&&f.Buttons.Count==0&&f.ScrollY==0);
    s.Handle(Down('s'),10);s.Reset(10);Check(s.Snapshot(10).Keys.Count==0);
});
Test("snapshot is a stable copy rather than mutable state", () => {
    var s=new InteractionState(0);s.Handle(Down('a'),0);var before=s.Snapshot(0);s.Reset(1);Check(before.Keys.Contains('a'));
});
Test("counts exclude repeats releases and invalid scrolling", () => {
    var a=new InputActivity();a.Record(Down('a'));a.Record(Down('a',true));a.Record(Up('a'));
    a.Record(new(InputKind.MouseDown,Button:MouseButton.Right));a.Record(new(InputKind.MouseUp,Button:MouseButton.Right));
    a.Record(new(InputKind.MouseDown,Button:MouseButton.Middle));a.Record(new(InputKind.Scroll,Y:1));a.Record(new(InputKind.Scroll,Y:double.NaN));
    Check(a.KeyPresses==1&&a.RightClicks==1&&a.MiddleClicks==1&&a.LeftClicks==0&&a.ScrollEvents==1);
});

Test("all scene keys have unique labels and consistent paw halves", () => {
    Check(SceneLayout.Keys.Count==36&&SceneLayout.Keys.Select(k=>k.Label).Distinct().Count()==36);
    Check(SceneLayout.Key('a')!.LeftPaw&&!SceneLayout.Key('j')!.LeftPaw);
    Check(SceneLayout.Key(' ') is null);
});
foreach(var label in "1234567890qwertyuiopasdfghjklzxcvbnm") {
    char key=label;
    Test($"paw tip lands on key {key} top", () => {
        var k=SceneLayout.Key(key)!;var pose=PawPose.Typing(key)!;
        Check(k.ContainsSurface(pose.Tip,true),$"{key} fingertip outside top");
        Check(Math.Abs(pose.Tip.X-pose.Contact.X)<0.0001&&Math.Abs(pose.Tip.Y-pose.Contact.Y)<0.0001);
    });
}
Test("mouse left is lower right from Bubu perspective", () => {
    var left=SceneLayout.MouseContact(MouseButton.Left);var right=SceneLayout.MouseContact(MouseButton.Right);
    Check(left.X==324&&left.Y==622&&right.X==255&&right.Y==592);
    Check(SceneLayout.MouseContains(left,MouseButton.Left)&&!SceneLayout.MouseContains(left,MouseButton.Right));
    Check(SceneLayout.MouseContains(right,MouseButton.Right)&&!SceneLayout.MouseContains(right,MouseButton.Left));
});
Test("rapid retarget starts at current visible pose", () => {
    var motion=new PawMotion(PawPose.Idle(true));motion.Retarget(PawPose.Typing('a')!,0);
    var before=motion.Pose(0.025);motion.Retarget(PawPose.Typing('t')!,0.025);
    Check(motion.Pose(0.025)==before);Check(motion.Pose(0.101)==PawPose.Typing('t'));
});
Test("motion settles in 75ms and idle returns to zero rotation", () => {
    var motion=new PawMotion(PawPose.Typing('a')!);motion.Retarget(PawPose.Idle(true),1);
    Check(motion.IsAnimating(1.074));Check(!motion.IsAnimating(1.076));Check(motion.Pose(1.076).Angle==0);
});
Test("mouse mixed buttons and scrolling choose wheel pose", () => {
    Check(PawPose.Mouse(new HashSet<MouseButton>{MouseButton.Left,MouseButton.Right},false).Contact==new Point2(280,601));
    Check(PawPose.Mouse(new HashSet<MouseButton>{MouseButton.Left},true).Contact==new Point2(280,601));
});
Test("negative coordinate monitor placement uses its own work area", () => {
    var p=WindowPlacement.BottomRight(new Rect2(-1920,0,1920,1080),300,200,24);
    Check(p.X==-324&&p.Y==856);
});
Test("offscreen and oversized windows are brought into work area", () => {
    var p=WindowPlacement.Clamp(new Point2(9000,-9000),new Rect2(-1920,-100,1920,1000),300,200);
    Check(p.X==-300&&p.Y==-100);
    Check(WindowPlacement.BottomRight(new Rect2(0,0,200,100),300,200,24)==new Point2(0,0));
});

Test("raw keyboard packet uses physical scan and release flags", () => {
    var n=new KeyboardNormalizer();var b=new byte[40];System.Buffers.Binary.BinaryPrimitives.WriteUInt32LittleEndian(b,1);System.Buffers.Binary.BinaryPrimitives.WriteUInt32LittleEndian(b.AsSpan(4),40);b[24]=0x1e;b[30]=65;
    Check(RawInputDecoder.Decode(b,n).Single().Key=='a');b[26]=1;Check(RawInputDecoder.Decode(b,n).Single().Kind==InputKind.KeyUp);
});
Test("raw mouse packet separates right and middle transitions", () => {
    var b=new byte[48];System.Buffers.Binary.BinaryPrimitives.WriteUInt32LittleEndian(b.AsSpan(4),48);b[28]=0x14;
    var events=RawInputDecoder.Decode(b,new());Check(events.Count==2&&events[0].Button==MouseButton.Right&&events[1].Button==MouseButton.Middle);
});
Test("raw wheel data is signed and horizontal has its own axis", () => {
    var b=new byte[48];System.Buffers.Binary.BinaryPrimitives.WriteUInt32LittleEndian(b.AsSpan(4),48);b[29]=8;b[30]=0x88;b[31]=0xff;
    var e=RawInputDecoder.Decode(b,new()).Single();Check(e.Kind==InputKind.Scroll&&e.X==-1&&e.Y==0);
});
Test("truncated malformed and overrun packets are ignored", () => {
    Check(RawInputDecoder.Decode(new byte[3],new()).Count==0);var b=new byte[40];b[0]=1;b[4]=40;b[24]=0xff;b[30]=65;
    Check(RawInputDecoder.Decode(b,new()).Count==0);b[24]=0x1e;b[4]=99;Check(RawInputDecoder.Decode(b,new()).Count==0);
});

int failed=0;
foreach(var (name,body) in tests) { try { body();Console.WriteLine($"PASS {name}"); } catch(Exception e) { failed++;Console.WriteLine($"FAIL {name}: {e.Message}"); } }
Console.WriteLine($"{tests.Count-failed}/{tests.Count} passed");
return failed==0 ? 0 : 1;
