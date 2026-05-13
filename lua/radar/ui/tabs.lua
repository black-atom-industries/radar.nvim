local M = {}

local state = require("radar.state")
local tabs = require("radar.tabs")
local window = require("radar.window")

---Cut item clipboard for cut/paste operations
---@type { type: "buffer"|string, filepath?: string, buffers?: string[] }?
local cut_item = nil

---Line number of the currently cut item (for visual highlight)
---@type integer?
local cut_line_num = nil

---Check if tabs window exists
---@return boolean
function M.exists()
  return state.is_tabs_window_valid()
end

---Close tabs window
---@return nil
function M.close()
  state.close_tabs_window()
end

---Build the content lines and line mapping
---@param tabs_data Radar.TabData[]
---@return string[], Radar.TabsLineMapping[]
local function build_content(tabs_data)
  local lines = {}
  local line_mapping = {}

  for _, tab in ipairs(tabs_data) do
    -- Tab header line
    local current_marker = tab.is_current and "*" or " "
    local tab_line =
      string.format("%sTab %d (%s)", current_marker, tab.index, tab.cwd)
    table.insert(lines, tab_line)
    table.insert(line_mapping, { tabid = tab.tabid })

    -- Buffer lines (indented)
    for _, buf in ipairs(tab.buffers) do
      local filepath = vim.fn.fnamemodify(buf.filepath, ":p:.")
      local buf_line = string.format("    %s", filepath)
      table.insert(lines, buf_line)
      table.insert(line_mapping, {
        tabid = tab.tabid,
        winid = buf.winid,
        filepath = buf.filepath,
      })
    end
  end

  -- Handle empty state
  if #lines == 0 then
    table.insert(lines, " No tabs with files")
    table.insert(line_mapping, {})
  end

  return lines, line_mapping
end

---Apply highlights to the tabs buffer
---@param bufnr integer
---@param tabs_data Radar.TabData[]
local function apply_highlights(bufnr, tabs_data)
  local ns = vim.api.nvim_create_namespace("radar.tabs")
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local line_idx = 0

  for _, tab in ipairs(tabs_data) do
    -- Highlight current tab header
    if tab.is_current and line_idx < #lines then
      vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, 0, {
        end_col = #lines[line_idx + 1],
        hl_group = "@function",
      })
    end
    line_idx = line_idx + 1

    -- Buffer lines
    for _ in ipairs(tab.buffers) do
      line_idx = line_idx + 1
    end
  end

  -- Highlight the cut line if there's an active cut item
  if cut_line_num and cut_line_num >= 1 and cut_line_num <= #lines then
    local cut_line = lines[cut_line_num]
    if cut_line and #cut_line > 0 then
      vim.api.nvim_buf_set_extmark(bufnr, ns, cut_line_num - 1, 0, {
        end_col = #cut_line,
        hl_group = "@comment",
      })
    end
  end
end

---Setup keymaps for the tabs buffer
---@param bufnr integer
---@param config Radar.Config
local function setup_keymaps(bufnr, config)
  local opts = { buffer = bufnr, silent = true, noremap = true, nowait = true }

  -- Jump to tab/buffer
  vim.keymap.set("n", "<CR>", function()
    M.jump_to_line(config)
  end, vim.tbl_extend("force", opts, { desc = "Jump to tab/buffer" }))

  -- Close
  vim.keymap.set("n", "q", function()
    M.close()
  end, vim.tbl_extend("force", opts, { desc = "Close tabs window" }))

  vim.keymap.set("n", "<Esc>", function()
    M.close()
  end, vim.tbl_extend("force", opts, { desc = "Close tabs window" }))

  -- Delete buffer / close tab
  vim.keymap.set("n", "x", function()
    M.delete_line(config)
  end, vim.tbl_extend("force", opts, { desc = "Delete buffer/close tab" }))

  -- Make tab/buffer the only one
  vim.keymap.set("n", "o", function()
    M.only_line(config)
  end, vim.tbl_extend("force", opts, { desc = "Make tab/buffer the only one" }))

  -- New tab
  vim.keymap.set("n", "n", function()
    M.new_line(config)
  end, vim.tbl_extend("force", opts, { desc = "New tab" }))

  -- Vertical split
  vim.keymap.set("n", "v", function()
    M.vsplit_line(config)
  end, vim.tbl_extend("force", opts, { desc = "Vertical split" }))

  -- Horizontal split
  vim.keymap.set("n", "s", function()
    M.split_line(config)
  end, vim.tbl_extend("force", opts, { desc = "Horizontal split" }))

  -- Cut buffer/tab into clipboard
  vim.keymap.set("n", "dd", function()
    M.cut_line(config)
  end, vim.tbl_extend("force", opts, { desc = "Cut tab/buffer" }))

  -- Paste cut item after cursor
  vim.keymap.set("n", "p", function()
    M.paste_line(config)
  end, vim.tbl_extend("force", opts, { desc = "Paste cut tab/buffer" }))

  -- Paste cut item before cursor
  vim.keymap.set("n", "P", function()
    M.paste_line_before(config)
  end, vim.tbl_extend("force", opts, { desc = "Paste cut tab/buffer before" }))
