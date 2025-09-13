local config_module = require("radar.config")
local state = require("radar.state")
local recent = require("radar.recent")

local M = {}

---Calculate optimal window width based on longest file path
---@param radar_config table
---@return integer
function M.calculate_window_width(radar_config)
  local max_width = 0

  -- Check locked files
  for _, lock in ipairs(state.locks) do
    local formatted_path = M.get_formatted_filepath(lock.filename, radar_config)
    local entry_text =
      string.format(radar_config.ui.mini.entry_format, lock.label, formatted_path)
    max_width = math.max(max_width, vim.fn.strdisplaywidth(entry_text))
  end

  -- Check recent files
  for i, filename in ipairs(state.recent_files) do
    local label = radar_config.keys.recent[i]
    if label then
      local formatted_path = M.get_formatted_filepath(filename, radar_config)
      local entry_text =
        string.format(radar_config.ui.mini.entry_format, label, formatted_path)
      max_width = math.max(max_width, vim.fn.strdisplaywidth(entry_text))
    end
  end

  -- Ensure minimum width and add padding
  return math.max(max_width, radar_config.ui.mini.config.width)
end

---Format file path according to config
---@param path string
---@param radar_config table
---@return string
function M.get_formatted_filepath(path, radar_config)
  return vim.fn.fnamemodify(path, radar_config.ui.mini.path_format)
end

---Create formatted entries for locks
---@param locks Radar.Lock[]
---@param radar_config table
---@return string[]
function M.create_entries(locks, radar_config)
  local entries = {}

  if #locks > 0 then
    table.insert(entries, radar_config.ui.mini.sections.locks.header)
    for _, lock in ipairs(locks) do
      local path = M.get_formatted_filepath(lock.filename, radar_config)
      local entry =
        string.format(radar_config.ui.mini.entry_format, lock.label, path)
      table.insert(entries, entry)
    end
  end

  return entries
end

---Create formatted entries for recent files
---@param radar_config table
---@return string[]
function M.create_recent_entries(radar_config)
  local entries = {}

  if #state.recent_files > 0 then
    table.insert(entries, radar_config.ui.mini.sections.recent.header)
    for i, filename in ipairs(state.recent_files) do
      local label = radar_config.keys.recent[i]
      if label then
        local path = M.get_formatted_filepath(filename, radar_config)
        local entry = string.format(radar_config.ui.mini.entry_format, label, path)
        table.insert(entries, entry)
      end
    end
  end

  return entries
end

---Build all radar entries with proper sectioning and empty state
---@param radar_config table
---@return string[]
function M.build_radar_entries(radar_config)
  local all_entries = {}

  -- Add lock entries
  local lock_entries = M.create_entries(state.locks, radar_config)
  vim.list_extend(all_entries, lock_entries)

  -- Add recent entries with separator
  if #state.recent_files > 0 then
    -- Add empty line separator only if we also have locks
    if #state.locks > 0 then
      table.insert(all_entries, radar_config.ui.mini.separator)
    end
    local recent_entries = M.create_recent_entries(radar_config)
    vim.list_extend(all_entries, recent_entries)
  end

  -- Add separator at the beginning if we have any content
  if #all_entries > 0 then
    table.insert(all_entries, 1, radar_config.ui.mini.separator)
  end

  -- If no content at all, show helpful message
  if #all_entries == 0 then
    if radar_config.ui.mini.sections.empty.show_title then
      table.insert(all_entries, radar_config.ui.mini.config.title)
      table.insert(all_entries, "")
    end
    if radar_config.ui.mini.sections.empty.instructions then
      table.insert(all_entries, "  No files tracked yet")
      table.insert(
        all_entries,
        "  Use " .. radar_config.keys.lock .. " to lock files"
      )
    end
  end

  return all_entries
end

---Get mini radar buffer ID
---@return integer?
function M.get_bufid()
  local win = state.mini_radar_winid

  if win ~= nil and vim.api.nvim_win_is_valid(win) then
    return vim.api.nvim_win_get_buf(win)
  else
    return nil
  end
end

