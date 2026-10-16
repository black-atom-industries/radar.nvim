# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Context & Learning Philosophy

This is **Nik's learning project** for Neovim plugin development. The focus is on understanding concepts through hands-on implementation rather than just completing features. Nik writes the code, Claude provides guidance and explanations of the "why" behind decisions.

radar.nvim is a file navigation system inspired by fighter pilot radar displays: one floating radar window with locks, recent files and an alternative file, a tabs sidebar, and locks persisted per project and branch.

## Architecture Overview

### Modular Structure

```
lua/radar/
├── init.lua              -- Entry point with setup(), :RadarCleanup
├── config.lua            -- Default configuration values (single source of truth)
├── config.types.lua      -- Type definitions only (no implementation)
├── autocmd.lua           -- Autocommand setup
├── path.lua              -- Path and git helpers (see below)
├── utils.lua             -- Utility functions (project sorting)
├── debug.lua             -- Buffered debug logging, gated by config.debug
├── data/
│   ├── state.lua         -- Global state (locks, recent files, window handles, line map)
│   ├── locks.lua         -- Lock add/remove/toggle/relabel
│   ├── recent.lua        -- Recent files (vim.v.oldfiles + session files)
│   ├── alternative.lua   -- Alternative file (e.g., test ↔ impl)
│   └── tabs.lua          -- Tab/buffer data gathering (NOT UI)
├── persist/
│   ├── persistence.lua   -- Read, write, load, persist, populate
│   ├── migration.lua     -- Data format migration (v0 → v1 → v2)
│   └── cleanup.lua       -- Stale persistence data removal (:RadarCleanup)
└── ui/
    ├── radar.lua         -- Radar window: build content, render, focus, help
    ├── keys.lua          -- Keymaps (global prefix dispatch + radar buffer-local)
    ├── hud.lua           -- Corner HUD: content builder + one float per tabpage
    ├── navigation.lua    -- File opening (current window/vertical/horizontal/tab/float)
    ├── help.lua          -- Help popup
    ├── edit.lua          -- Lock label editor
    ├── tabs.lua          -- Tabs sidebar (tab/buffer tree)
    ├── window.lua        -- Window preset definitions and config resolution
    ├── file_float.lua    -- Floating file view
    └── indicators.lua    -- Shared git/LSP indicator utilities
```

`path.lua` helpers: `is_url`, `git_info`, `git_branch`, `project_root`, `to_absolute`, `to_lock_path`, `display`.

### Key Architectural Patterns

- **Context-Aware Persistence**: `{version, projects = {[project_root] = {[git_branch] = {locks = [...], lastAccessed = timestamp}}}}`
- **Project Identity**: The project is the git root containing the cwd (the worktree root inside a worktree), or the cwd outside git. The persistence key is that root abbreviated with `~`.
- **Root-Relative Lock Paths**: Lock filenames are relative to the project root when inside it, absolute otherwise. URLs stay unchanged. `path.to_lock_path` and `path.to_absolute` convert.
- **Data Versioning**: Persistence data is versioned (currently v2). `migration.migrate` upgrades v0 → v1 → v2 on load.
- **Safe Persistence**: Writes go to a tmp file that is renamed over the target (atomic). A corrupt data file is moved to `data.json.bad`. An unreadable file is never overwritten. JSON is encoded in Lua with a fixed key order, no external tools.
- **No Branch, No Persistence**: Detached HEAD and non-git directories keep locks in memory only, as long as the project root stays the same. One warning per session.
- **Single Radar Window**: One floating window and buffer holding the alternative, locks and recent sections. `ui/radar.lua` renders it in place and stores a line → entry map in `state`, which navigation and the lock key read.
- **Corner HUD**: `ui/hud.lua` keeps one non-focusable float and scratch buffer per tabpage, top-right below the tabline. `hud.build` is a pure content builder (lines + highlight ranges); `hud.refresh()` rebuilds and shows or hides the current tab's HUD and runs on lock changes, populate, radar/tabs open and close, `BufEnter`, `TabEnter`, `VimResized`, `DirChanged`, `FocusGained` and `VimEnter`. `hud.dodge()` only repositions (bottom-right while the cursor is under the top-right spot) on `CursorMoved`, `CursorMovedI` and `WinScrolled`.
- **Prefix Dispatch**: The global `keys.prefix` mapping reads one key with `vim.fn.getcharstr()` and dispatches: lock and recent labels jump, prefix opens the radar, `keys.alternative` (`o`) opens the alternative file, `keys.lock` locks the current buffer, `keys.hud_toggle` toggles the HUD, anything else cancels. Split variants exist only inside the radar.
- **Relabel by Position**: Lock labels come from the position in `config.keys.locks`. Removing a lock and loading persisted locks both relabel.
- **Safe String Matching**: Uses `string.find(text, pattern, 1, true)` for literal matching (critical for special chars)
- **Dynamic Highlighting**: Extmarks, refreshed on `BufEnter`
- **Safe Nested Access**: `vim.tbl_get()` for nested persistence data, validation before operations
- **Type Safety**: Separate type definitions in `config.types.lua`, implementation in `config.lua`

