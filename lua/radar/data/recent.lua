local M = {}
local path = require("radar.path")

local function is_within_cwd(filesystem_path, cwd)
  local normalized_cwd = cwd:gsub("/+$", "")
  local normalized_path = filesystem_path:gsub("/+$", "")
  return normalized_path == normalized_cwd
    or vim.startswith(filesystem_path, normalized_cwd .. "/")
end

local function exists(filename, filesystem_path)
  return path.is_oil_url(filename) and vim.fn.isdirectory(filesystem_path) == 1
    or vim.fn.filereadable(filename) == 1
end

---Get recent files filtered by current working directory and excluding locked files and alternative file
---@param config Radar.Config
---@return string[]
function M.get_files(config)
  local cwd = vim.uv.cwd()
  if not cwd then
    return {}
  end

  local recent_files = {}
  local seen_files = {}
  local excluded_files = {}

  local state = require("radar.data.state")
  -- Create lookup table for locked files (normalize to absolute paths)
  for _, lock in ipairs(state.get_locks()) do
    local abs_path = vim.fn.fnamemodify(path.to_filesystem_path(lock.filename), ":p")
    excluded_files[abs_path] = true
  end

  -- Exclude alternative file — use stored source alt file when available
  -- (set during radar.open()) to ensure consistent exclusion before and after
  -- BufEnter during nvim_open_win, where re-evaluating get_alternative_file()
  -- gives different results (radar buffer vs source buffer)
  local alt_file = state.get_source_alt_file()
  if not alt_file then
    local ok, result = pcall(function()
      local alternative = require("radar.data.alternative")
      return alternative.get_alternative_file()
    end)
    if ok then
      alt_file = result
    end
  end
  if alt_file then
    local abs_path = vim.fn.fnamemodify(path.to_filesystem_path(alt_file), ":p")
    excluded_files[abs_path] = true
  end

  -- Add current session files first (most recent)
  for i = #state.get_session_files(), 1, -1 do
    local filepath = state.get_session_files()[i]

    local filesystem_path = path.to_filesystem_path(filepath)
    local abs_path = vim.fn.fnamemodify(filesystem_path, ":p")

    if not excluded_files[abs_path] and not seen_files[abs_path] then
      if
        is_within_cwd(filesystem_path, cwd) and exists(filepath, filesystem_path)
      then
        table.insert(recent_files, filepath)
        seen_files[abs_path] = true

        if #recent_files >= config.radar.max_recent_files then
          return recent_files
        end
      end
    end
  end

  -- Fill remaining slots with vim.v.oldfiles
  for _, filepath in ipairs(vim.v.oldfiles) do
    -- Skip if already seen, excluded, or if we're at capacity
    local filesystem_path = path.to_filesystem_path(filepath)
    local abs_path = vim.fn.fnamemodify(filesystem_path, ":p")

    if
      not seen_files[abs_path]
      and not excluded_files[abs_path]
      and #recent_files < config.radar.max_recent_files
    then
      -- Only include files from current working directory
      if
        is_within_cwd(filesystem_path, cwd) and exists(filepath, filesystem_path)
      then
        table.insert(recent_files, filepath)
        seen_files[abs_path] = true
      end
    end
  end

  return recent_files
end

---Add current file to session tracking
---@param config Radar.Config
---@return nil
function M.track_current_file(config)
  local current_file = vim.api.nvim_buf_get_name(0)

  local is_oil_url = path.is_oil_url(current_file)

  -- Only track real files (not empty buffers, help files, etc.)
  if
    current_file == ""
    or (vim.bo.buftype ~= "" and not is_oil_url)
    or vim.bo.filetype == "help"
  then
    return
  end

  -- Get absolute path
  local abs_path = is_oil_url and current_file
    or vim.fn.fnamemodify(current_file, ":p")

  local state = require("radar.data.state")
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
