# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Context & Learning Philosophy

This is **Nik's learning project** for Neovim plugin development. The focus is on understanding concepts through hands-on implementation rather than just completing features. Nik writes the code, Claude provides guidance and explanations of the "why" behind decisions.

radar.nvim is a file navigation plugin: a Lock HUD at the bottom of the active pane and `<space>` prefix keys for locks, recent files and the alternative file, a Tab HUD, and locks and recent files persisted per project and branch.

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
│   ├── state.lua         -- Global state (locks, recent files, window handles)
│   ├── locks.lua         -- Lock add/remove/toggle/relabel
│   ├── recent.lua        -- Recent files (session files + persisted history + vim.v.oldfiles)
│   ├── alternative.lua   -- Alternative file (e.g., test ↔ impl)
│   └── tabs.lua          -- Tab/buffer data gathering (NOT UI)
├── persist/
│   ├── persistence.lua   -- Read, write, load, persist, populate
│   ├── migration.lua     -- Data format migration (v0 → v1 → v2)
│   └── cleanup.lua       -- Stale persistence data removal (:RadarCleanup)
└── ui/
    ├── keys.lua          -- Global keymaps (prefix dispatch, tabs toggle)
    ├── hud.lua           -- HUD: content builder + one float per tabpage, anchored to the active pane
    ├── navigation.lua    -- File opening (current window/vertical/horizontal/tab/float)
    ├── help.lua          -- Help popup
    ├── edit.lua          -- Lock label editor
    ├── tabs.lua          -- Tabs view (tab/buffer tree)
    ├── window.lua        -- Window preset definitions and config resolution
    ├── file_float.lua    -- Floating file view (`<C-f>` in the lock editor)
    └── indicators.lua    -- Shared git/LSP indicator utilities