end

---Open the tabs floating window
---@param config Radar.Config
---@return nil
function M.open(config)
  -- Capture the source buffer before creating the tabs window
  local source_buf = vim.api.nvim_get_current_buf()
  local source_filepath = vim.api.nvim_buf_get_name(source_buf)
  local source_tabid = vim.api.nvim_get_current_tabpage()

  -- Get tabs data
  local tabs_data = tabs.get_tabs_data()

  -- Build content
  local lines, line_mapping = build_content(tabs_data)
  state.tabs_line_mapping = line_mapping

  -- Create buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })

  -- Set content
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  -- Setup keymaps
  setup_keymaps(bufnr, config)

  -- Store buffer id
  state.tabs_bufid = bufnr

  -- Resolve window config from preset
  local win_config = window.resolve_config(config, config.tabs.win_preset, {
    title = "  TABS ",
    footer = " [CR]jump [x]close [o]only [v]vsp [s]hsp [n]tab [dd]cut [p]paste [q]quit ",
    footer_pos = "left",
    border = "solid",
  })

  local winid = vim.api.nvim_open_win(bufnr, true, win_config)

  -- Store window id
  state.tabs_winid = winid

  -- Apply window options
  for opt, value in pairs(config.tabs.win_opts) do
    vim.api.nvim_set_option_value(opt, value, { win = winid })
  end

  -- Apply highlights
  apply_highlights(bufnr, tabs_data)

  -- Position cursor on the source buffer's line
  local cursor_line = 1

  -- Find the line matching current tab + buffer
  for i, entry in ipairs(line_mapping) do
    if entry.tabid == source_tabid then
      if entry.filepath and entry.filepath == source_filepath then
        -- Exact buffer match (highest priority)
        cursor_line = i
        break
      elseif cursor_line == 1 then
        -- Tab header match (fallback if no buffer found)
        cursor_line = i
      end
    end
  end

  vim.api.nvim_win_set_cursor(winid, { cursor_line, 0 })
end

---Toggle tabs window
---@param config Radar.Config
---@return nil
function M.toggle(config)
  if M.exists() then
    M.close()
  else
    M.open(config)
  end
end

---Update tabs window content
---@param config Radar.Config
---@return nil
function M.update(config)
  if not M.exists() then
    return
  end

  -- Get fresh data
  local tabs_data = tabs.get_tabs_data()
  local lines, line_mapping = build_content(tabs_data)
  state.tabs_line_mapping = line_mapping

  local bufnr = state.tabs_bufid
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Update content
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  -- Re-apply highlights
  apply_highlights(bufnr, tabs_data)
end

---Delete the buffer or close the tab on the current line
---@param config Radar.Config
---@return nil
function M.delete_line(config)
  if not M.exists() then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.tabs_winid)
  local line_num = cursor[1]
  local item = state.tabs_line_mapping[line_num]

  if not item or not item.tabid then
    return
  end

  if item.winid then
    -- Buffer line: close the window (not the buffer, which may be open elsewhere)
    local ok, err = pcall(vim.api.nvim_win_close, item.winid, false)
    if not ok then
      vim.notify("Cannot close window: " .. err, vim.log.levels.WARN)
      return
    end
  else
    -- Tab header line: close the tab
    local tab_count = #vim.api.nvim_list_tabpages()
    if tab_count <= 1 then
      vim.notify("Cannot close the last tab", vim.log.levels.WARN)
      return
    end

    local ok, err =
      pcall(vim.cmd, "tabclose " .. vim.api.nvim_tabpage_get_number(item.tabid))
    if not ok then
      vim.notify("Cannot close tab: " .. err, vim.log.levels.WARN)
      return
    end
  end

  -- Refresh the tabs window
  M.update(config)

  -- Clamp cursor if past the new last line
  if
    M.exists()
    and state.tabs_bufid
    and vim.api.nvim_buf_is_valid(state.tabs_bufid)
  then
    local new_count = vim.api.nvim_buf_line_count(state.tabs_bufid)
    if line_num > new_count then
      vim.api.nvim_win_set_cursor(state.tabs_winid, { math.max(1, new_count), 0 })
    end
  end
