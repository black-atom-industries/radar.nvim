# Grid-Based Radar Implementation Plan

## Progress Tracker

- [ ] Phase 1: Configuration Schema
- [ ] Phase 2: State Management
- [ ] Phase 3: Grid Layout System
- [ ] Phase 4: Alternative Section Window
- [ ] Phase 5: Locks Section Window
- [ ] Phase 6: Recent Section Window
- [ ] Phase 7: Hints Overlay Window
- [ ] Phase 8: Window Lifecycle Management
- [ ] Phase 9: Focus & Navigation
- [ ] Phase 10: Integration & Testing
- [ ] Phase 11: Cleanup

---

## Overview

This plan refactors radar.nvim from a single floating window to a multi-window grid layout with 4 separate windows:

1. **Alternative** (top, full width, non-focusable indicator)
2. **Locks** (bottom-left, focusable)
3. **Recent** (bottom-right, focusable)
4. **Hints** (bottom, full width, non-focusable overlay)

The refactor removes the entire existing `lua/radar/ui/radar.lua` implementation and replaces it with a new grid-based system. All existing keybindings (1-9, a-g, o, CR, V, S, T, F) remain functional. Tab/Shift-Tab will cycle focus between Locks and Recent sections.

---

## Architecture Changes

### Current Architecture (Single Window)
```lua
-- State tracks one window
state.radar_winid = <single window ID>

-- Single buffer with all content
-- All sections in one buffer
```

### New Architecture (Grid System)
```lua
-- State tracks multiple windows
state.radar_windows = {
  alternative = <window ID>,
  locks = <window ID>,
  recent = <window ID>,
  hints = <window ID>
}

-- Each section has its own buffer
-- Focus cycles between locks and recent
```

---

## Files to Modify

### 1. `/Users/nbr/repos/black-atom-industries/radar.nvim/lua/radar/config.lua`
- Remove `win_preset` field from `radar` config
- Add `grid_size = { width = 100, height = 30 }` to `radar` config
- Add `position = "center"` to `radar` config (for grid placement)
- Remove `win_presets = {}` field (no longer needed)
- Keep all other fields unchanged

### 2. `/Users/nbr/repos/black-atom-industries/radar.nvim/lua/radar/config.types.lua`
- Update `Radar.Config.Radar` type
- Remove `win_preset` field
- Add `grid_size` field: `{ width: integer, height: integer }`
- Add `position` field: `"center" | "top_left" | "top_right" | "bottom_left" | "bottom_right"`

### 3. `/Users/nbr/repos/black-atom-industries/radar.nvim/lua/radar/state.lua`
- Replace `radar_winid` with `radar_windows` table
- Add helper functions for window validation

### 4. `/Users/nbr/repos/black-atom-industries/radar.nvim/lua/radar/ui/radar.lua`
- **COMPLETE REWRITE** - Replace entire file with grid implementation
- Create grid layout calculator
- Implement 4 separate window creators
- Implement focus management
- Port highlights to work with multiple buffers

### 5. `/Users/nbr/repos/black-atom-industries/radar.nvim/lua/radar/keys.lua`
- Update buffer-local keymaps to work with focused section
- Add Tab/Shift-Tab for focus cycling
- Update line-based navigation to detect current section

### 6. `/Users/nbr/repos/black-atom-industries/radar.nvim/lua/radar/navigation.lua`
- Update `get_file_from_line()` to work with separate buffers
- Handle section detection from buffer context

### 7. `/Users/nbr/repos/black-atom-industries/radar.nvim/lua/radar/autocmd.lua`
- Update to handle multiple windows in `radar.exists()` calls

---

## Phase 1: Configuration Schema

### Step 1.1: Update config.types.lua

```lua
---@class Radar.Config.GridSize
---@field width integer Grid total width
---@field height integer Grid total height

---@alias Radar.Config.Position "center" | "top_left" | "top_right" | "bottom_left" | "bottom_right"

---@class Radar.Config.Radar
---@field grid_size Radar.Config.GridSize
---@field position Radar.Config.Position
---@field winblend integer
---@field max_recent_files integer
---@field show_empty_message boolean
---@field titles Radar.Config.Titles
---@field win_opts table<string, any> Window-local options

-- Remove win_preset field from type definition
```

### Step 1.2: Update config.lua