```

`path.lua` helpers: `is_url`, `git_info`, `git_branch`, `project_root`, `to_absolute`, `to_lock_path`, `display`.

### Key Architectural Patterns

- **Context-Aware Persistence**: `{version, projects = {[project_root] = {[git_branch] = {locks = [...], recent = [...], lastAccessed = timestamp}}}}`. Data without `recent` loads as an empty history.
- **Project Identity**: The project is the git root containing the cwd (the worktree root inside a worktree), or the cwd outside git. The persistence key is that root abbreviated with `~`.
- **Root-Relative Lock Paths**: Lock filenames are relative to the project root when inside it, absolute otherwise. URLs stay unchanged. `path.to_lock_path` and `path.to_absolute` convert. The persisted `recent` list uses the same form.
- **Recent History**: `recent` is a per-branch MRU list, most recent first, capped at `recent.max_files`. `populate` loads it into `state` as absolute paths (missing files dropped). When `BufEnter` makes a new file the most recent, `persistence.recent_snapshot()` (this session's files inside the root, no locks, so the saved locks stay) is persisted after `persist.defer_ms`; `persist` merges them in front of the saved list. `recent.get_files` lists session files, then the history, then `vim.v.oldfiles`.
- **Data Versioning**: Persistence data is versioned (currently v2). `migration.migrate` upgrades v0 → v1 → v2 on load.
- **Safe Persistence**: Writes go to a tmp file that is renamed over the target (atomic). A corrupt data file is moved to `data.json.bad`. An unreadable file is never overwritten. JSON is encoded in Lua with a fixed key order, no external tools.
- **No Branch, No Persistence**: Detached HEAD and non-git directories keep locks in memory only, as long as the project root stays the same. One warning per session.
- **Lock HUD**: `ui/hud.lua` keeps one non-focusable float and scratch buffer per tabpage, anchored (`relative = "win"`) to the bottom of the active pane and as wide as it; while a float has focus it stays on the previous pane. `hud.build` is a pure content builder (lines + highlight ranges); `hud.refresh()` rebuilds and shows or hides the current tab's Lock HUD and runs on lock changes, populate, Tab HUD and lock editor open and close, `BufEnter`, `TabEnter`, `WinEnter`, `WinResized`, `VimResized`, `DirChanged`, `FocusGained` and `VimEnter`. `hud.dodge()` only repositions on `CursorMoved`, `CursorMovedI` and `WinScrolled`: the Lock HUD moves to the top of its pane while the cursor line runs under it.
- **Lock Editor**: `ui/edit.lua` opens a focusable float anchored (`relative = "win"`) to the bottom of the active pane, as wide as it, `border = "none"`, above the Lock HUD, which hides while the editor is open. `<CR>`, `<C-v>`, `<C-s>`, `<C-t>` and `<C-f>` save and open the file under the cursor through `ui/navigation.lua`.
- **Prefix Dispatch**: The global `keys.prefix` mapping reads one key with `vim.fn.getcharstr()` and dispatches: lock and recent labels jump in the current window, `keys.alternative` (`o`) opens the alternative file, `keys.lock` locks the current buffer, `keys.hud_toggle` toggles the Lock HUD, `keys.edit` opens the lock editor, `keys.help` shows a help popup for these keys (`prefix_help_section` in `ui/keys.lua`), anything else (the prefix included) cancels.
- **Relabel by Position**: Lock labels come from the position in `config.keys.locks`. Removing a lock and loading persisted locks both relabel.
- **Safe String Matching**: Uses `string.find(text, pattern, 1, true)` for literal matching (critical for special chars)
- **Dynamic Highlighting**: Extmarks, refreshed on `BufEnter`
- **Safe Nested Access**: `vim.tbl_get()` for nested persistence data, validation before operations
- **Type Safety**: Separate type definitions in `config.types.lua`, implementation in `config.lua`

### Architectural Decisions

1. **Config Separation**
   - `config.types.lua` = types only (no values)
   - `config.lua` = single source of truth for all values

2. **Window Presets**
   - A preset name (e.g. `"center"`) or a full table, resolved by `window.resolve_config`
   - Presets: cursor, center, center_large, center_narrow, top_left, top_right, bottom_left, bottom_right, bottom_center, full_height_sidebar
   - Used by: file_float (`file_float.win_preset`); the Lock HUD, the lock editor and the Tab HUD sit at the bottom of the active pane via `window.pane_bottom`
   - Custom presets go in `config.win_presets`

3. **Tab HUD**
   - Toggled via `keys.tabs_toggle` (default `<leader>t`)
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

The snapshot pins project, branch, locks and this session's recent files at toggle or `BufEnter` time, so a `:cd` or branch switch within the delay cannot save them under the wrong key.

**Why**: Batches rapid changes, prevents excessive I/O during active editing.

### 5. Window Preset Resolution Pattern

```lua
local win_opts = window.resolve_config(config, preset_name, overrides)
```

**Why**: Allows flexible configuration - simple presets for common cases, full customization when needed.

### 6. Populate on Context Change

`persistence.populate` loads locks and the recent history for the current project and branch into state, dropping missing files. `populate_if_changed` runs on `DirChanged`, `FocusGained` and before a lock toggle, and reloads only when the project root or branch differs from the last populate. Populating refreshes the Lock HUD.

## Spatial Design & Keybinding Layout

From [docs/concept.md](docs/concept.md):

```
<space> then:
[1][2][3][4][5][6][7][8][9]  ← Locks (files you lock)
[a][s][d][f][g]              ← Recent files (per project and branch)
[o]                          ← Alternative file (test ↔ impl)
```

**Implemented:**

- Locks (1-9 keys)
- Recent files (a-g keys, filtered by project root)
- Alternative file (`<space>o`)
- Lock HUD (`<space>h` toggles it)
- Lock editor (`<space>e`)
- Prefix help (`<space>?`)
- Tab HUD

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
- **Recent Files**: MRU history per project root + git branch, filled up from `vim.v.oldfiles` (a-g keys)
- **Alternative Files**: Smart test ↔ implementation file switching (`<space>o`)
- **Lock HUD**: Always-visible float at the bottom of the active pane with the alternative file, up to `hud.max_locks` locks and `hud.max_recent` recent files; dodges the cursor, hides while the Tab HUD or the lock editor is open
- **Tab HUD**: Tab/buffer tree view with jump and close support
- **Label Editing**: Customize lock labels in an editor at the bottom of the active pane (`<space>e`; supports protocol URLs)
- **Context Persistence**: Saves locks and recent files per project root + git branch with data versioning
- **Help Popup**: `<space>?`, built from the configured keys
- **Data Cleanup**: `:RadarCleanup` command removes entries for deleted branches/projects
- **Path Display**: Paths shown relative to the project root

### Known Limitations

- **Detached HEAD and non-git folders**: Locks and recent files live in memory only. Persistence needs a branch.

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
- **[lua/radar/ui/hud.lua](lua/radar/ui/hud.lua)**: Lock HUD content and rendering
- **[lua/radar/ui/keys.lua](lua/radar/ui/keys.lua)**: Prefix dispatch
- **[lua/radar/ui/tabs.lua](lua/radar/ui/tabs.lua)**: Tab HUD UI
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