end

---Make the tab or buffer the only one (tabonly/only)
---@param config Radar.Config
---@return nil
function M.only_line(config)
  if not M.exists() then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.tabs_winid)
  local line_num = cursor[1]
  local item = state.tabs_line_mapping[line_num]

  if not item or not item.tabid then
    return
  end

  -- Close the tabs window first
  M.close()

  if item.winid then
    -- Buffer line: switch to this window, then close all other windows in the tab
    vim.api.nvim_set_current_win(item.winid)
    vim.cmd("only")
  else
    -- Tab header line: switch to this tab, then close all other tabs
    local tab_win = vim.api.nvim_tabpage_get_win(item.tabid)
    vim.api.nvim_set_current_win(tab_win)
    vim.cmd("tabonly")
  end
end

---Create a new tab from the current tab header line
---@param config Radar.Config
---@return nil
function M.new_line(config)
  if not M.exists() then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.tabs_winid)
  local line_num = cursor[1]
  local item = state.tabs_line_mapping[line_num]

  if not item or not item.tabid or item.winid then
    return
  end

  -- Close the tabs window first
  M.close()

  -- Tab header line: create a new tab
  vim.cmd("tabnew")
end

---Create a vertical split from the current buffer line
---@param config Radar.Config
---@return nil
function M.vsplit_line(config)
  if not M.exists() then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.tabs_winid)
  local line_num = cursor[1]
  local item = state.tabs_line_mapping[line_num]

  if not item or not item.winid then
    return
  end

  -- Close the tabs window first
  M.close()

  vim.api.nvim_set_current_win(item.winid)
  vim.cmd("vsplit")
end

---Create a horizontal split from the current buffer line
---@param config Radar.Config
---@return nil
function M.split_line(config)
  if not M.exists() then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.tabs_winid)
  local line_num = cursor[1]
  local item = state.tabs_line_mapping[line_num]

  if not item or not item.winid then
    return
  end

  -- Close the tabs window first
  M.close()

  vim.api.nvim_set_current_win(item.winid)
  vim.cmd("split")
end

---Cut the tab or buffer on the current line (store in clipboard, don't close)
---@param config Radar.Config
---@return nil
function M.cut_line(config)
  if not M.exists() then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.tabs_winid)
  local line_num = cursor[1]
  local item = state.tabs_line_mapping[line_num]

  if not item or not item.tabid then
    return
  end

  if item.winid then
    -- Buffer line: store buffer info WITHOUT closing the window
    if not item.filepath then
      return
    end
    cut_item = { type = "buffer", filepath = item.filepath, winid = item.winid }
  else
    -- Tab header line: store tab info WITHOUT closing the tab
    local buffer_paths = {}
    local wins = vim.api.nvim_tabpage_list_wins(item.tabid)
    for _, winid in ipairs(wins) do
      local bufnr = vim.api.nvim_win_get_buf(winid)
      local filepath = vim.api.nvim_buf_get_name(bufnr)
      if filepath ~= "" then
        table.insert(buffer_paths, filepath)
      end
    end
    cut_item = { type = "tab", buffers = buffer_paths, tabid = item.tabid }
  end

  cut_line_num = line_num

  -- Re-apply highlights to visually mark the cut line
  if M.exists() and state.tabs_bufid and vim.api.nvim_buf_is_valid(state.tabs_bufid) then
    local tabs_data = tabs.get_tabs_data()
    apply_highlights(state.tabs_bufid, tabs_data)
  end

  vim.notify("Cut " .. cut_item.type .. " — press p to paste it", vim.log.levels.INFO)
end

