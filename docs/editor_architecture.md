# Editor architecture

The editor is a standalone Godot project. It does not copy Project Horn's
scripts, parse `.tres` text, or depend on the game's runtime scene tree.

## External project bridge

The UI process owns selection, browsing, inspector controls, dirty state,
undo/redo, and validation display. When the selected Project Root is another
Godot project, `resource_editor.gd` starts a short-lived headless Godot
process in that project and runs `project_horn_bridge.gd` there.

The bridge is the only process that loads and saves Project Horn custom
Resources. It uses `get_property_list()`, `ResourceLoader`, and
`ResourceSaver`, then returns JSON values to the standalone UI. This keeps
script dependencies and Resource subresources in the original project
context, so save/load remains a real Godot round trip.

## Registry and inspector

`RESOURCE_TYPES` is the explicit top-level type registry used by the UI.
The bridge has a matching registry for global IDs and reference validation.
The inspector is generated from exported property metadata and supports
primitive values, enums, vectors, rectangles, colors, arrays, nested
Resources, and Resource references. Legacy Dictionaries are displayed and
preserved but intentionally not edited until their schema is made explicit.

## Safety boundaries

- New and Duplicate only create an in-memory document; Save creates the file.
- Dirty actions require Save, Discard, or Cancel.
- Save is blocked for validation errors and detected external file changes.
- Delete is blocked when the bridge finds references to the target ID.
- External saves are restricted to the selected Project Root.
- Project Horn's current scripts do not yet expose the goal's proposed custom
  metadata contract, so reference fields use the current field-name registry
  as a temporary compatibility layer.
