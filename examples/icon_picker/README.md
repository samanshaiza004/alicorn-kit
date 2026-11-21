# Icon Picker example

This is the complete consumer for `icon_picker`, a copyable custom composite
built only on public Alicorn APIs. The example imports the package by relative
path, so the pair builds outside AliKit's collection layout:

```powershell
odin build examples/icon_picker -collection:alicorn=/path/to/alicorn
```

Press **Insert icon…** to open the dialog. Type to search, use arrows to rove
the grid or list, and press Enter to accept. **Ctrl+F** focuses the search field
from anywhere in the dialog (the application-authored interaction); **Ctrl+2**
switches between the compact grid and the list-with-labels. **Escape**,
**Close**, or an outside click dismisses the dialog and restores the opener.

The dialog also opens a nested **Shortcut details** overlay to show that the
picker is not a modal owner: the application owns dismissal, nesting, and focus
restoration.

Run `--smoke` for a single native SDL_GPU frame and an idle check.

Source:

- [`main.odin`](main.odin) — dialog host, Escape/outside/nested handling,
  application Ctrl+F, appearance toggle.
- [`../../icon_picker/icon_picker.odin`](../../icon_picker/icon_picker.odin) —
  the complete copyable composite.
- [Icon picker guide](../../docs/icon-picker.md) — named parts, behavior,
  copy-and-change notes, tests, and limits.
