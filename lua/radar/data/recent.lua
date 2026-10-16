local M = {}
local path = require("radar.path")

---@param filename string
---@return string
local function absolute(filename)
  return path.to_absolute(path.to_filesystem_path(filename))
end

local function exists(filename, filesystem_path)
  return path.is_oil_url(filename) and vim.fn.isdirectory(filesystem_path) == 1
    or vim.fn.filereadable(filename) == 1
end

---Get recent files filtered by project root and excluding locked files and alternative file
---@param config Radar.Config
---@return string[]
function M.get_files(config)
  local root = path.project_root()
  if not root then
    return {}
  end

  local recent_files = {}
  local seen_files = {}
  local excluded_files = {}

  local state = require("radar.data.state")
  for _, lock in ipairs(state.get_locks()) do
    excluded_files[absolute(lock.filename)] = true
  end

  -- Exclude alternative file — use stored source alt file when available
  -- (set during radar.open()) to ensure consistent exclusion before and after
  -- BufEnter during nvim_open_win, where re-evaluating get_alternative_file()
  -- gives different results (radar buffer vs source buffer).
  -- `false` means radar.open() found no alternative file.
  local alt_file = state.get_source_alt_file()
  if alt_file == nil then
    local ok, result = pcall(function()
      local alternative = require("radar.data.alternative")
      return alternative.get_alternative_file()
    end)
    if ok then
      alt_file = result
    end
  end
  if alt_file then
    excluded_files[absolute(alt_file)] = true
  end

  local function add(filepath)
    local filesystem_path = path.to_filesystem_path(filepath)
    local abs_path = absolute(filepath)

    if
      not seen_files[abs_path]
      and not excluded_files[abs_path]
      and #recent_files < config.radar.max_recent_files
    then
      if path.relative_to(abs_path, root) and exists(filepath, filesystem_path) then
        table.insert(recent_files, filepath)
        seen_files[abs_path] = true
      end
    end
  end

  -- Current session files first (most recent), then the persisted history,
  -- then vim.v.oldfiles
  for i = #state.get_session_files(), 1, -1 do
    add(state.get_session_files()[i])
  end
  for _, filepath in ipairs(state.get_history()) do
    add(filepath)
  end
  for _, filepath in ipairs(vim.v.oldfiles) do
    add(filepath)
  end

  return recent_files
end

---This session's files inside `root` as lock paths, most recent first
---@param root string
---@return string[]
function M.session_lock_paths(root)
  local files = require("radar.data.state").get_session_files()
  local paths = {}
  for i = #files, 1, -1 do
    local relative = path.relative_to(absolute(files[i]), root)
    if relative then
      table.insert(paths, path.is_url(files[i]) and files[i] or relative)
    end
  end
  return paths
end

---Add current file to session tracking
---@param config Radar.Config
---@return boolean changed false when the file is ignored or already the most recent
function M.track_current_file(config)
  local current_file = vim.api.nvim_buf_get_name(0)

  local is_oil_url = path.is_oil_url(current_file)

  -- Only track real files (not empty buffers, help files, etc.)
  if
    current_file == ""
    or (vim.bo.buftype ~= "" and not is_oil_url)
    or vim.bo.filetype == "help"
  then
    return false
  end

  -- Get absolute path
  local abs_path = is_oil_url and current_file
    or vim.fn.fnamemodify(current_file, ":p")

  local state = require("radar.data.state")
  local session_files = state.get_session_files()
  if session_files[#session_files] == abs_path then
    return false
  end

  -- Remove if already exists (we'll add it to the end)
  for i = #state.get_session_files(), 1, -1 do
    if state.get_session_files()[i] == abs_path then
      table.remove(state.get_session_files(), i)
      break
    end
  end

  -- Add to end (most recent)
  table.insert(state.get_session_files(), abs_path)

  -- Keep only last N session files
  if #state.get_session_files() > config.radar.max_recent_files then
    table.remove(state.get_session_files(), 1)
  end
  return true
end

---Update recent files in state
---@param config? Radar.Config
---@return nil
function M.update_state(config)
  if not config then
    return
  end
  local state = require("radar.data.state")
  state.set_recent_files(M.get_files(config))
end

return M
