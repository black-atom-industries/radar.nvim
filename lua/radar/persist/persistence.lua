local M = {}
local utils = require("radar.utils")
local path_utils = require("radar.path")
local migration = require("radar.persist.migration")

---@param value any
---@return string
local function encode_scalar(value)
  return vim.json.encode(value)
end

---@param tbl table
---@return string[]
local function sorted_keys(tbl)
  local keys = vim.tbl_keys(tbl)
  table.sort(keys)
  return keys
end

---@param locks table[]
---@param indent string
---@return string
local function encode_locks(locks, indent)
  if #locks == 0 then
    return "[]"
  end
  local inner = indent .. "  "
  local deeper = inner .. "  "
  local items = {}
  for _, lock in ipairs(locks) do
    table.insert(
      items,
      string.format(
        '%s{\n%s"filename": %s,\n%s"label": %s\n%s}',
        inner,
        deeper,
        encode_scalar(lock.filename),
        deeper,
        encode_scalar(lock.label),
        inner
      )
    )
  end
  return "[\n" .. table.concat(items, ",\n") .. "\n" .. indent .. "]"
end

---Encode persistence data as pretty JSON with a fixed key order:
---version, projects (sorted), branches (sorted), {locks, lastAccessed},
---lock {filename, label}.
---@param data table
---@return string
function M.encode(data)
  local project_items = {}
  for _, project in ipairs(sorted_keys(data.projects or {})) do
    local branch_items = {}
    local branches = data.projects[project]
    for _, branch in ipairs(sorted_keys(branches)) do
      local branch_data = branches[branch]
      table.insert(
        branch_items,
        string.format(
          '      %s: {\n        "locks": %s,\n        "lastAccessed": %s\n      }',
          encode_scalar(branch),
          encode_locks(branch_data.locks or {}, "        "),
          encode_scalar(branch_data.lastAccessed)
        )
      )
    end
    local body = #branch_items == 0 and "{}"
      or "{\n" .. table.concat(branch_items, ",\n") .. "\n    }"
    table.insert(
      project_items,
      string.format("    %s: %s", encode_scalar(project), body)
    )
  end
  local projects = #project_items == 0 and "{}"
    or "{\n" .. table.concat(project_items, ",\n") .. "\n  }"
  return string.format(
    '{\n  "version": %s,\n  "projects": %s\n}\n',
    encode_scalar(data.version or migration.VERSION),
    projects
  )
end

---Write table to file as pretty JSON. The content goes to a unique tmp file
---in the same directory and is renamed over the target (atomic).
---@param path string
---@param tbl table
---@return boolean
function M.write(path, tbl)
  local tmp = path .. ".tmp." .. vim.uv.os_getpid() .. "." .. vim.uv.hrtime()
  local ok = pcall(function()
    local fd = assert(vim.uv.fs_open(tmp, "w", 438)) -- 438 = 0666
    local wrote, err = vim.uv.fs_write(fd, M.encode(tbl))
    local synced = wrote and vim.uv.fs_fsync(fd)
    vim.uv.fs_close(fd)
    assert(synced, err)
    assert(vim.uv.fs_rename(tmp, path))
  end)

  if not ok then
    vim.uv.fs_unlink(tmp)
  end

  return ok
end

---@alias Radar.ReadStatus "missing"|"empty"|"corrupt"|"unreadable"

---Read JSON file and return table.
---Returns nil plus a status when no data could be produced.
---@param path string
---@return Radar.PersistenceData?, Radar.ReadStatus?
function M.read(path)
  local fd, _, err_name = vim.uv.fs_open(path, "r", 438) -- 438 = 0666
  if not fd then
    return nil, err_name == "ENOENT" and "missing" or "unreadable"
  end

  local stat = vim.uv.fs_fstat(fd)
  local content = stat and vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)

  if not content then
    return nil, "unreadable"
  end
  if #content == 0 then
    return nil, "empty"
  end

  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= "table" then
    return nil, "corrupt"
  end
  return decoded
end

---Get the persistence key of the current project: the project root with `~`
---abbreviation
---@return string?
function M.get_project_path()
  local root = path_utils.project_root()
  return root and vim.fn.fnamemodify(root, ":~")
