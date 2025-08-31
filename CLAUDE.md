# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Context & Learning Philosophy

This is **Nik's learning project** for Neovim plugin development. The focus is on understanding concepts through hands-on implementation rather than just completing features. Nik writes the code, Claude provides guidance and explanations of the "why" behind decisions.

### Evolution: pins.lua → radar.nvim

- **Current State**: Fully functional file pinning system with sophisticated persistence and UI management
- **Vision**: Comprehensive file navigation system inspired by fighter pilot radar displays
- **Learning Focus**: Understanding Neovim API patterns, Lua module systems, and dynamic UI management

## Architecture Overview

### Current Implementation (Production Ready)

All functionality lives in `lua/radar/init.lua` (430+ lines) - a monolithic but well-architected implementation that demonstrates:

- **Context-Aware Persistence**: `{[project_path][git_branch] = {pins: [...]}}`
- **Safe String Matching**: Uses `string.find(text, pattern, 1, true)` for literal matching (critical for special chars)
- **Dynamic Highlighting**: Extmarks with `BufEnter` autocmd for automatic updates
- **Robust Error Handling**: `vim.tbl_get()` for safe nested access, validation before operations

### Future Modular Structure (Planned)

```
lua/radar/
├── init.lua      -- Entry point with setup()
├── pins.lua      -- Current pins functionality
├── recent.lua    -- Recent files logic (vim.v.oldfiles)
├── ui.lua        -- Radar view rendering
└── persistence.lua
```

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

## Radar.nvim Vision & Spatial Design

### File Categories & Keybinding Layout

From [docs/concept.md](docs/concept.md) - spatial keyboard layout for 24 instant-access files:

```
[1][2][3][4][5][6][7][8][9]  ← Pins (manually locked targets)
[q][w][e][r][t]              ← Modified files (git status)
[a][s][d][f][g]              ← Recent files (vim.v.oldfiles)
[z][x][c][v][b]              ← PR files (branch changes)
```

### Dual Navigation Modes

- **Mini Radar**: Persistent floating window (pins only)
- **Full Radar**: Comprehensive tactical display (all categories)

### Deduplication Strategy

Pinned files are filtered out of other sections - each file appears only once, prioritizing manual pins over automatic categorization.

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

- **Extmarks System**: Namespace management, dynamic highlighting, safe clearing
- **Floating Windows**: Configuration, positioning, content management
- **Persistence**: JSON encoding/decoding with error handling
- **Autocmd Management**: Group creation, callback functions, event handling

## Known Limitations & Future Work

### Current Limitations

- **Non-git Folders**: Persistence system requires git branches for context
- **Monolithic Structure**: All code in single file (by design for learning)

### v1 Implementation Plan

- **Recent Files**: Filter `vim.v.oldfiles` by current working directory
- **Modified Files**: Git integration for uncommitted changes
- **PR Files**: Branch-specific file changes
- **Navigation Mode**: Arrow key navigation between radar sections

## Configuration Architecture

### Current Structure

```lua
M.config = {
    board = {        -- UI appearance and behavior
        pin_labels = { "1", "2", ... },
        win = { ... }  -- vim.api.keyset.win_config
    },
    persist = {      -- Data persistence settings
        path = vim.fs.joinpath(vim.fn.stdpath("data"), "pins")
    },
    mappings = {     -- Keybinding configuration
        pin = "<space><space>",
        jump = "<space>"
    }
}
```

### Future Configuration (from concept.md)

```lua
require('radar').setup({
    keys = { ... },        -- Spatial keyboard customization
    behaviour = {          -- Deduplication, persistence settings
        deduplicate = true,
        persist_pins = true
    },
    appearance = {         -- Mini vs full radar configs
        mini = { display = "static", preset = "float_top_right" }
    }
})
```

## Important Files

- **[.claude/CLAUDE_HANDOVER.md](.claude/CLAUDE_HANDOVER.md)**: Technical evolution notes and solved challenges
- **[docs/concept.md](docs/concept.md)**: Comprehensive design vision and philosophy
- **[lua/radar/init.lua](lua/radar/init.lua)**: Complete current implementation

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
