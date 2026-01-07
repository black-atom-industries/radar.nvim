local M = {}

---Format file path to relative path from cwd
---@param path string
---@return string
function M.get_formatted_filepath(path)
  return vim.fn.fnamemodify(path, ":p:.")
end

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
  local ALTERNATIVE_HEIGHT = 1 -- Just one line of content (title is in border)
  local VERTICAL_GAP = 3 -- Gap between alternative and locks/recent
  local HORIZONTAL_GAP = 4 -- Gap between locks and recent
  local column_width = math.floor((total_width - HORIZONTAL_GAP) / 2)

  -- Calculate main content height (below alternative, with gap)
  local content_height = total_height - ALTERNATIVE_HEIGHT - VERTICAL_GAP

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
      row = origin.row + ALTERNATIVE_HEIGHT + VERTICAL_GAP,
      col = origin.col,
      width = column_width,
      height = content_height,
    },
    recent = {
      row = origin.row + ALTERNATIVE_HEIGHT + VERTICAL_GAP,
      col = origin.col + column_width + HORIZONTAL_GAP,
      width = total_width - column_width - HORIZONTAL_GAP, -- Handle odd widths and gap
      height = content_height,
    },
  }
end

---Check if radar exists (all windows valid)
---@return boolean
function M.exists()
  local state = require("radar.state")
  return state.are_radar_windows_valid()
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

---Cycle focus to next section (Tab)
---@return nil
function M.cycle_focus_next()
  local state = require("radar.state")
  if not state.radar_windows then
    return
  end

  -- Default to locks if focused_section is nil
  local current = state.focused_section or "locks"
  local next_section = current == "locks" and "recent" or "locks"

  local next_winid = state.radar_windows[next_section]
  if next_winid and vim.api.nvim_win_is_valid(next_winid) then
    -- Set flag to prevent BufEnter from recreating windows
    state.switching_focus = true

    -- Switch window focus
    vim.api.nvim_set_current_win(next_winid)

    -- Update state
    state.focused_section = next_section

    -- Reset flag after a short delay
    vim.defer_fn(function()
      state.switching_focus = false
    end, 50)
  end
end

---Cycle focus to previous section (Shift-Tab)
---@return nil
function M.cycle_focus_prev()
  -- Same as next for 2 sections
  M.cycle_focus_next()
end

---Create alternative file window (non-focusable indicator)
---@param layout table Grid layout from calculate_grid_layout
---@param config Radar.Config
---@return integer window_id
local function create_alternative_window(layout, config)
  local alternative = require("radar.alternative")
  local alt_file = alternative.get_alternative_file()

  -- Build content (no title - shown in window border)
  local lines = {}

  local label = config.keys.alternative or config.keys.prefix
  if alt_file then
    local path = vim.fn.fnamemodify(alt_file, ":p:.")
    table.insert(lines, string.format(" [%s] %s", label, path))
  else
    table.insert(lines, string.format(" [%s] - No other file yet", label))
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
    border = config.radar.border,
    title = " " .. config.radar.titles.alternative .. " ",
    title_pos = "left",
    focusable = false, -- Non-focusable indicator
    zindex = 100,
  }

  local winid = vim.api.nvim_open_win(bufnr, false, win_opts)

  -- Apply window options
  vim.api.nvim_set_option_value("winblend", config.radar.winblend, { win = winid })
  for opt, value in pairs(config.radar.win_opts) do
    -- Skip cursorline for alternative window - we want it disabled
    if opt ~= "cursorline" then
      vim.api.nvim_set_option_value(opt, value, { win = winid })
    end
  end
  -- Explicitly disable cursorline for alternative window
  vim.api.nvim_set_option_value("cursorline", false, { win = winid })

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

  -- Each line maps directly to a lock entry
  for i, line in ipairs(lines) do
    if line ~= "" and line ~= " " and i <= #state.locks then
      local lock = state.locks[i]

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

---Create locks section window (focusable)
---@param layout table Grid layout from calculate_grid_layout
---@param config Radar.Config
---@param should_focus boolean
---@return integer window_id
local function create_locks_window(layout, config, should_focus)
  local state = require("radar.state")

  -- Build content (no title - shown in window border)
  local lines = {}

  if #state.locks > 0 then
    for _, lock in ipairs(state.locks) do
      local path = vim.fn.fnamemodify(lock.filename, ":p:.")
      local entry = string.format(" [%s] %s", lock.label, path)
      table.insert(lines, entry)
    end
  else
    if config.radar.show_empty_message then
      table.insert(lines, " No locks yet")
      table.insert(lines, " Press l to lock files")
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

  -- Create window with border title
  local win_opts = {
    relative = "editor",
    row = layout.locks.row,
    col = layout.locks.col,
    width = layout.locks.width,
    height = layout.locks.height,
    style = "minimal",
    border = config.radar.border,
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

  -- Set cursor to line 1 (first entry)
  if should_focus and #lines > 0 then
    vim.api.nvim_win_set_cursor(winid, { 1, 0 })
  end

  -- Apply highlights
  apply_locks_highlights(bufnr, config)

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

  -- Each line maps directly to a recent file entry
  for i, line in ipairs(lines) do
    if line ~= "" and line ~= " " and i <= #state.recent_files then
      local recent_file = state.recent_files[i]

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

---Create recent section window (focusable)
---@param layout table Grid layout from calculate_grid_layout
---@param config Radar.Config
---@param should_focus boolean
---@return integer window_id
local function create_recent_window(layout, config, should_focus)
  local state = require("radar.state")

  -- Build content (no title - shown in window border)
  local lines = {}

  if #state.recent_files > 0 then
    for i, filename in ipairs(state.recent_files) do
      local label = config.keys.recent[i] -- Will be nil after exhausting keybindings
      local path = vim.fn.fnamemodify(filename, ":p:.")
      local entry
      if label then
        entry = string.format(" [%s] %s", label, path)
      else
        -- Show without keybinding label for files beyond the keybinding list
        entry = string.format("     %s", path)
      end
      table.insert(lines, entry)
    end
  else
    if config.radar.show_empty_message then
      table.insert(lines, " No recent files yet")
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

  -- Create window with border title (higher zindex to prevent occlusion)
  local win_opts = {
    relative = "editor",
    row = layout.recent.row,
    col = layout.recent.col,
    width = layout.recent.width,
    height = layout.recent.height,
    style = "minimal",
    border = config.radar.border,
    title = " " .. config.radar.titles.recent .. " ",
    title_pos = "left",
    focusable = true,
    zindex = 101,
  }

  local winid = vim.api.nvim_open_win(bufnr, should_focus, win_opts)

  -- Apply window options
  vim.api.nvim_set_option_value("winblend", config.radar.winblend, { win = winid })
  for opt, value in pairs(config.radar.win_opts) do
    vim.api.nvim_set_option_value(opt, value, { win = winid })
  end

  -- Set cursor to line 1 (first entry)
  if should_focus and #lines > 0 then
    vim.api.nvim_win_set_cursor(winid, { 1, 0 })
  end

  -- Apply highlights
  apply_recent_highlights(bufnr, config)

  return winid
end

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
    border = config.radar.border,
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
  -- windows.hints = create_hints_window(layout, config) -- Removed for now

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

return M
