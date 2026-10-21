namespace YierBubu.Core;
public sealed record InteractionSnapshot(IReadOnlySet<char> Keys, IReadOnlySet<MouseButton> Buttons, double ScrollX=0, double ScrollY=0, char? LeftKey=null, char? RightKey=null, bool Resting=false)
{
    public static InteractionSnapshot Empty => new(new HashSet<char>(),new HashSet<MouseButton>());
}
public sealed class InteractionState
{
    public InteractionState(double now) { _=now; }
    public void Handle(InputEvent input,double time) => throw new NotImplementedException();
    public InteractionSnapshot Snapshot(double time) => throw new NotImplementedException();
    public void Reset(double time) => throw new NotImplementedException();
}
