# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Context & Learning Philosophy

This is **Nik's learning project** for Neovim plugin development. The focus is on understanding concepts through hands-on implementation rather than just completing features. Nik writes the code, Claude provides guidance and explanations of the "why" behind decisions.

### Evolution: pins.lua → radar.nvim

- **Origin**: Started as a simple file pinning system (`pins.lua`)
- **Current State**: Fully modular file navigation system with locks, recent files, alternative file support
- **Vision**: Comprehensive file navigation inspired by fighter pilot radar displays
- **Learning Focus**: Understanding Neovim API patterns, Lua module systems, dynamic UI management

## Architecture Overview

### Current Modular Structure (Production Ready)

The codebase has evolved into a clean modular architecture:

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
├── keys.lua              -- Keybinding setup
├── autocmd.lua           -- Autocommand setup
├── api.lua               -- Public API functions
├── window.lua            -- Window config resolution
├── win_presets.lua       -- Window positioning presets (center, top_right, etc.)
└── ui/
    ├── mini_radar.lua    -- Mini radar floating window UI
    └── edit.lua          -- Lock label editor UI
```

### Key Architectural Patterns

- **Context-Aware Persistence**: `{[project_path][git_branch] = {locks: [...]}}`
- **Safe String Matching**: Uses `string.find(text, pattern, 1, true)` for literal matching (critical for special chars)
- **Dynamic Highlighting**: Extmarks with `BufEnter` autocmd for automatic updates
- **Robust Error Handling**: `vim.tbl_get()` for safe nested access, validation before operations
- **Window Preset System**: String presets like `"center"` resolve to full window configs via `win_presets.lua`
- **Type Safety**: Separate type definitions in `config.types.lua`, implementation in `config.lua`

### Recent Architectural Decisions

1. **Config Separation** (Latest)
   - Split type definitions from implementation
   - `config.types.lua` = types only (no values)
   - `config.lua` = single source of truth for all values
   - Resolved duplicate config bug where types file had different values

2. **Window Preset System**
   - Replaced hardcoded window configs with preset system
   - Users can specify `"center"` instead of full table
   - Presets available: center, cursor, top_right, bottom_center, full_height_sidebar
   - Supports override syntax: `{ "preset_name", { width = 100 } }`

3. **Modular Refactor**
   - Evolved from monolithic `init.lua` to clean module separation
   - Each concern (locks, recent, alternative, UI) in dedicated file
   - Maintained backward compatibility through careful API design

4. **Removed Mode Config**
   - Eliminated `mode = "float_top_right"` from config
   - Window positioning now handled purely through preset system
   - Simpler mental model: window presets control positioning

## Key Technical Patterns

### 1. Critical String Safety Pattern

```lua
-- ALWAYS use literal matching for filenames with special characters
if line:find(formatted_filepath, 1, true) then
```

**Why**: Prevents crashes with filenames containing `$`, `*`, `(`, `)`, etc.

### 2. Window/Buffer Lifecycle Management

```lua
function M:does_pin_board_exist()
    return self.state.pin_board_win and vim.api.nvim_win_is_valid(self.state.pin_board_win)
end
```

**Pattern**: Always validate handles before use in dynamic environments.

### 3. Safe Nested Table Access

```lua
local persisted_pins = vim.tbl_get(data, project_path, git_branch, "pins")
```

**Why**: Avoids nil errors when navigating nested persistence data.

### 4. Deferred Persistence for Performance

```lua
vim.defer_fn(function()
    self:persist()
end, 500)
```

**Why**: Batches rapid changes, prevents excessive I/O during active editing.

### 5. Window Preset Resolution Pattern

```lua
-- Config can be a string preset or tuple with overrides
config = "center"  -- Simple preset
config = { "center", { width = 100, height = 20 } }  -- Preset + overrides

-- Resolution happens in window.lua
local win_opts = window.resolve_config(config, opts)
```

**Why**: Allows flexible configuration - simple presets for common cases, full customization when needed.

## Radar.nvim Vision & Spatial Design

### File Categories & Keybinding Layout

From [docs/concept.md](docs/concept.md) - spatial keyboard layout for instant-access files:

```
[1][2][3][4][5][6][7][8][9]  ← Locks (manually locked targets)
[a][s][d][f][g]              ← Recent files (vim.v.oldfiles)
o                             ← Alternative file (test ↔ impl)
```

**Currently Implemented:**
- ✅ Locks (1-9 keys)
- ✅ Recent files (a-g keys, filtered by cwd)
- ✅ Alternative file (o key, detects test/impl pairs)

**Future Extensions:**
- Modified files (git status)
- PR files (branch changes)

### Navigation Modes

**Current:** Mini Radar only (persistent floating window)
- Displays locks, recent files, and alternative file
- Keybindings: `<space>1-9`, `<space>a-g`, `<space>o`
- Line-based navigation: `<CR>`, `V`, `S`, `T`, `F` for different split modes

**Future:** Full Radar
- Comprehensive tactical display (all categories)
- Enhanced navigation with arrow keys

## Development Patterns

### Plugin Structure

- **`plugin/radar.lua`**: Auto-load file for immediate setup (guard against double-loading)
- **`lua/radar/init.lua`**: Main module with `setup()` function for Lazy.nvim integration
- **Configuration**: Uses `vim.tbl_deep_extend("force", M.config, opts)` pattern

### Setup Function Pattern

```lua
function M.setup(opts)  -- NOT M:setup(opts)
    opts = opts or {}
    M.config = vim.tbl_deep_extend("force", M.config, opts)
    -- Initialize keymaps, autocmds, populate data
