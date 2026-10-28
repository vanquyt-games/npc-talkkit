using System;
using Godot;

// Godot.Collections is referenced by full name: its Array and Dictionary
// collide with the System types (CS0104).
using GodotArray = Godot.Collections.Array;
using GodotDictionary = Godot.Collections.Dictionary;

namespace NpcTalkKit
{
    /// <summary>
    /// A typed C# face for the GDScript <c>NPCTalkKit</c> node.
    /// </summary>
    /// <remarks>
    /// <para>
    /// C# cannot reference a GDScript <c>class_name</c> as a type; this wraps the
    /// untyped <c>Call("play", ...)</c> calls behind typed methods and events.
    /// </para>
    /// <para>
    /// Store the instance in a field. It derives from <see cref="RefCounted"/>,
    /// and its signal connections keep your handlers alive.
    /// </para>
    /// </remarks>
    public partial class TalkKit : RefCounted
    {
        private readonly Node _node;

        /// <summary>Fires when a non-blocking line event is reached.</summary>
        public event Action<StringName, Variant> EventTriggered;

        /// <summary>
        /// Fires when playback has <b>paused</b> on a blocking line. Answer with
        /// <see cref="Resume"/>, <see cref="Stop"/>, or <see cref="Play"/>.
        /// </summary>
        public event Action<StringName, Variant> EventBlocked;

        /// <summary>Asks your game to lock or release the player.</summary>
        public event Action<bool> PlayerLockRequested;

        public event Action<StringName> ConversationStarted;
        public event Action<StringName> ConversationFinished;
        public event Action<StringName> ConversationCancelled;

        /// <summary>Wraps an existing NPCTalkKit node.</summary>
        public TalkKit(Node talkKitNode)
        {
            _node = talkKitNode ?? throw new ArgumentNullException(nameof(talkKitNode));
            Connect("event_triggered", Callable.From<StringName, Variant>(OnEventTriggered));
            Connect("event_blocked", Callable.From<StringName, Variant>(OnEventBlocked));
            Connect("request_player_lock", Callable.From<bool>(OnPlayerLock));
            Connect("conversation_started", Callable.From<StringName>(OnStarted));
            Connect("conversation_finished", Callable.From<StringName>(OnFinished));
            Connect("conversation_cancelled", Callable.From<StringName>(OnCancelled));
        }

        /// <summary>
        /// Finds the NPCTalkKit child of <paramref name="owner"/> and wraps it.
        /// </summary>
        public static TalkKit Of(Node owner, string path = "NPCTalkKit")
        {
            Node found = owner.GetNodeOrNull<Node>(path);
            return found == null ? null : new TalkKit(found);
        }

        /// <summary>The wrapped node, for anything this class does not cover.</summary>
        public Node Node => _node;

        /// <summary>
        /// Plays a conversation by name. Returns false when the name is unknown,
        /// the content fails validation, or a conversation is already running.
        /// Allowed while blocked, to branch.
        /// </summary>
        public bool Play(string name, GodotDictionary parameters = null)
        {
            return parameters == null
                ? _node.Call("play", name).AsBool()
                : _node.Call("play", name, parameters).AsBool();
        }

        /// <summary>Speaks a line without an authored conversation.</summary>
        public bool Say(string line, GodotDictionary parameters = null)
        {
            return parameters == null
                ? _node.Call("say", line).AsBool()
                : _node.Call("say", line, parameters).AsBool();
        }

        /// <summary>Speaks several lines in order.</summary>
        public bool Say(string[] lines, GodotDictionary parameters = null)
        {
            var array = new GodotArray();
            foreach (string line in lines)
            {
                array.Add(line);
            }

            return parameters == null
                ? _node.Call("say", array).AsBool()
                : _node.Call("say", array, parameters).AsBool();
        }

        /// <summary>Finishes the current line, or moves to the next one.</summary>
        public void Advance() => _node.Call("advance");

        /// <summary>Continues playback after a blocking event.</summary>
        public void Resume() => _node.Call("resume");

        /// <summary>Ends the conversation and releases the player lock.</summary>
        public void Stop() => _node.Call("stop");

        public bool IsRunning => _node.Call("is_running").AsBool();

        public bool IsBlocked => _node.Call("is_blocked").AsBool();

        /// <summary>Every conversation this NPC can play.</summary>
        public StringName[] ListConversations()
        {
            var names = _node.Call("list_conversations").AsGodotArray();
            var result = new StringName[names.Count];
            for (int i = 0; i < names.Count; i++)
            {
                result[i] = names[i].AsStringName();
            }

            return result;
        }

        /// <summary>Builds a one-entry params dictionary for Play and Say.</summary>
        public static GodotDictionary Params(string key, Variant value)
        {
            return new GodotDictionary { { key, value } };
        }

        private void Connect(StringName signal, Callable callable)
        {
            Error error = _node.Connect(signal, callable);
            if (error != Error.Ok)
            {
                GD.PushWarning($"TalkKit could not connect '{signal}': {error}");
            }
        }

        private void OnEventTriggered(StringName id, Variant payload) =>
            EventTriggered?.Invoke(id, payload);

        private void OnEventBlocked(StringName id, Variant payload) =>
            EventBlocked?.Invoke(id, payload);

        private void OnPlayerLock(bool locked) => PlayerLockRequested?.Invoke(locked);

        private void OnStarted(StringName id) => ConversationStarted?.Invoke(id);

        private void OnFinished(StringName id) => ConversationFinished?.Invoke(id);

        private void OnCancelled(StringName id) => ConversationCancelled?.Invoke(id);
    }
}
