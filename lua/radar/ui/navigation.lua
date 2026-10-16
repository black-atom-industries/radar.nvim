local M = {}
local path_utils = require("radar.path")

---Open a file with the given command
---@param filepath string? File path to open
---@param open_cmd? string Command to open file (edit, vsplit, split, tabedit, float)
---@param config Radar.Config
---@return nil
function M.open_file(filepath, open_cmd, config)
  if not filepath then
    return
  end

  filepath = path_utils.to_absolute(filepath)

  -- Skip stale entries whose files no longer exist
  if not path_utils.is_url(filepath) and vim.fn.filereadable(filepath) == 0 then
    return
  end

  -- Close the help popup first, so the file opens in its parent window
  require("radar.ui.help").close()

  local path = vim.fn.fnameescape(filepath)
  open_cmd = open_cmd or "edit"

  if open_cmd == "float" then
    require("radar.ui.file_float").open(filepath, config)
  else
    vim.cmd(open_cmd .. " " .. path)
  end
end

---Open lock by label in the current window
---@param label string
---@param config Radar.Config
---@return nil
function M.open_lock(label, config)
  local state = require("radar.data.state")
  local lock = state.get_lock_by_field("label", tostring(label))
  if lock then
    M.open_file(lock.filename, nil, config)
  end
end

---Open recent file by label in the current window
---@param label string
---@param config Radar.Config
---@return nil
function M.open_recent(label, config)
  local state = require("radar.data.state")
  for i, recent_label in ipairs(config.keys.recent) do
    if recent_label == label and state.get_recent_files()[i] then
      M.open_file(state.get_recent_files()[i], nil, config)
      return
    end
  end
end

return M