end
```

**Why**: Plugin managers call `M.setup(opts)` directly, not with colon syntax.

### Learning Areas Successfully Mastered

- ✅ **Extmarks System**: Namespace management, dynamic highlighting, safe clearing
- ✅ **Floating Windows**: Configuration, positioning, content management
- ✅ **Persistence**: JSON encoding/decoding with error handling
- ✅ **Autocmd Management**: Group creation, callback functions, event handling
- ✅ **Modular Architecture**: Clean separation of concerns across multiple modules
- ✅ **Type System**: Lua Language Server annotations with separate type definitions
- ✅ **Window Presets**: Flexible configuration with preset resolution system
- ✅ **Navigation System**: Multiple file opening modes (vertical/horizontal/tab/float)

## Current State & Roadmap

### ✅ Implemented Features

- **Locks (Pins)**: Manual file pinning system with 1-9 keybindings
- **Recent Files**: MRU list filtered by current working directory (a-g keys)
- **Alternative Files**: Smart test ↔ implementation file switching (o key)
- **Line Navigation**: Navigate within radar using `<CR>`, `V`, `S`, `T`, `F`
- **Label Editing**: Customize lock labels via floating editor
- **Context Persistence**: Saves locks per project + git branch
- **Mini Radar UI**: Persistent floating window with dynamic highlighting

### 🚧 Known Limitations

- **Non-git Folders**: Persistence system requires git for branch context
- **Single View Mode**: Only mini radar implemented (full radar planned)

### 🎯 Future Work (v1+)

- **Modified Files**: Git integration for uncommitted changes
- **PR Files**: Branch-specific file changes
- **Full Radar Mode**: Comprehensive view with arrow key navigation
- **Non-git Support**: Fallback persistence strategy for non-git projects

## Configuration Architecture

### Current Structure (lua/radar/config.lua)

```lua
M.default = {
  keys = {
    prefix = "<space>",
    lock = "l",
    locks = { "1", "2", "3", "4", "5", "6", "7", "8", "9" },
    alternative = "<space>",
    recent = { "a", "s", "d", "f", "g" },
    vertical = "<C-v>",
    horizontal = "<C-s>",
    tab = "<C-t>",
    float = "<C-f>",
    line = {
      open = "<CR>",
      vertical = "V",
      horizontal = "S",
      tab = "T",
      float = "F",
    },
  },

  persist = {
    path = vim.fs.joinpath(vim.fn.stdpath("data"), "radar", "data.json"),
    defer_ms = 500,
  },

  -- Window presets - users can override or add custom presets
  win_presets = {},

  -- Main radar window
  radar = {
    win_preset = "center",
    width = 75,
    winblend = 0,
    max_recent_files = 20,
    show_empty_message = true,
    path_format = ":p:.",
    titles = {
      main = "󰐷  RADAR",
      locks = "󰋱  LOCKED IN",
      alternative = "  OTHER",
      recent = "󰽏  NEAR",
    },
  },

  -- Lock label editor window
  radar_edit = {
    win_preset = "cursor",
    width_padding = 10,
    max_height = 20,
    min_width = 60,
  },

  -- File float window
  file_float = {
    win_preset = "center",
  },
}
```

### Window Preset System

**Base presets** are defined in `lua/radar/window.lua` (implementation detail). Users can customize presets in the config:

**Simple override (table merge)**:
```lua
win_presets = {
  center = { width = 100 }  -- Merges with base center preset
}
```

**Custom preset (function)**:
```lua
win_presets = {
  my_preset = function(config)
    return {
      relative = "editor",
      width = 100,
      height = 20,
      row = math.floor((vim.o.lines - 20) / 2),
      col = math.floor((vim.o.columns - 100) / 2),
      border = "rounded",
      style = "minimal",
      title = config.radar.titles.main,
      title_pos = "center",
      focusable = true,
      zindex = 100,
    }
  end
}

radar = {
  win_preset = "my_preset"  -- Use your custom preset
}
```

**Available base presets**:
- `"center"` - Centered floating window (75x10)
- `"center_large"` - Large centered window (80% width, 70% height)
- `"cursor"` - Window appears at cursor position
- `"top_right"` - Top-right corner
- `"bottom_center"` - Bottom center
- `"full_height_sidebar"` - Full-height sidebar on right

### Type Definitions (lua/radar/config.types.lua)

**IMPORTANT:** This file contains ONLY type annotations, no implementation. All actual values live in `config.lua`.

## Important Files

- **[.claude/CLAUDE_HANDOVER.md](.claude/CLAUDE_HANDOVER.md)**: Technical evolution notes and solved challenges
- **[docs/concept.md](docs/concept.md)**: Comprehensive design vision and philosophy
- **[lua/radar/init.lua](lua/radar/init.lua)**: Plugin entry point (calls setup on modules)
- **[lua/radar/config.lua](lua/radar/config.lua)**: Single source of truth for configuration values
- **[lua/radar/config.types.lua](lua/radar/config.types.lua)**: Type definitions only (no implementation)
- **[lua/radar/ui/mini_radar.lua](lua/radar/ui/mini_radar.lua)**: Main UI rendering logic
- **[lua/radar/locks.lua](lua/radar/locks.lua)**: Lock/pin management
- **[lua/radar/recent.lua](lua/radar/recent.lua)**: Recent file tracking
- **[lua/radar/alternative.lua](lua/radar/alternative.lua)**: Alternative file detection (test ↔ impl)

## Development Approach

### Learning-First Philosophy

- **Experiment first**, then ask for explanations of observed behavior
- **Ask specific questions** rather than "how do I implement X"
- **Break down complex features** into smaller learning steps
- **Focus on understanding patterns** that apply beyond this specific plugin

### Code Quality Principles

- **Preserve working code** - the current pins implementation is production-ready
- **Additive development** - expand functionality without breaking existing features
- **Safe operations** - always validate before API calls
- **Clear error messages** - help users understand what went wrong