---Paste the cut item after the current line
---@param config Radar.Config
---@return nil
function M.paste_line(config)
  if not M.exists() or not cut_item then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.tabs_winid)
  local line_num = cursor[1]
  local item = state.tabs_line_mapping[line_num]

  if not item or not item.tabid then
    return
  end

  if cut_item.type == "buffer" then
    -- Create the new window FIRST at the paste position
    if item.winid then
      vim.api.nvim_set_current_win(item.winid)
      pcall(vim.cmd, "vsplit")
      pcall(vim.cmd, "edit " .. vim.fn.fnameescape(cut_item.filepath))
    else
      local tab_win = vim.api.nvim_tabpage_get_win(item.tabid)
      vim.api.nvim_set_current_win(tab_win)
      pcall(vim.cmd, "tabedit " .. vim.fn.fnameescape(cut_item.filepath))
    end

    -- Return focus to the tabs floating window
    if M.exists() then
      pcall(vim.api.nvim_set_current_win, state.tabs_winid)
    end

    -- THEN close the original window
    if cut_item.winid and vim.api.nvim_win_is_valid(cut_item.winid) then
      pcall(vim.api.nvim_win_close, cut_item.winid, false)
    end

  elseif cut_item.type == "tab" and cut_item.tabid then
    if not vim.api.nvim_tabpage_is_valid(cut_item.tabid) then
      return
    end

    -- Calculate target position (0-indexed) for tabmove
    local tabs = vim.api.nvim_list_tabpages()
    local target_pos = nil
    for i, tabid in ipairs(tabs) do
      if tabid == item.tabid then
        target_pos = i - 1 -- 0-indexed
        break
      end
    end

    if target_pos == nil then
      return
    end

    -- Navigate to the cut tab, move it after the target, then return
    local cut_tab_win = vim.api.nvim_tabpage_get_win(cut_item.tabid)
    vim.api.nvim_set_current_win(cut_tab_win)
    vim.cmd("tabmove " .. (target_pos + 1))

    -- Return focus to the tabs floating window
    if M.exists() then
      pcall(vim.api.nvim_set_current_win, state.tabs_winid)
    end
  end

  cut_item = nil
  cut_line_num = nil

  -- Refresh the tabs window to show the new layout
  M.update(config)

  -- Clamp cursor if past the new last line
  if
    M.exists()
    and state.tabs_bufid
    and vim.api.nvim_buf_is_valid(state.tabs_bufid)
  then
    local new_count = vim.api.nvim_buf_line_count(state.tabs_bufid)
    if line_num > new_count then
      vim.api.nvim_win_set_cursor(state.tabs_winid, { math.max(1, new_count), 0 })
    end
  end
end

---Paste the cut item before the current line
---@param config Radar.Config
---@return nil
function M.paste_line_before(config)
  if not M.exists() or not cut_item then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.tabs_winid)
  local line_num = cursor[1]
  local item = state.tabs_line_mapping[line_num]

  if not item or not item.tabid then
    return
  end

  if cut_item.type == "tab" and cut_item.tabid then
    if not vim.api.nvim_tabpage_is_valid(cut_item.tabid) then
      return
    end

    -- Calculate target position (0-indexed) for tabmove
    local tabs = vim.api.nvim_list_tabpages()
    local target_pos = nil
    for i, tabid in ipairs(tabs) do
      if tabid == item.tabid then
        target_pos = i - 1 -- 0-indexed
        break
      end
    end

    if target_pos == nil then
      return
    end

    -- Navigate to the cut tab, move it before the target, then return
    local cut_tab_win = vim.api.nvim_tabpage_get_win(cut_item.tabid)
    vim.api.nvim_set_current_win(cut_tab_win)
    vim.cmd("tabmove " .. target_pos)

    -- Return focus to the tabs floating window
    if M.exists() then
      pcall(vim.api.nvim_set_current_win, state.tabs_winid)
    end

    cut_item = nil
    cut_line_num = nil

    -- Refresh the tabs window to show the new layout
    M.update(config)

    -- Clamp cursor if past the new last line
    if
      M.exists()
      and state.tabs_bufid
      and vim.api.nvim_buf_is_valid(state.tabs_bufid)
    then
      local new_count = vim.api.nvim_buf_line_count(state.tabs_bufid)
      if line_num > new_count then
        vim.api.nvim_win_set_cursor(state.tabs_winid, { math.max(1, new_count), 0 })
      end
    end
  else
    -- Buffer line: fall back to paste after (for now)
    M.paste_line(config)
  end
end

---Jump to the tab/buffer on the current line
---@param config Radar.Config
---@return nil
function M.jump_to_line(config)
  if not M.exists() then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.tabs_winid)
  local line_num = cursor[1]
  local item = state.tabs_line_mapping[line_num]

  if not item or not item.tabid then
    return
  end

  -- Close window if auto_close is enabled
  if config.tabs.auto_close then
    M.close()
  end

  -- Jump to the target
  if item.winid then
    -- Buffer line: switch to specific window (this also switches tabs)
    vim.api.nvim_set_current_win(item.winid)
  else
    -- Tab header line: switch to tab's active window
    local tab_win = vim.api.nvim_tabpage_get_win(item.tabid)
    vim.api.nvim_set_current_win(tab_win)
  end
end

return M
