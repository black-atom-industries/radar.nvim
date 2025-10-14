local M = {}

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

  local state = require("radar.state")
  -- Create lookup table for locked files (normalize to absolute paths)
  for _, lock in ipairs(state.locks) do
    local abs_path = vim.fn.fnamemodify(lock.filename, ":p")
    excluded_files[abs_path] = true
  end

  -- Exclude alternative file
  local alternative = require("radar.alternative")
  local alt_file = alternative.get_alternative_file()
  if alt_file then
    excluded_files[alt_file] = true
  end

  -- Add current session files first (most recent)
  for i = #state.session_files, 1, -1 do
    local filepath = state.session_files[i]

    if not excluded_files[filepath] and not seen_files[filepath] then
      if vim.startswith(filepath, cwd) and vim.fn.filereadable(filepath) == 1 then
        table.insert(recent_files, filepath)
        seen_files[filepath] = true

        if #recent_files >= #config.keys.recent then
          return recent_files
        end
      end
    end
  end

  -- Fill remaining slots with vim.v.oldfiles
  for _, filepath in ipairs(vim.v.oldfiles) do
    -- Skip if already seen, excluded, or if we're at capacity
    if
      seen_files[filepath]
      or excluded_files[filepath]
      or #recent_files >= #config.keys.recent
    then
      goto continue
    end

    -- Only include files from current working directory
    if vim.startswith(filepath, cwd) and vim.fn.filereadable(filepath) == 1 then
      table.insert(recent_files, filepath)
      seen_files[filepath] = true
    end

    ::continue::
  end

  return recent_files
end

---Add current file to session tracking
---@param config Radar.Config
---@return nil
function M.track_current_file(config)
  local current_file = vim.api.nvim_buf_get_name(0)

  -- Only track real files (not empty buffers, help files, etc.)
  if current_file == "" or vim.bo.buftype ~= "" or vim.bo.filetype == "help" then
    return
  end

  -- Get absolute path
  local abs_path = vim.fn.fnamemodify(current_file, ":p")

  local state = require("radar.state")
  -- Remove if already exists (we'll add it to the end)
  for i = #state.session_files, 1, -1 do
    if state.session_files[i] == abs_path then
      table.remove(state.session_files, i)
      break
    end
  end

  -- Add to end (most recent)
  table.insert(state.session_files, abs_path)

  -- Keep only last N session files
  if #state.session_files > config.behavior.max_recent_files then
    table.remove(state.session_files, 1)
  end
end

---Update recent files in state
---@param config? Radar.Config
---@return nil
function M.update_state(config)
  if not config then
    return
  end
  local state = require("radar.state")
  state.recent_files = M.get_files(config)
end

return M