---Check if mini radar exists
---@return boolean
function M.exists()
  return state.mini_radar_winid and vim.api.nvim_win_is_valid(state.mini_radar_winid)
    or false
end

---Ensure mini radar exists, create if needed
---@param radar_config table
---@return nil
function M.ensure_exists(radar_config)
  if not M.exists() then
    M.create(radar_config)
  end
end

---Apply all highlights in one simple pass
---@param radar_config table
---@return nil
function M.apply_highlights(radar_config)
  local bufid = M.get_bufid()
  if not bufid then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufid, 0, -1, false)

  -- Get current file (might be empty)
  local current_file = ""
  local curr_filepath = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
  if curr_filepath ~= "" then
    current_file = M.get_formatted_filepath(curr_filepath, radar_config)
  end

  -- Clear all highlights once
  vim.api.nvim_buf_clear_namespace(
    bufid,
    config_module.constants.ns_mini_radar,
    0,
    -1
  )

  -- Apply all highlights in one pass
  local current_section = nil
  for i, line in ipairs(lines) do
    -- Section headers - always highlight
    if line == radar_config.ui.mini.sections.locks.header then
      current_section = "locks"
      vim.api.nvim_buf_set_extmark(
        bufid,
        config_module.constants.ns_mini_radar,
        i - 1,
        0,
        {
          end_col = #line,
          hl_group = radar_config.ui.mini.sections.locks.header_hl,
        }
      )
    elseif line == radar_config.ui.mini.sections.recent.header then
      current_section = "recent"
      vim.api.nvim_buf_set_extmark(
        bufid,
        config_module.constants.ns_mini_radar,
        i - 1,
        0,
        {
          end_col = #line,
          hl_group = radar_config.ui.mini.sections.recent.header_hl,
        }
      )
    -- Active file - only if we have a current file
    elseif current_file ~= "" and line:find(current_file, 1, true) then
      local entry_hl = current_section == "recent"
          and radar_config.ui.mini.sections.recent.entry_hl
        or radar_config.ui.mini.sections.locks.entry_hl

      vim.api.nvim_buf_set_extmark(
        bufid,
        config_module.constants.ns_mini_radar,
        i - 1,
        0,
        {
          end_col = #line,
          hl_group = entry_hl,
        }
      )
    end
  end
end

---Create mini radar window
---@param radar_config table
---@return nil
function M.create(radar_config)
  -- Update recent files first
  recent.update_state(radar_config)

  local all_entries = M.build_radar_entries(radar_config)

  local new_buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(new_buf_id, 0, -1, false, all_entries)

  local board_width = M.calculate_window_width(radar_config)
  local win_opts = vim.tbl_deep_extend("force", radar_config.ui.mini.config, {
    width = board_width,
    height = #all_entries,
    row = 1,
    col = math.floor((vim.o.columns - board_width) - 2),
  })

  local win = vim.api.nvim_open_win(new_buf_id, false, win_opts)
  state.mini_radar_winid = win

  -- Set window transparency
  vim.api.nvim_set_option_value(
    "winblend",
    radar_config.ui.mini.winblend,
    { win = win }
  )

  -- Apply all highlights
  M.apply_highlights(radar_config)
end

---Update mini radar window
---@param radar_config Radar.Config
---@return nil
function M.update(radar_config)
  -- Update recent files
  recent.update_state(radar_config)

  -- Keep window open even when empty
  M.ensure_exists(radar_config)
  local mini_radar_bufid = M.get_bufid()
  if mini_radar_bufid == nil then
    return
  end

  local all_entries = M.build_radar_entries(radar_config)

  vim.api.nvim_buf_set_lines(mini_radar_bufid, 0, -1, false, all_entries)

  local board_width = M.calculate_window_width(radar_config)
  vim.api.nvim_win_set_config(state.mini_radar_winid, {
    relative = "editor",
    width = board_width,
    height = #all_entries,
    row = 1,
    col = math.floor((vim.o.columns - board_width) - 2),
  })
  -- Apply all highlights
  M.apply_highlights(radar_config)
end

return M