```lua
---@class Radar.Config
M.default = {
  -- ... (keep keys, persist unchanged)

  -- Remove win_presets = {},

  -- Main radar window
  radar = {
    grid_size = { width = 100, height = 30 },
    position = "center",
    winblend = 0,
    max_recent_files = 20,
    show_empty_message = true,
    titles = {
      main = "󰐷  RADAR",
      locks = "󰋱  LOCKED IN",
      alternative = "  OTHER",
      recent = "󰽏  NEAR",
      hints = "  KEYS", -- Add hints title
    },
    win_opts = {
      number = false,
      relativenumber = false,
      cursorline = true,
      wrap = false,
    },
  },

  -- ... (keep radar_edit, file_float unchanged)
}
```

### Testing Checklist - Phase 1
- [ ] Run `:checkhealth` to ensure no Lua errors
- [ ] Config loads without errors
- [ ] Type checking passes (if using LuaLS)

---

## Phase 2: State Management

### Step 2.1: Update state.lua

Replace the state structure:

```lua
---@class Radar.State
local M = {
  ---@type Radar.Lock[]
  locks = {},
  ---@type string[]
  recent_files = {},
  ---@type string[]
  session_files = {},
  ---@type { alternative: integer?, locks: integer?, recent: integer?, hints: integer? }?
  radar_windows = nil,
  ---@type "locks" | "recent"?
  focused_section = nil,
  ---@type integer?
  edit_winid = nil,
  ---@type integer?
  edit_bufid = nil,
  ---@type integer?
  source_bufnr = nil,
  ---@type string?
  source_alt_file = nil,
}

---Check if all radar windows are valid
---@return boolean
function M.are_radar_windows_valid()
  if not M.radar_windows then
    return false
  end

  for section, winid in pairs(M.radar_windows) do
    if not winid or not vim.api.nvim_win_is_valid(winid) then
      return false
    end
  end

  return true
end

---Close all radar windows
---@return nil
function M.close_all_radar_windows()
  if not M.radar_windows then
    return
  end

  for section, winid in pairs(M.radar_windows) do
    if winid and vim.api.nvim_win_is_valid(winid) then
      vim.api.nvim_win_close(winid, false)
    end
  end

  M.radar_windows = nil
  M.focused_section = nil
end

-- Keep get_lock_by_field unchanged
```

### Testing Checklist - Phase 2
- [ ] State loads without errors
- [ ] Helper functions work correctly
- [ ] No references to old `radar_winid` remain

---

## Phase 3: Grid Layout System

Create the foundation for positioning windows in the grid.

### Step 3.1: Add grid calculator to radar.lua (new file)

```lua
local M = {}

---Calculate position based on config position setting
---@param config Radar.Config
---@return { row: integer, col: integer }
local function calculate_grid_origin(config)
  local width = config.radar.grid_size.width
  local height = config.radar.grid_size.height

  local positions = {
    center = {
      row = math.floor((vim.o.lines - height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
    },
    top_left = { row = 0, col = 0 },
    top_right = { row = 0, col = vim.o.columns - width },
    bottom_left = { row = vim.o.lines - height, col = 0 },
    bottom_right = {
      row = vim.o.lines - height,
      col = vim.o.columns - width,
    },
  }

  return positions[config.radar.position] or positions.center
end

---Calculate grid cell dimensions and positions
---@param config Radar.Config
---@return table Grid layout info
local function calculate_grid_layout(config)
  local origin = calculate_grid_origin(config)
  local total_width = config.radar.grid_size.width
  local total_height = config.radar.grid_size.height

  -- Layout constants
  local ALTERNATIVE_HEIGHT = 3
  local HINTS_HEIGHT = 5
  local column_width = math.floor(total_width / 2)

  -- Calculate main content height (between alternative and hints)
  local content_height = total_height - ALTERNATIVE_HEIGHT - HINTS_HEIGHT

  return {
    origin = origin,
    total_width = total_width,
    total_height = total_height,
    alternative = {
      row = origin.row,
      col = origin.col,
      width = total_width,
      height = ALTERNATIVE_HEIGHT,
    },
    locks = {
      row = origin.row + ALTERNATIVE_HEIGHT,
      col = origin.col,
      width = column_width,
      height = content_height,
    },
    recent = {
      row = origin.row + ALTERNATIVE_HEIGHT,
      col = origin.col + column_width,
      width = total_width - column_width, -- Handle odd widths
      height = content_height,
    },
    hints = {
      row = origin.row + total_height - HINTS_HEIGHT,
      col = origin.col,
      width = total_width,
      height = HINTS_HEIGHT,
    },
  }
end
```

### Testing Checklist - Phase 3
- [ ] Grid calculator returns correct dimensions
- [ ] Different positions (center, top_left, etc.) work correctly
- [ ] Grid adapts to various window sizes