### Architectural Decisions

1. **Radar Layout**
   - Sections top to bottom: alternative file, locks, recent files
   - Placement via `config.radar.win_preset`, size via `config.radar.size`
   - `<Tab>`/`<S-Tab>` cycles the cursor between sections
   - `keys.alternative` (default `o`) opens the alternative file, the prefix closes the radar

2. **Config Separation**
   - `config.types.lua` = types only (no values)
   - `config.lua` = single source of truth for all values

3. **Window Presets**
   - A preset name (e.g. `"center"`) or a full table, resolved by `window.resolve_config`
   - Presets: cursor, center, center_large, center_narrow, top_left, top_right, bottom_left, bottom_right, bottom_center, full_height_sidebar
   - Used by: radar (`radar.win_preset`), radar_edit, file_float, tabs
   - Custom presets go in `config.win_presets`

4. **Tabs Sidebar**
   - Separate from the radar, toggled via `keys.tabs_toggle` (default `<leader>t`) or `t` inside the radar
   - Shows all open tabs with their buffers in a tree structure
   - Supports jumping to tab/buffer and closing buffers/tabs (`x` key)

## Key Technical Patterns

### 1. Critical String Safety Pattern

```lua
-- ALWAYS use literal matching for filenames with special characters
if line:find(formatted_filepath, 1, true) then
```

**Why**: Prevents crashes with filenames containing `$`, `*`, `(`, `)`, etc.

### 2. Window/Buffer Lifecycle Management

Always validate handles before use in dynamic environments.

### 3. Safe Nested Table Access

```lua
local locks = vim.tbl_get(data, "projects", project_path, git_branch, "locks")
```

**Why**: Avoids nil errors when navigating nested persistence data.

### 4. Deferred Persistence for Performance

```lua
local snapshot = persistence.snapshot()
vim.defer_fn(function()
    persistence.persist(config, snapshot)
end, config.persist.defer_ms)
```

The snapshot pins project, branch and locks at toggle time, so a `:cd` or branch switch within the delay cannot save them under the wrong key.

**Why**: Batches rapid changes, prevents excessive I/O during active editing.

### 5. Window Preset Resolution Pattern

```lua
local win_opts = window.resolve_config(config, preset_name, overrides)
```

**Why**: Allows flexible configuration - simple presets for common cases, full customization when needed.

### 6. Populate on Context Change

`persistence.populate` loads locks for the current project and branch into state. `populate_if_changed` runs on `DirChanged`, `FocusGained` and before a lock toggle, and reloads only when the project root or branch differs from the last populate. Populating re-renders an open radar and refreshes the HUD.

## Spatial Design & Keybinding Layout

From [docs/concept.md](docs/concept.md):

```
<space> then:
[1][2][3][4][5][6][7][8][9]  ← Locks (manually locked targets)
[a][s][d][f][g]              ← Recent files (vim.v.oldfiles)
[o]                          ← Alternative file (test ↔ impl, also inside the radar)
[<space>]                    ← Full radar
```

**Implemented:**

- Locks (1-9 keys)
- Recent files (a-g keys, filtered by project root)
- Alternative file (`<space>o`, `o` inside the radar)
- Corner HUD (`<space>h` toggles it)
- Tabs sidebar

**Planned (tracked in GitHub Issues):**

- Modified files (git status) - #6
- PR files (branch changes) - #7

