# Architecture

NPC TalkKit keeps conversation content, runtime playback, presentation, and
editor tooling separate.

Dependency direction:

```text
Resources <- Core services <- Runtime
          <- Validator      <- Editor
          <- Serializer

Runtime -> TalkBoxRenderer contract -> built-in or custom dialogue box
```

A box's look is data: a `TalkBoxTemplate` and its `TalkBoxLayer`s. The renderer
draws a layer on whichever control it returns for the layer's slot (Panel,
Speaker Name, Dialogue Visual), so the built-in box and a custom renderer
receive the same layers. Layers draw native `StyleBox` and `Texture2D`
resources; there is no TalkKit-specific asset format.

Tools that read or write TalkKit content should go through `TalkKitDatabase`,
`TalkKitSerializer`, and `TalkValidator` rather than implementing their own
storage or validation.

Host games remain authoritative. TalkKit requests player lock, facing, or camera
focus through signals and never requires a specific player controller, quest
system, or NPC base class.
