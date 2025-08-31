# radar.nvim - Handover

## Project Evolution

This started as a learning project for Neovim plugin development (`pins.lua`) and has evolved into `radar.nvim` - a comprehensive file navigation system inspired by fighter pilot radar displays.

## Current State

The existing codebase successfully implements:

- **Pin Management**: Add/remove/toggle pins for files (1-9 keybindings)
- **Floating Window UI**: Clean display with highlighting for active file
- **Context-Aware Persistence**: Saves pins per project + git branch
  - Currently does not handle non-git folders
- **Safe Navigation**: Handles special characters in filenames, nil checks for nested data
- **Auto-highlighting**: BufEnter autocmd updates highlights automatically

### Key Technical Decisions Made

1. **String Matching**: Use `string.find(text, pattern, 1, true)` for literal matching (avoids pattern issues with special chars like `$`)
2. **Persistence Structure**: Nested tables `{[project_path][git_branch] = {pins = [...]}}`
3. **Safe Indexing**: `vim.tbl_get()` for safe nested table access
4. **Module Loading**: Local modules via `package.path` modification for plugin structure

## radar.nvim Vision

### Core Concept

See [concept](../docs/concept.md)

### Implementation Plan for v1

#### Recent Files Implementation

```lua
function M:get_recent_files()
    -- Use vim.v.oldfiles (Neovim's built-in MRU list)
    -- 1. Filter by current working directory (vim.fn.getcwd())
    -- 2. Check file exists (vim.fn.filereadable())
    -- 3. Deduplicate against pinned files
    -- 4. Limit to 5 files (for a,s,d,f,g keys)
end
```

### Technical Challenges Solved

1. **Nested Table Navigation**: Use `vim.tbl_get()` for safe access
2. **Pattern Matching Issues**: Use literal string matching with `true` flag
3. **Window Height Management**: Check `#entries > 0` before creating windows
4. **Module Organization**: Local requires work with `package.path` modification

### New project structure

Create new repository structure:

```
radar.nvim/
├── lua/
│   └── radar/
│       ├── init.lua      -- Entry point with setup()
│       ├── pins.lua      -- Current pins functionality
│       ├── recent.lua    -- Recent files logic
│       ├── ui.lua        -- Radar view rendering
│       └── persistence.lua
└── plugin/
    └── radar.lua          -- Auto-load file
```

### Learning Notes

This has been Nik's learning project for understanding:

- Neovim's buffer/window management
- Extmarks for highlighting
- Lua patterns and module systems
- Persistence and state management
- Safe error handling in dynamic environments

Remember: This is a learning-first project. Nik writes the code, Claude provides guidance and explanations. Focus on understanding the "why" behind decisions, not just implementing features. If Nik directly asks you to write code, then you can do it.

### Current Working State

The pins functionality is fully working with:

- Context-aware persistence (project + branch)
- Dynamic highlighting of active file
- Clean floating window UI
- Proper error handling
- Not handling non-git folders
