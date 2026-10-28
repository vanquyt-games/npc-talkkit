# C# wrapper

`TalkKit.cs` is a typed face for the GDScript `NPCTalkKit` node, so your game
is not littered with `Call("play", ...)`.

```csharp
using NpcTalkKit;

public partial class Blacksmith : Node2D
{
    private TalkKit _talk;   // keep the field: it holds the signal connections

    public override void _Ready()
    {
        _talk = TalkKit.Of(this);
        _talk.EventBlocked += OnBlocked;
        _talk.PlayerLockRequested += locked => SetPlayerLocked(locked);
    }

    public void Interact()
    {
        if (!_talk.IsRunning)
            _talk.Play("greeting", TalkKit.Params("player_name", "Alex"));
    }

    private void OnBlocked(StringName id, Variant payload)
    {
        if (id == "offer_job")
            _talk.Play(PlayerAccepts() ? "accepted" : "declined");
    }
}
```

## Compatibility

Verified on **Godot 4.7.2 .NET** with **.NET SDK 8.0.425**.

In a standard (non-.NET) Godot build this folder is inert: a `.cs` file has no
importer there, so it is ignored without errors or warnings.

## Scope

Conversations, speakers, dialogue boxes, placements and transitions are
authored in the editor and never cross into C#. This wrapper covers starting
conversations and reacting to signals.
