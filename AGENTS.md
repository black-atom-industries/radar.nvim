# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Context & Learning Philosophy

This is **Nik's learning project** for Neovim plugin development. The focus is on understanding concepts through hands-on implementation rather than just completing features. Nik writes the code, Claude provides guidance and explanations of the "why" behind decisions.

### Evolution: pins.lua → radar.nvim

- **Origin**: Started as a simple file pinning system (`pins.lua`)
- **Current State**: Fully modular file navigation system with grid-based radar display, tab sidebar, locks, recent files, and alternative file support
- **Vision**: Comprehensive file navigation inspired by fighter pilot radar displays
- **Learning Focus**: Understanding Neovim API patterns, Lua module systems, dynamic UI management

## Architecture Overview

### Modular Structure

```
lua/radar/
├── init.lua              -- Entry point with setup()
├── config.lua            -- Default configuration values (single source of truth)
├── config.types.lua      -- Type definitions only (no implementation)
├── state.lua             -- Global state management
├── locks.lua             -- File locking/pinning functionality
├── recent.lua            -- Recent files logic (vim.v.oldfiles)
├── alternative.lua       -- Alternative file switching (e.g., test ↔ impl)
├── persistence.lua       -- Save/load locks per project+branch
├── navigation.lua        -- File opening logic (vertical/horizontal/tab/float)
├── keys.lua              -- Keybinding setup (global + buffer-local per section)
├── autocmd.lua           -- Autocommand setup
├── api.lua               -- Public API functions
├── window.lua            -- Window config resolution & preset definitions
├── tabs.lua              -- Tab/buffer data gathering (NOT UI)
├── cleanup.lua           -- Stale persistence data removal (:RadarCleanup)
├── migration.lua         -- Data format migration (v0 → v1)
├── utils.lua             -- Utility functions (project sorting)
└── ui/
    ├── radar.lua         -- Main radar grid UI (3-section layout)
    ├── tabs.lua          -- Tabs sidebar UI (tab/buffer tree)
    ├── edit.lua          -- Lock label editor UI
    └── path.lua          -- Path shortening utility
```

### Key Architectural Patterns

- **Context-Aware Persistence**: `{[project_path][git_branch] = {locks: [...], lastAccessed: timestamp}}`
- **Data Versioning**: Persistence data is versioned (currently v1), with automatic migration from older formats
- **Grid Layout System**: Radar uses a 3-section grid (alternative top, locks bottom-left, recent bottom-right) with position-based placement
- **Safe String Matching**: Uses `string.find(text, pattern, 1, true)` for literal matching (critical for special chars)
- **Dynamic Highlighting**: Extmarks with `BufEnter` autocmd for automatic updates
- **Robust Error Handling**: `vim.tbl_get()` for safe nested access, validation before operations
- **Window Preset System**: Used for secondary windows (edit, file_float, tabs). The main radar grid uses its own position system.
- **Type Safety**: Separate type definitions in `config.types.lua`, implementation in `config.lua`

### Architectural Decisions

1. **Grid-Based Radar Layout**
   - Main radar is a multi-window grid: alternative file (top), locks (bottom-left), recent files (bottom-right)
   - Positioned via `config.radar.position` (center, top_left, top_right, bottom_left, bottom_right)
   - Each section has its own buffer with section-specific keymaps
   - `<Tab>`/`<S-Tab>` cycles focus between sections

2. **Config Separation**
   - `config.types.lua` = types only (no values)
   - `config.lua` = single source of truth for all values
   - Resolved duplicate config bug where types file had different values

3. **Window Preset System** (for secondary windows)
   - Users can specify `"center"` instead of full table
   - Presets available: center, center_large, cursor, top_right, bottom_center, full_height_sidebar
   - Used by: radar_edit, file_float, tabs windows
   - **Note**: The main radar grid does NOT use presets - it uses `config.radar.position` directly