end

---Get current git branch by reading HEAD directly (no subprocess)
---@return string?
function M.get_git_branch()
  return path_utils.git_branch(path_utils.git_info())
end

local warned_no_branch = false

---Warn once per session that locks are not persisted outside a branch
local function warn_no_branch()
  if warned_no_branch then
    return
  end
  warned_no_branch = true
  vim.notify(
    "radar: locks are not persisted outside a git branch (detached HEAD or non-git directory).",
    vim.log.levels.WARN
  )
end

---Load persistence data from file.
---A corrupt file is moved to `<path>.bad` and treated as missing. The second
---return value is true when the file exists but could not be used and was not
---quarantined; callers must not overwrite it then.
---@param config Radar.Config
---@return Radar.PersistenceData?, boolean?
function M.load(config)
  local file_path = config.persist.path
  local data, status = M.read(file_path)

  if data then
    local ok, migrated = pcall(migration.migrate, data)
    if ok and type(migrated) == "table" and type(migrated.projects) == "table" then
      return migrated
    end
    status = "corrupt"
  end

  if status == "missing" or status == "empty" then
    return nil
  end

  if status == "corrupt" then
    local bad_path = file_path .. ".bad"
    if vim.uv.fs_rename(file_path, bad_path) then
      vim.notify(
        string.format("radar: %s is corrupt. Moved it to %s.", file_path, bad_path),
        vim.log.levels.WARN
      )
      return nil
    end
  end

  vim.notify(
    string.format(
      "radar: cannot read %s. Persistence is disabled for this write.",
      file_path
    ),
    vim.log.levels.WARN
  )
  return nil, true
end

---Persist current state to file
---@param config Radar.Config
---@return Radar.PersistenceData?
function M.persist(config)
  local project_path = M.get_project_path()
  local git_branch = M.get_git_branch()
  if not project_path or not git_branch then
    warn_no_branch()
    return nil
  end

  local persisted_data, load_failed = M.load(config)
  if load_failed then
    return nil
  end

  local state = require("radar.data.state")
  local current_time = os.time()

  local merged_projects =
    vim.tbl_deep_extend("force", persisted_data and persisted_data.projects or {}, {
      [project_path] = {
        [git_branch] = {
          locks = state.get_locks(),
          lastAccessed = current_time,
        },
      },
    })

  local data = {
    version = migration.VERSION,
    projects = utils.sort_projects(merged_projects),
  }

  vim.fn.mkdir(vim.fn.fnamemodify(config.persist.path, ":h"), "p")
  M.write(config.persist.path, data)
  return data
end

---Project and branch of the last populate, as `<project>\n<branch>`
---@type string?
local populated_context

---Populate state from persisted data
---@param config Radar.Config
---@return nil
function M.populate(config)
  local project_path = M.get_project_path()
  local git_branch = M.get_git_branch()
  populated_context =
    string.format("%s\n%s", tostring(project_path), tostring(git_branch))
  if not project_path or not git_branch then
    warn_no_branch()
    return
  end

  local data = M.load(config)
  local state = require("radar.data.state")

  local locks =
    vim.tbl_get(data or {}, "projects", project_path, git_branch, "locks")

  -- Clears to {} when the new project/branch has no saved locks (e.g.,
  -- switching worktrees) so stale locks from the previous directory go away.
  require("radar.data.locks").relabel(locks or {}, config)
  state.set_locks(locks or {})

  if data ~= nil and locks ~= nil then
    data.projects[project_path][git_branch].lastAccessed = os.time()

    vim.fn.mkdir(vim.fn.fnamemodify(config.persist.path, ":h"), "p")
    M.write(config.persist.path, {
      version = data.version or migration.VERSION,
      projects = utils.sort_projects(data.projects),
    })
  end
end

---Populate state only when the project root or branch differs from the last
---populate
---@param config Radar.Config
---@return boolean reloaded
function M.populate_if_changed(config)
  local context = string.format(
    "%s\n%s",
    tostring(M.get_project_path()),
    tostring(M.get_git_branch())
  )
  if context == populated_context then
    return false
  end
  M.populate(config)
  return true
end

return M
