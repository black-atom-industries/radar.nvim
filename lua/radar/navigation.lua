local M = {}

---Get file path from current line in radar window
---@param config Radar.Config
---@param section "locks" | "recent"
---@return string? filepath
function M.get_file_from_line(config, section)
  local state = require("radar.state")

  if
    not state.get_radar_winid()
    or not vim.api.nvim_win_is_valid(state.get_radar_winid())
  then
    return nil
  end

  local current_line_nr = vim.api.nvim_win_get_cursor(state.get_radar_winid())[1]
  local ranges = state.get_section_line_ranges()

  if not ranges or not ranges[section] then
    return nil
  end

  -- Calculate entry index from line number with section offset
  -- First line in section range is the section header, so entries start at header + 1
  local section_start = ranges[section].start
  local entry_index = current_line_nr - section_start

  if section == "locks" then
    if entry_index > 0 and entry_index <= #state.get_locks() then
      return state.get_locks()[entry_index].filename
    end
  elseif section == "recent" then
    if entry_index > 0 and entry_index <= #state.get_recent_files() then
      return state.get_recent_files()[entry_index]
    end
  end

  return nil
end

---Open a file with the given command, ensuring radar exists
---@param filepath string? File path to open
---@param open_cmd? string Command to open file (edit, vsplit, split, tabedit, float)
---@param config Radar.Config
---@param radar_module table
---@return nil
function M.open_file(filepath, open_cmd, config, radar_module)
  if not filepath then
    return
  end

  -- Close radar first, so file opens in the previous window
  radar_module.close()

  local path = vim.fn.fnameescape(filepath)
  open_cmd = open_cmd or "edit"

  if open_cmd == "float" then
    require("radar.ui.file_float").open(filepath, config)
  else
    vim.cmd(open_cmd .. " " .. path)
  end
end

---Open lock by label
---@param label string
---@param open_cmd? string Command to open file (edit, vsplit, split, tabedit, float)
---@param config Radar.Config
---@param radar_module table
---@return nil
function M.open_lock(label, open_cmd, config, radar_module)
  local state = require("radar.state")
  local lock = state.get_lock_by_field("label", tostring(label))
  if lock then
    M.open_file(lock.filename, open_cmd, config, radar_module)
  end
end

---Open alternative file
---@param open_cmd? string Command to open file (edit, vsplit, split, tabedit, float)
---@param config Radar.Config
---@param radar_module table
---@return nil
function M.open_alternative(open_cmd, config, radar_module)
  local state = require("radar.state")
  -- Use the alternate file captured when radar was opened
  local alt_file = state.get_source_alt_file()
  if alt_file then
    M.open_file(alt_file, open_cmd, config, radar_module)
  end
end

---Open recent file by label
---@param label string
---@param open_cmd? string Command to open file (edit, vsplit, split, tabedit, float)
---@param config Radar.Config
---@param radar_module table
---@return nil
function M.open_recent(label, open_cmd, config, radar_module)
  local state = require("radar.state")
  -- Find the recent file by label
  for i, recent_label in ipairs(config.keys.recent) do
    if recent_label == label and state.get_recent_files()[i] then
      M.open_file(state.get_recent_files()[i], open_cmd, config, radar_module)
      return
    end
  end
end

---Open file from current line in radar window
---@param open_cmd? string Command to open file (edit, vsplit, split, tabedit, float)
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

return M
