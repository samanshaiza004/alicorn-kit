# Command Palette

`alikit:command_palette` provides a themed modal palette, while
`alikit:palette_model` contains the filtering and selection rules without a UI
dependency.

## Application-owned items

Each item has a nonzero, unique `Item_ID` that remains stable for the palette
session. The ID is a scalar, so activation does not return a borrowed string or
an index into a temporary filtered list. `title`, `description`, and
`keywords` are borrowed only during `build` or `handle_key`; the application
can rebuild its item slice between turns.

The application supplies items in its preferred order. The model filters that
order and does not impose application-specific recency, category, or scoring
policy. Every whitespace-separated query token must occur as a contiguous
substring in a title, description, or keyword. ASCII letters compare without
case; non-ASCII UTF-8 bytes compare exactly. Locale-aware matching and Unicode
case folding are outside this first version's contract.

Disabled items remain visible but cannot be selected or activated. Selection
is retained by item ID while that item remains visible and enabled. If it
vanishes, becomes disabled, or stops matching, selection moves to the first
enabled result.

## Owning the component state

Zero-initialize one `State` for each palette instance and initialize it with the
allocator that should own its query and cached match buffer:

```odin
palette: command_palette.State
if !command_palette.init(&palette) {
    // Handle allocation failure.
}
defer command_palette.destroy(&palette)
```

Call `open_palette` from the application command that opens the palette. It
captures the current focused node, clears the query, and requests a redraw.

## Native host integration

The palette uses Alicorn's public `Application` callbacks because the simple
`ui.run` helper does not expose application-level key and text callbacks. The
application keeps its existing callback policy and calls the component helpers
from those callbacks:

```odin
on_key :: proc(data: rawptr, rt: ^alicorn.Runtime, key: host.Application_Key) -> bool {
    app := cast(^App)data
    if !app.palette.open && key == .Open_Command_Palette {
        _ = command_palette.open_palette(&app.palette, rt)
        return true
    }
    handled, event := command_palette.handle_key(&app.palette, rt, app.palette_items[:], key)
    if event.kind == .Activated { app.dispatch(event.item_id) }
    return handled
}

on_text_change :: proc(data: rawptr, rt: ^alicorn.Runtime, change: alicorn.Text_Change) {
    app := cast(^App)data
    _ = command_palette.text_change(&app.palette, rt, change)
}
```

Pass a fresh item slice to `handle_key`. It filters against the current query
and current application data, so a fast key event cannot activate an action
from a stale item snapshot. The text-change callback's `change.text` is borrowed
for the callback only; AliKit copies it into its owned controlled-text buffer.

Describe the ordinary root first. Then call `command_palette.build` while the
frame is open, and call `command_palette.after_frame` after `alicorn.end_frame`.
The returned activation event contains a stable ID. Keep dispatch in the
application so it can apply its own mutation and error policy. For pointer
outside-dismissal, forward application pointer events to
`command_palette.pointer`. The example shows the complete wiring.

The palette declines Up, Down, and Return while Alicorn reports active IME
composition in its query field, allowing the native text host to handle those
keys. When composition is inactive, the palette consumes Up, Down, Return,
Escape, and its toggle key while open; unrelated keys continue through the
host application's policy.
The modal overlay retains Alicorn's normal focus scope, semantics, hit testing,
and accessibility behavior.

## UI-independent model

The model package can be used independently to filter and navigate a command
list. Allocate an output buffer with capacity for the complete item slice,
call `palette_model.filter`, then pass its initialized prefix to `reconcile`,
`move`, or `activate`. The model borrows item strings and stores only indexes
and stable IDs.

## Compatibility and dependencies

The package is source-level Odin and imports Alicorn's `runtime`, `ui`, and
`native/sdl_gpu` collections. The palette does not access Alicorn private
runtime storage. The host adapter is intentionally native because it uses
Alicorn's cross-platform `Application_Key` vocabulary and native application
callbacks. Other AliKit packages can remain independent of the native host.