---

## Phase 4: Alternative Section Window

Create the non-focusable indicator at the top.

### Step 4.1: Add alternative window creator

```lua
---Create alternative file window (non-focusable indicator)
---@param layout table Grid layout from calculate_grid_layout
---@param config Radar.Config
---@return integer window_id
local function create_alternative_window(layout, config)
  local alternative = require("radar.alternative")
  local alt_file = alternative.get_alternative_file()

  -- Build content
  local lines = {}
  table.insert(lines, config.radar.titles.alternative)

  if alt_file then
    local path = vim.fn.fnamemodify(alt_file, ":p:.")
    local label = config.keys.alternative
    table.insert(lines, string.format("   [%s] %s  ", label, path))
  else
    table.insert(lines, "   [o] - No other file yet  ")
  end

  -- Create buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  -- Set content
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  -- Create window
  local win_opts = {
    relative = "editor",
    row = layout.alternative.row,
    col = layout.alternative.col,
    width = layout.alternative.width,
    height = layout.alternative.height,
    style = "minimal",
    border = "solid",
    focusable = false, -- Non-focusable indicator
    zindex = 100,
  }

  local winid = vim.api.nvim_open_win(bufnr, false, win_opts)

  -- Apply window options
  vim.api.nvim_set_option_value("winblend", config.radar.winblend, { win = winid })
  for opt, value in pairs(config.radar.win_opts) do
    vim.api.nvim_set_option_value(opt, value, { win = winid })
  end

  -- Apply highlight to title
  local ns = vim.api.nvim_create_namespace("radar.alternative")
  vim.api.nvim_buf_set_extmark(bufnr, ns, 0, 0, {
    end_col = #lines[1],
    hl_group = "@variable",
  })

  return winid
end
```