## Development Patterns

### Plugin Structure

- **`plugin/radar.lua`**: Auto-load file for immediate setup (guard against double-loading)
- **`lua/radar/init.lua`**: Main module with `setup()` function for Lazy.nvim integration
- **Configuration**: Uses `vim.tbl_deep_extend("force", defaults, opts)` pattern

### Setup Function Pattern

```lua
function M.setup(opts)  -- NOT M:setup(opts)
    opts = opts or {}
    config = vim.tbl_deep_extend("force", require("radar.config").default, opts)
    -- Initialize autocmds, keymaps, populate persistence data
end
```

**Why**: Plugin managers call `M.setup(opts)` directly, not with colon syntax.

## Implemented Features

- **Locks**: Manual file locking with 1-9 keybindings
- **Recent Files**: MRU list filtered by project root (a-g keys)
- **Alternative Files**: Smart test ↔ implementation file switching (`<space>o`, `o` inside the radar)
- **Corner HUD**: Always-visible top-right float with the alternative file, up to `hud.max_locks` locks and `hud.max_recent` recent files; dodges the cursor, hides while the radar or tabs sidebar is open
- **Radar Window**: One floating window with three sections and section cycling
- **Tabs Sidebar**: Tab/buffer tree view with jump and close support
- **Line Navigation**: Navigate within radar using `<CR>`, `V`, `S`, `T`, `F`
- **Label Editing**: Customize lock labels via floating editor (supports protocol URLs)
- **Context Persistence**: Saves locks per project root + git branch with data versioning
- **Help Popup**: `?` in the radar, built from the configured keys
- **Data Cleanup**: `:RadarCleanup` command removes entries for deleted branches/projects
- **Path Display**: Paths shown relative to the project root

### Known Limitations

- **Detached HEAD and non-git folders**: Locks live in memory only. Persistence needs a branch.

## Issue Tracking

All future work is tracked in [GitHub Issues](https://github.com/black-atom-industries/radar.nvim/issues). See `/bai/status` or filter by label.

## Configuration

- **Defaults**: [`lua/radar/config.lua`](lua/radar/config.lua) - single source of truth for all default values
- **Types**: [`lua/radar/config.types.lua`](lua/radar/config.types.lua) - type annotations only, no implementation

**IMPORTANT:** When modifying config, always update `config.lua` for values and `config.types.lua` for types. Keep them in sync.

## Important Files

- **[docs/concept.md](docs/concept.md)**: Comprehensive design vision and philosophy
- **[lua/radar/init.lua](lua/radar/init.lua)**: Plugin entry point (calls setup on modules)
- **[lua/radar/config.lua](lua/radar/config.lua)**: Single source of truth for configuration values
- **[lua/radar/config.types.lua](lua/radar/config.types.lua)**: Type definitions only (no implementation)
- **[lua/radar/ui/radar.lua](lua/radar/ui/radar.lua)**: Radar window rendering logic
- **[lua/radar/ui/tabs.lua](lua/radar/ui/tabs.lua)**: Tabs sidebar UI
- **[lua/radar/data/locks.lua](lua/radar/data/locks.lua)**: Lock management
- **[lua/radar/data/recent.lua](lua/radar/data/recent.lua)**: Recent file tracking
- **[lua/radar/data/alternative.lua](lua/radar/data/alternative.lua)**: Alternative file detection (test ↔ impl)
- **[lua/radar/persist/persistence.lua](lua/radar/persist/persistence.lua)**: Load, persist, populate
- **[lua/radar/persist/cleanup.lua](lua/radar/persist/cleanup.lua)**: Stale data cleanup logic
- **[lua/radar/persist/migration.lua](lua/radar/persist/migration.lua)**: Data format versioning and migration

## Development Approach

### Learning-First Philosophy

- **Experiment first**, then ask for explanations of observed behavior
- **Ask specific questions** rather than "how do I implement X"
- **Break down complex features** into smaller learning steps
- **Focus on understanding patterns** that apply beyond this specific plugin

### Code Quality Principles

- **Preserve working code** - the current implementation is production-ready
- **Additive development** - expand functionality without breaking existing features
- **Safe operations** - always validate before API calls
- **Clear error messages** - help users understand what went wrong
