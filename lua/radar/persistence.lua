local M = {}

---Write table to file as JSON
---@param path string
---@param tbl table
---@return boolean
function M.write(path, tbl)
  local ok, _ = pcall(function()
    local fd = assert(vim.uv.fs_open(path, "w", 438)) -- 438 = 0666
    assert(vim.uv.fs_write(fd, vim.json.encode(tbl)))
    assert(vim.uv.fs_close(fd))
  end)

  return ok
end

---Read JSON file and return table
---@param path string
---@return Radar.PersistenceData?
function M.read(path)
  local ok, content = pcall(function()
    local fd = assert(vim.uv.fs_open(path, "r", 438)) -- 438 = 0666
    local stat = assert(vim.uv.fs_fstat(fd))
    local data = assert(vim.uv.fs_read(fd, stat.size, 0))
    assert(vim.uv.fs_close(fd))
    return data
  end)

  return ok and vim.json.decode(content) or nil
end

---Get current project path
---@return string?
function M.get_project_path()
  local cwd = vim.uv.cwd()

  if not cwd then
    return nil
  end

  local sanitized_path = vim.fn.fnameescape(cwd)
  return vim.fn.fnamemodify(sanitized_path, ":~")
end

---Get current git branch
---@return string?
function M.get_git_branch()
  local branch = vim.fn.systemlist("git branch --show-current")[1]
  if branch == "" then
    return nil
  end

  local sanitized_branch = vim.fn.fnameescape(branch)
  return sanitized_branch
end

---Load persistence data from file
---@param config Radar.Config
---@return Radar.PersistenceData?
function M.load(config)
  local file_path = config.persist.path
  local is_readable = vim.fn.filereadable(file_path)
  if is_readable == 1 then
    return M.read(file_path)
  else
    return nil
  end
end

---Persist current state to file
---@param config Radar.Config
---@return Radar.PersistenceData
function M.persist(config)
  local project_path = M.get_project_path()
  local git_branch = M.get_git_branch()

  local persisted_data = M.load(config)
  local data

  local state = require("radar.state")
  if persisted_data == nil then
    data = {
      [project_path] = {
        [git_branch] = {
          locks = state.locks,
        },
      },
    }
  else
    data = vim.tbl_deep_extend("force", persisted_data, {
      [project_path] = {
        [git_branch] = {
          locks = state.locks,
        },
      },
    })
  end

  vim.fn.mkdir(vim.fn.fnamemodify(config.persist.path, ":h"), "p")
  M.write(config.persist.path, data)
  return data
end

---Populate state from persisted data
---@param config Radar.Config
---@return nil
function M.populate(config)
  local data = M.load(config)

  if data ~= nil then
    local project_path = M.get_project_path()
    local git_branch = M.get_git_branch()
    local locks = vim.tbl_get(data, project_path, git_branch, "locks")

    if locks ~= nil then
      local state = require("radar.state")
      state.locks = locks
    end
  end
end

return M
