local config_module = require("radar.config")
local state = require("radar.state")
local recent = require("radar.recent")
local collision = require("radar.collision")

local M = {}

---Format file path according to config, with optional shortening
---@param path string
---@param radar_config table
---@param max_width integer? Maximum width for path display (if nil, no shortening)
---@param label_width integer? Width taken by label (e.g., "[1] ")
---@return string
function M.get_formatted_filepath(path, radar_config, max_width, label_width)
  -- Use our path utility for formatting and shortening
  local path_utils = require("radar.utils.path")
  return path_utils.format_and_shorten(
    path,
    radar_config.path_format,
    max_width,
    label_width
  )
end

---Create formatted entries for locks
---@param locks Radar.Lock[]
---@param radar_config table
---@return string[]
function M.create_entries(locks, radar_config)
  local entries = {}

  if #locks > 0 then
    table.insert(entries, radar_config.locks_header)
    for _, lock in ipairs(locks) do
      -- Calculate label width: "   [1] " = 7 chars for single char label
      local label_width = 3 + 1 + #lock.label + 1 + 1 + 2 -- spaces + [label] + spaces
      local path = M.get_formatted_filepath(
        lock.filename,
        radar_config,
        radar_config.width,
        label_width
      )
      local entry = string.format("   [%s] %s  ", lock.label, path)
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
    table.insert(entries, radar_config.recent_header)
    for i, filename in ipairs(state.recent_files) do
      local label = radar_config.keys.recent[i]
      if label then
        -- Calculate label width: "   [a] " = 7 chars for single char label
        local label_width = 3 + 1 + #label + 1 + 1 + 2 -- spaces + [label] + spaces
        local path = M.get_formatted_filepath(
          filename,
          radar_config,
          radar_config.width,
          label_width
        )
        local entry = string.format("   [%s] %s  ", label, path)
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
      table.insert(all_entries, " ")
    end
    local recent_entries = M.create_recent_entries(radar_config)
    vim.list_extend(all_entries, recent_entries)
  end

  -- Add separator at the beginning if we have any content
  if #all_entries > 0 then
    table.insert(all_entries, 1, " ")
  end

  -- If no content at all, show helpful message
  if #all_entries == 0 and radar_config.show_empty_message then
    table.insert(all_entries, radar_config.title)
    table.insert(all_entries, "")
    table.insert(all_entries, "  No files tracked yet")
    table.insert(all_entries, "  Use " .. radar_config.keys.lock .. " to lock files")
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
  if not M.exists() and not collision.is_hidden_for_collision() then
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

  -- Get current file path for highlighting comparison
  local curr_filepath = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())

  -- Format current file path to match the format used in locks/recent files
  -- Locks use the same format as the path_format configuration
  local curr_filepath_formatted = ""
  if curr_filepath ~= "" then
    curr_filepath_formatted =
      vim.fn.fnamemodify(curr_filepath, radar_config.path_format)
  end

  -- Clear all highlights once
  vim.api.nvim_buf_clear_namespace(
    bufid,
    config_module.constants.ns_mini_radar,
    0,
    -1
  )

  -- Track which section we're in for proper highlighting
  local current_section = nil
  local section_index = 0

  for i, line in ipairs(lines) do
    -- Section headers - always highlight and reset section tracking
    if line == radar_config.locks_header then
      current_section = "locks"
      section_index = 0
      vim.api.nvim_buf_set_extmark(
        bufid,
        config_module.constants.ns_mini_radar,
        i - 1,
        0,
        {
          end_col = #line,
          hl_group = "@tag.builtin",
        }
      )
    elseif line == radar_config.recent_header then
      current_section = "recent"
      section_index = 0
      vim.api.nvim_buf_set_extmark(
        bufid,
        config_module.constants.ns_mini_radar,
        i - 1,
        0,
        {
          end_col = #line,
          hl_group = "@type",
        }
      )
    elseif line == " " then
      -- Skip separator lines, don't change section or index
    elseif line ~= "" and current_section and curr_filepath_formatted ~= "" then
      -- This is a file entry line - increment index and check for match
      section_index = section_index + 1

      local actual_filepath = nil
      if current_section == "locks" and state.locks[section_index] then
        actual_filepath = state.locks[section_index].filename
      elseif current_section == "recent" and state.recent_files[section_index] then
        actual_filepath = state.recent_files[section_index]
      end

      -- Only highlight if this line represents the current file
      -- Locks store relative paths, recent files store absolute paths
      local matches = false
      if actual_filepath then
        if current_section == "locks" then
          -- Locks use relative paths - compare with formatted current path
          matches = actual_filepath == curr_filepath_formatted
        elseif current_section == "recent" then
          -- Recent files use absolute paths - compare with absolute current path
          matches = actual_filepath == curr_filepath
        end
      end

      if matches then
        local entry_hl = "@function" -- Both locks and recent use same highlight

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

  local board_width = radar_config.width
  local win_opts = {
    width = board_width,
    height = #all_entries,
    row = 1,
    col = math.floor((vim.o.columns - board_width) - 2),
    relative = "editor",
    anchor = "NW",
    title = radar_config.title,
    title_pos = "left",
    style = "minimal",
    border = "solid",
    focusable = false,
    zindex = 100,
  }

  local win = vim.api.nvim_open_win(new_buf_id, false, win_opts)
  state.mini_radar_winid = win

  -- Set window transparency
  vim.api.nvim_set_option_value(
    "winblend",
    radar_config.winblend,
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

  local board_width = radar_config.width
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
