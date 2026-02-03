local M = {}

local state = require("radar.state")
local tabs = require("radar.tabs")
local window = require("radar.window")

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
    local tab_line = string.format("%sTab %d (%s)", current_marker, tab.index, tab.cwd)
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
end

---Open the tabs floating window
---@param config Radar.Config
---@return nil
function M.open(config)
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

  -- Position cursor on first line
  vim.api.nvim_win_set_cursor(winid, { 1, 0 })
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