4. **Tabs Sidebar**
   - Separate from the main radar - toggled independently via `<leader>t`
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
local persisted_pins = vim.tbl_get(data, project_path, git_branch, "pins")
```

**Why**: Avoids nil errors when navigating nested persistence data.

### 4. Deferred Persistence for Performance

```lua
vim.defer_fn(function()
    persistence.save(config)
end, config.persist.defer_ms)
```

**Why**: Batches rapid changes, prevents excessive I/O during active editing.

### 5. Window Preset Resolution Pattern

```lua
-- For secondary windows (edit, file_float, tabs)
local win_opts = window.resolve_config(preset_name, config)
```

**Why**: Allows flexible configuration - simple presets for common cases, full customization when needed.

## Spatial Design & Keybinding Layout

From [docs/concept.md](docs/concept.md):

```
[1][2][3][4][5][6][7][8][9]  ← Locks (manually locked targets)
[a][s][d][f][g]              ← Recent files (vim.v.oldfiles)
[<space>]                    ← Alternative file (test ↔ impl, double-tap prefix)
```

**Implemented:**

- Locks (1-9 keys)
- Recent files (a-g keys, filtered by cwd)
- Alternative file (double-tap prefix key, detects test/impl pairs)
- Tabs sidebar (`<leader>t`, separate view)

**Planned (tracked in Linear):**

- Modified files (git status) - DEV-260
- PR files (branch changes) - DEV-261

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

- **Locks**: Manual file pinning system with 1-9 keybindings
- **Recent Files**: MRU list filtered by current working directory (a-g keys)
- **Alternative Files**: Smart test ↔ implementation file switching (double-tap prefix)
- **Grid Radar UI**: 3-section grid layout with section cycling
- **Tabs Sidebar**: Tab/buffer tree view with jump and close support
- **Line Navigation**: Navigate within radar using `<CR>`, `V`, `S`, `T`, `F`
- **Label Editing**: Customize lock labels via floating editor (supports protocol URLs)
- **Context Persistence**: Saves locks per project + git branch with data versioning
- **Data Cleanup**: `:RadarCleanup` command removes entries for deleted branches/projects
- **Path Shortening**: Smart path display that fits within available width

### Known Limitations

- **Non-git Folders**: Persistence system requires git for branch context

## Issue Tracking

All future work is tracked in **Linear** (Black Atom Industries workspace) with the `radar.nvim` label. See `/bai/status` or filter by label in Linear.

## Configuration

- **Defaults**: [`lua/radar/config.lua`](lua/radar/config.lua) - single source of truth for all default values
- **Types**: [`lua/radar/config.types.lua`](lua/radar/config.types.lua) - type annotations only, no implementation

**IMPORTANT:** When modifying config, always update `config.lua` for values and `config.types.lua` for types. Keep them in sync.

## Important Files

- **[docs/concept.md](docs/concept.md)**: Comprehensive design vision and philosophy
- **[lua/radar/init.lua](lua/radar/init.lua)**: Plugin entry point (calls setup on modules)
- **[lua/radar/config.lua](lua/radar/config.lua)**: Single source of truth for configuration values
- **[lua/radar/config.types.lua](lua/radar/config.types.lua)**: Type definitions only (no implementation)
- **[lua/radar/ui/radar.lua](lua/radar/ui/radar.lua)**: Main grid UI rendering logic
- **[lua/radar/ui/tabs.lua](lua/radar/ui/tabs.lua)**: Tabs sidebar UI
- **[lua/radar/locks.lua](lua/radar/locks.lua)**: Lock/pin management
- **[lua/radar/recent.lua](lua/radar/recent.lua)**: Recent file tracking
- **[lua/radar/alternative.lua](lua/radar/alternative.lua)**: Alternative file detection (test ↔ impl)
- **[lua/radar/cleanup.lua](lua/radar/cleanup.lua)**: Stale data cleanup logic
- **[lua/radar/migration.lua](lua/radar/migration.lua)**: Data format versioning and migration

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