### Testing Checklist - Phase 4
- [ ] Alternative window appears at correct position
- [ ] Shows alternative file when available
- [ ] Shows placeholder when no alternative file
- [ ] Non-focusable (can't Tab to it)
- [ ] Highlights title correctly

---

## Phase 5: Locks Section Window

Create the focusable locks section.

### Step 5.1: Add locks window creator

```lua
---Create locks section window (focusable)
---@param layout table Grid layout from calculate_grid_layout
---@param config Radar.Config
---@param should_focus boolean
---@return integer window_id
local function create_locks_window(layout, config, should_focus)
  local state = require("radar.state")

  -- Build content
  local lines = {}
  table.insert(lines, config.radar.titles.locks)

  if #state.locks > 0 then
    for _, lock in ipairs(state.locks) do
      local path = vim.fn.fnamemodify(lock.filename, ":p:.")
      local entry = string.format("   [%s] %s  ", lock.label, path)
      table.insert(lines, entry)
    end
  else
    if config.radar.show_empty_message then
      table.insert(lines, " ")
      table.insert(lines, "  No locks yet")
      table.insert(lines, "  Press l to lock files")
    end
  end

  -- Create buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  -- Set content
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  -- Set up buffer-local keymaps BEFORE opening window
  local keys = require("radar.keys")
  keys.setup_locks_keymaps(bufnr, config)

  -- Create window
  local win_opts = {
    relative = "editor",
    row = layout.locks.row,
    col = layout.locks.col,
    width = layout.locks.width,
    height = layout.locks.height,
    style = "minimal",
    border = "solid",
    title = " " .. config.radar.titles.locks .. " ",
    title_pos = "left",
    focusable = true,
    zindex = 100,
  }

  local winid = vim.api.nvim_open_win(bufnr, should_focus, win_opts)

  -- Apply window options
  vim.api.nvim_set_option_value("winblend", config.radar.winblend, { win = winid })
  for opt, value in pairs(config.radar.win_opts) do
    vim.api.nvim_set_option_value(opt, value, { win = winid })
  end

  -- Apply highlights
  apply_locks_highlights(bufnr, config)

  return winid
end

---Apply highlights to locks buffer
---@param bufnr integer
---@param config Radar.Config
local function apply_locks_highlights(bufnr, config)
  local ns = vim.api.nvim_create_namespace("radar.locks")
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Get current file for highlighting
  local curr_filepath = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
  local curr_filepath_formatted = ""
  if curr_filepath ~= "" then
    curr_filepath_formatted = vim.fn.fnamemodify(curr_filepath, ":p:.")
  end

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local state = require("radar.state")
  local section_index = 0

  for i, line in ipairs(lines) do
    if line == config.radar.titles.locks then
      -- Highlight title
      vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, {
        end_col = #line,
        hl_group = "@tag.builtin",
      })
    elseif line ~= "" and line ~= " " and section_index < #state.locks then
      section_index = section_index + 1
      local lock = state.locks[section_index]

      -- Highlight if this is the current file
      if lock and lock.filename == curr_filepath_formatted then
        vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, {
          end_col = #line,
          hl_group = "@function",
        })
      end
    end
  end
end
```

### Testing Checklist - Phase 5
- [ ] Locks window appears at correct position
- [ ] Shows locks correctly
- [ ] Shows empty message when no locks
- [ ] Focusable (can Tab to it)
- [ ] Highlights current file correctly
- [ ] Keybindings work (1-9)

---

## Phase 6: Recent Section Window

Create the focusable recent files section.

### Step 6.1: Add recent window creator

```lua
---Create recent section window (focusable)
---@param layout table Grid layout from calculate_grid_layout
---@param config Radar.Config
---@param should_focus boolean
---@return integer window_id
local function create_recent_window(layout, config, should_focus)
  local state = require("radar.state")

  -- Build content
  local lines = {}
  table.insert(lines, config.radar.titles.recent)

  if #state.recent_files > 0 then
    for i, filename in ipairs(state.recent_files) do
      local label = config.keys.recent[i]
      if label then
        local path = vim.fn.fnamemodify(filename, ":p:.")
        local entry = string.format("   [%s] %s  ", label, path)
        table.insert(lines, entry)
      end
    end
  else
    if config.radar.show_empty_message then
      table.insert(lines, " ")
      table.insert(lines, "  No recent files yet")
    end
  end

  -- Create buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  -- Set content
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  -- Set up buffer-local keymaps BEFORE opening window
  local keys = require("radar.keys")
  keys.setup_recent_keymaps(bufnr, config)

  -- Create window
  local win_opts = {
    relative = "editor",
    row = layout.recent.row,
    col = layout.recent.col,
    width = layout.recent.width,
    height = layout.recent.height,
    style = "minimal",
    border = "solid",
    title = " " .. config.radar.titles.recent .. " ",
    title_pos = "left",
    focusable = true,
    zindex = 100,
  }

  local winid = vim.api.nvim_open_win(bufnr, should_focus, win_opts)

  -- Apply window options
  vim.api.nvim_set_option_value("winblend", config.radar.winblend, { win = winid })
  for opt, value in pairs(config.radar.win_opts) do
    vim.api.nvim_set_option_value(opt, value, { win = winid })
  end

  -- Apply highlights
  apply_recent_highlights(bufnr, config)

  return winid
end

---Apply highlights to recent buffer
---@param bufnr integer
---@param config Radar.Config
local function apply_recent_highlights(bufnr, config)
  local ns = vim.api.nvim_create_namespace("radar.recent")
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Get current file for highlighting
  local curr_filepath = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local state = require("radar.state")
  local section_index = 0

  for i, line in ipairs(lines) do
    if line == config.radar.titles.recent then
      -- Highlight title
      vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, {
        end_col = #line,
        hl_group = "@type",
      })
    elseif line ~= "" and line ~= " " and section_index < #state.recent_files then
      section_index = section_index + 1
      local recent_file = state.recent_files[section_index]

      -- Highlight if this is the current file (recent uses absolute paths)
      if recent_file and recent_file == curr_filepath then
        vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, {
          end_col = #line,
          hl_group = "@function",
        })
      end
    end
  end
end
```

### Testing Checklist - Phase 6
- [ ] Recent window appears at correct position
- [ ] Shows recent files correctly
- [ ] Shows empty message when no recent files
- [ ] Focusable (can Tab to it)
- [ ] Highlights current file correctly
- [ ] Keybindings work (a-g)

---

## Phase 7: Hints Overlay Window

Create the non-focusable hints overlay at the bottom.

### Step 7.1: Add hints window creator

```lua
---Create hints overlay window (non-focusable)
---@param layout table Grid layout from calculate_grid_layout
---@param config Radar.Config
---@return integer window_id
local function create_hints_window(layout, config)
  -- Build hint content
  local lines = {
    config.radar.titles.hints or "  KEYS",
    " ",
    "  [1-9] locks  [a-g] recent  [o] other  [l] lock  [e] edit",
    "  [CR] open  [V] vsplit  [S] hsplit  [T] tab  [F] float",
    "  [Tab] cycle  [q/Esc] close",
  }

  -- Create buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  -- Set content
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  -- Create window
  local win_opts = {
    relative = "editor",
    row = layout.hints.row,
    col = layout.hints.col,
    width = layout.hints.width,
    height = layout.hints.height,
    style = "minimal",
    border = "solid",
    focusable = false, -- Non-focusable overlay
    zindex = 101, -- Higher than other windows
  }

  local winid = vim.api.nvim_open_win(bufnr, false, win_opts)

  -- Apply window options
  vim.api.nvim_set_option_value("winblend", config.radar.winblend, { win = winid })
  for opt, value in pairs(config.radar.win_opts) do
    -- Skip cursorline for hints
    if opt ~= "cursorline" then
      vim.api.nvim_set_option_value(opt, value, { win = winid })
    end
  end

  -- Apply highlights
  local ns = vim.api.nvim_create_namespace("radar.hints")
  vim.api.nvim_buf_set_extmark(bufnr, ns, 0, 0, {
    end_col = #lines[1],
    hl_group = "@comment",
  })

  return winid
end
```

### Testing Checklist - Phase 7
- [ ] Hints window appears at correct position
- [ ] Shows keybinding hints correctly
- [ ] Non-focusable (can't Tab to it)
- [ ] Has higher z-index (appears on top)

---

## Phase 8: Window Lifecycle Management

Implement create, update, close, and toggle functions.

### Step 8.1: Add lifecycle functions to radar.lua

```lua
---Check if radar exists (all windows valid)
---@return boolean
function M.exists()
  local state = require("radar.state")
  return state.are_radar_windows_valid()
end

---Create all radar windows
---@param config Radar.Config
---@return nil
function M.create(config)
  local state = require("radar.state")

  -- Update recent files first
  local recent = require("radar.recent")
  recent.update_state(config)

  -- Calculate grid layout
  local layout = calculate_grid_layout(config)

  -- Create all windows
  local windows = {}
  windows.alternative = create_alternative_window(layout, config)
  windows.locks = create_locks_window(layout, config, true) -- Initial focus
  windows.recent = create_recent_window(layout, config, false)
  windows.hints = create_hints_window(layout, config)

  -- Store in state
  state.radar_windows = windows
  state.focused_section = "locks"
end

---Update all radar windows
---@param config Radar.Config
---@return nil
function M.update(config)
  if not M.exists() then
    M.create(config)
    return
  end

  local state = require("radar.state")

  -- Update recent files
  local recent = require("radar.recent")
  recent.update_state(config)

  -- Close and recreate windows
  -- (Simpler than updating in place for now)
  M.close()
  M.create(config)
end

---Close all radar windows
---@return nil
function M.close()
  local state = require("radar.state")
  state.close_all_radar_windows()
end

---Toggle radar visibility
---@param config Radar.Config
---@return nil
function M.toggle(config)
  if M.exists() then
    M.close()
  else
    M.open(config)
  end
end

---Open radar and focus locks section
---@param config Radar.Config
---@return nil
function M.open(config)
  local state = require("radar.state")

  -- Store the buffer we're opening from
  state.source_bufnr = vim.api.nvim_get_current_buf()

  -- Capture the alternate file before focus changes
  local alternative = require("radar.alternative")
  state.source_alt_file = alternative.get_alternative_file()

  if not M.exists() then
    M.create(config)
  else
    -- Already exists, just focus locks section
    if state.radar_windows and state.radar_windows.locks then
      vim.api.nvim_set_current_win(state.radar_windows.locks)
      state.focused_section = "locks"
    end
  end
end

---Get buffer ID of focused section
---@return integer?
function M.get_focused_bufid()
  local state = require("radar.state")
  if not state.radar_windows or not state.focused_section then
    return nil
  end

  local winid = state.radar_windows[state.focused_section]
  if winid and vim.api.nvim_win_is_valid(winid) then
    return vim.api.nvim_win_get_buf(winid)
  end

  return nil
end
```

### Testing Checklist - Phase 8
- [ ] `create()` creates all 4 windows correctly
- [ ] `update()` refreshes content properly
- [ ] `close()` closes all windows
- [ ] `toggle()` opens/closes correctly
- [ ] `open()` focuses locks section initially
- [ ] Windows positioned correctly per config

---

## Phase 9: Focus & Navigation

Implement Tab cycling and section-aware navigation.

### Step 9.1: Add focus management to radar.lua

```lua
---Cycle focus to next section (Tab)
---@return nil
function M.cycle_focus_next()
  local state = require("radar.state")
  if not state.radar_windows then
    return
  end

  local current = state.focused_section
  local next_section = current == "locks" and "recent" or "locks"

  local next_winid = state.radar_windows[next_section]
  if next_winid and vim.api.nvim_win_is_valid(next_winid) then
    vim.api.nvim_set_current_win(next_winid)
    state.focused_section = next_section
  end
end

---Cycle focus to previous section (Shift-Tab)
---@return nil
function M.cycle_focus_prev()
  -- Same as next for 2 sections
  M.cycle_focus_next()
end
```

### Step 9.2: Update keys.lua

Replace `setup_buffer_local_keymaps` with section-specific functions:

```lua
---Setup keymaps for locks section
---@param bufnr integer
---@param config Radar.Config
---@return nil
function M.setup_locks_keymaps(bufnr, config)
  local navigation = require("radar.navigation")
  local radar = require("radar.ui.radar")
  local opts = { buffer = bufnr, silent = true, noremap = true, nowait = true }

  -- Common keymaps
  M.setup_common_keymaps(bufnr, config, radar, opts)

  -- Lock-specific keymaps (1-9)
  for _, label in ipairs(config.keys.locks) do
    register_split_variants(bufnr, label, function(cmd)
      navigation.open_lock(label, cmd, config, radar)
    end, "Open lock " .. label, config)
  end

  -- Line-based navigation
  register_split_variants(bufnr, config.keys.line.open, function(cmd)
    navigation.open_file_from_line(cmd, config, radar, "locks")
  end, "Open file from line", config)

  -- Additional line keys (V, S, T, F)
  vim.keymap.set("n", config.keys.line.vertical, function()
    navigation.open_file_from_line("vsplit", config, radar, "locks")
  end, vim.tbl_extend("force", opts, { desc = "Open file in vertical split" }))

  vim.keymap.set("n", config.keys.line.horizontal, function()
    navigation.open_file_from_line("split", config, radar, "locks")
  end, vim.tbl_extend("force", opts, { desc = "Open file in horizontal split" }))

  vim.keymap.set("n", config.keys.line.tab, function()
    navigation.open_file_from_line("tabedit", config, radar, "locks")
  end, vim.tbl_extend("force", opts, { desc = "Open file in new tab" }))

  vim.keymap.set("n", config.keys.line.float, function()
    navigation.open_file_from_line("float", config, radar, "locks")
  end, vim.tbl_extend("force", opts, { desc = "Open file in floating window" }))
end

---Setup keymaps for recent section
---@param bufnr integer
---@param config Radar.Config
---@return nil
function M.setup_recent_keymaps(bufnr, config)
  local navigation = require("radar.navigation")
  local radar = require("radar.ui.radar")
  local opts = { buffer = bufnr, silent = true, noremap = true, nowait = true }

  -- Common keymaps
  M.setup_common_keymaps(bufnr, config, radar, opts)

  -- Recent-specific keymaps (a-g)
  for _, label in ipairs(config.keys.recent) do
    register_split_variants(bufnr, label, function(cmd)
      navigation.open_recent(label, cmd, config, radar)
    end, "Open recent file " .. label, config)
  end

  -- Line-based navigation
  register_split_variants(bufnr, config.keys.line.open, function(cmd)
    navigation.open_file_from_line(cmd, config, radar, "recent")
  end, "Open file from line", config)

  -- Additional line keys (V, S, T, F)
  vim.keymap.set("n", config.keys.line.vertical, function()
    navigation.open_file_from_line("vsplit", config, radar, "recent")
  end, vim.tbl_extend("force", opts, { desc = "Open file in vertical split" }))

  vim.keymap.set("n", config.keys.line.horizontal, function()
    navigation.open_file_from_line("split", config, radar, "recent")
  end, vim.tbl_extend("force", opts, { desc = "Open file in horizontal split" }))

  vim.keymap.set("n", config.keys.line.tab, function()
    navigation.open_file_from_line("tabedit", config, radar, "recent")
  end, vim.tbl_extend("force", opts, { desc = "Open file in new tab" }))

  vim.keymap.set("n", config.keys.line.float, function()
    navigation.open_file_from_line("float", config, radar, "recent")
  end, vim.tbl_extend("force", opts, { desc = "Open file in floating window" }))
end

---Setup common keymaps shared by all sections
---@param bufnr integer
---@param config Radar.Config
---@param radar table
---@param opts table
---@return nil
function M.setup_common_keymaps(bufnr, config, radar, opts)
  -- Close radar
  vim.keymap.set("n", "q", function()
    radar.close()
  end, vim.tbl_extend("force", opts, { desc = "Close Radar" }))

  vim.keymap.set("n", "<Esc>", function()
    radar.close()
  end, vim.tbl_extend("force", opts, { desc = "Close Radar" }))

  -- Tab cycling
  vim.keymap.set("n", "<Tab>", function()
    radar.cycle_focus_next()
  end, vim.tbl_extend("force", opts, { desc = "Cycle to next section" }))

  vim.keymap.set("n", "<S-Tab>", function()
    radar.cycle_focus_prev()
  end, vim.tbl_extend("force", opts, { desc = "Cycle to previous section" }))

  -- Lock current buffer
  vim.keymap.set("n", config.keys.lock, function()
    local locks = require("radar.locks")
    local persistence = require("radar.persistence")
    local state = require("radar.state")
    locks.lock_current_buffer(state.source_bufnr, config, persistence, radar)
  end, vim.tbl_extend("force", opts, { desc = "Lock source buffer" }))

  -- Alternative file
  register_split_variants(bufnr, config.keys.alternative, function(cmd)
    local navigation = require("radar.navigation")
    navigation.open_alternative(cmd, config, radar)
  end, "Open alternative file", config)

  -- Edit locks
  vim.keymap.set("n", "e", function()
    require("radar.ui.edit").edit_locks(config, radar)
  end, vim.tbl_extend("force", opts, { desc = "Edit radar locks" }))
end
```

### Step 9.3: Update navigation.lua

Update `get_file_from_line` to accept section parameter:

```lua
---Get file path from current line in radar window
---@param config Radar.Config
---@param section "locks" | "recent"
---@return string? filepath
function M.get_file_from_line(config, section)
  local state = require("radar.state")

  if not state.radar_windows or not state.radar_windows[section] then
    return nil
  end

  local winid = state.radar_windows[section]
  if not vim.api.nvim_win_is_valid(winid) then
    return nil
  end

  local bufid = vim.api.nvim_win_get_buf(winid)
  local current_line_nr = vim.api.nvim_win_get_cursor(winid)[1]
  local lines = vim.api.nvim_buf_get_lines(bufid, 0, -1, false)

  -- Skip title line (line 1)
  local entry_index = current_line_nr - 1

  if section == "locks" then
    if entry_index > 0 and entry_index <= #state.locks then
      return state.locks[entry_index].filename
    end
  elseif section == "recent" then
    if entry_index > 0 and entry_index <= #state.recent_files then
      return state.recent_files[entry_index]
    end
  end

  return nil
end

---Update signature to accept section
---@param open_cmd? string
---@param config Radar.Config
---@param radar_module table
---@param section "locks" | "recent"
---@return nil
function M.open_file_from_line(open_cmd, config, radar_module, section)
  local filepath = M.get_file_from_line(config, section)
  if filepath then
    M.open_file(filepath, open_cmd, config, radar_module)
  end
end
```

### Testing Checklist - Phase 9
- [ ] Tab cycles between locks and recent
- [ ] Shift-Tab cycles between recent and locks
- [ ] Can't focus alternative or hints sections
- [ ] Line-based navigation works in both sections
- [ ] 1-9 keys work only in locks section
- [ ] a-g keys work only in recent section
- [ ] o (alternative) works in both sections

---

## Phase 10: Integration & Testing

Test the complete integration.

### Step 10.1: Integration checklist

- [ ] Open radar with `<space>` (or configured prefix)
- [ ] All 4 windows appear in correct layout
- [ ] Initial focus on locks section
- [ ] Tab cycles between locks and recent
- [ ] Press 1-9 to open locks (with split variants)
- [ ] Press a-g to open recent files (with split variants)
- [ ] Press o to open alternative file (with split variants)
- [ ] Press CR/V/S/T/F for line-based navigation in both sections
- [ ] Press l to lock current file
- [ ] Press e to edit lock labels
- [ ] Press q or Esc to close all windows
- [ ] Reopen radar, windows remember state
- [ ] Alternative section shows correct file or placeholder
- [ ] Hints overlay displays keybindings
- [ ] Highlights update on BufEnter
- [ ] Current file highlighted correctly in locks/recent
- [ ] Grid adapts to different positions (center, top_left, etc.)
- [ ] Grid adapts to vim resize events

### Step 10.2: Update autocmd.lua

No changes needed - autocmds already call `radar.exists()` and `radar.update()` which now work with the new system.

### Step 10.3: Test all navigation modes

Test each split variant:
- [ ] `<CR>` opens in current window
- [ ] `<C-v>` + key opens in vertical split
- [ ] `<C-s>` + key opens in horizontal split
- [ ] `<C-t>` + key opens in new tab
- [ ] `<C-f>` + key opens in floating window
- [ ] Line-based: `V`, `S`, `T`, `F` work correctly

---

## Phase 11: Cleanup

Remove obsolete code and update documentation.

### Step 11.1: Remove unused files

- [ ] Remove `/Users/nbr/repos/black-atom-industries/radar.nvim/lua/radar/window.lua` (no longer needed)
- [ ] Remove `/Users/nbr/repos/black-atom-industries/radar.nvim/lua/radar/win_presets.lua` (if exists, no longer needed)

### Step 11.2: Update CLAUDE.md

Update the architecture section to reflect the new grid system:

```markdown
### Current Modular Structure (Grid-Based)

```
lua/radar/
├── ui/
│   ├── radar.lua         -- Grid layout system with 4 windows
│   └── edit.lua          -- Lock label editor
```

### Grid Layout

The radar uses a multi-window grid layout:
- Alternative (top, full width, non-focusable)
- Locks (bottom-left, focusable)
- Recent (bottom-right, focusable)
- Hints (bottom, full width, non-focusable overlay)

Configuration:
- `grid_size = { width, height }` - Total grid dimensions
- `position = "center" | "top_left" | ...` - Grid placement
```

### Step 11.3: Final verification

- [ ] No console errors on startup
- [ ] No console errors when opening/closing radar
- [ ] All keybindings work as expected
- [ ] Persistence still works (locks save/load per project+branch)
- [ ] Alternative file detection still works
- [ ] Recent files tracking still works
- [ ] Edit mode still works for lock labels

---

## Rollback Plan

If issues arise during implementation:

1. **Keep backups**: Before starting, copy `lua/radar/ui/radar.lua` to `lua/radar/ui/radar.lua.backup`
2. **Commit frequently**: Use semantic commits after each phase
3. **Test incrementally**: Don't move to next phase until current phase tests pass
4. **Rollback command**: `git restore lua/radar/ui/radar.lua lua/radar/config.lua lua/radar/state.lua lua/radar/keys.lua`

---

## Commit Strategy

After each phase, commit with semantic format:

- Phase 1: `feat: add grid_size and position config schema`
- Phase 2: `refactor: update state to track multiple radar windows`
- Phase 3: `feat: add grid layout calculator`
- Phase 4: `feat: implement alternative section window`
- Phase 5: `feat: implement locks section window`
- Phase 6: `feat: implement recent section window`
- Phase 7: `feat: implement hints overlay window`
- Phase 8: `feat: implement window lifecycle management`
- Phase 9: `feat: add focus cycling and section-aware navigation`
- Phase 10: `test: verify complete grid radar integration`
- Phase 11: `refactor: remove obsolete window preset system`

---

## Critical Patterns to Maintain

### 1. Safe String Matching
```lua
-- ALWAYS use literal matching for filenames
if line:find(formatted_filepath, 1, true) then
```

### 2. Window Validation
```lua
-- Always validate before use
if winid and vim.api.nvim_win_is_valid(winid) then
```

### 3. Safe Nested Access
```lua
-- Use vim.tbl_get for safe nested access
local persisted_pins = vim.tbl_get(data, project_path, git_branch, "pins")
```

### 4. Deferred Persistence
```lua
-- Batch changes to avoid excessive I/O
vim.defer_fn(function()
  persistence.persist(config)
end, config.persist.defer_ms)
```

### 5. Buffer Modification Pattern
```lua
-- Always modifiable -> edit -> unmodifiable
vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
```

---

## Known Edge Cases

1. **Empty sections**: Ensure empty messages display correctly in locks/recent
2. **No alternative file**: Show placeholder in alternative section
3. **Grid too small**: May need minimum size validation
4. **Vim resize**: Grid should recalculate positions
5. **Focus lost**: If user closes focused window manually, detect and reopen

---

## Future Enhancements (Post-Implementation)

- [ ] Smart height distribution (taller sections with more content)
- [ ] User-configurable section visibility (hide alternative/hints)
- [ ] Animated transitions between sections
- [ ] More position presets (4 corners + edges)
- [ ] Configurable hints content

---

This plan provides a complete roadmap for refactoring radar.nvim to a grid-based layout. Each phase is independently testable and can be committed separately. The implementation preserves all existing functionality while adding the new multi-window grid system.
